from __future__ import annotations
import hashlib

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai import KnowledgeChunk, KnowledgeDocument
from app.services.rag_service import (
    parse_pdf_content,
    search_knowledge,
    generate_strategy,
    list_knowledge,
)

router = APIRouter(prefix="/rag", tags=["rag"])


class GenerateRequest(BaseModel):
    prompt: str
    risk_level: str = "medium"
    market: str = "crypto"


class SearchRequest(BaseModel):
    query: str
    top_k: int = 5


def _extract_chunks(text: str) -> list[str]:
    lines = [
        line.strip()
        for line in text.splitlines()
        if len(line.strip()) > 20
        and any(keyword in line.lower() for keyword in ["strategy", "trading", "signal", "indicator", "risk", "position", "策略", "交易", "信号", "风险"])
    ]
    if lines:
        return lines[:80]

    compact = " ".join(text.split())
    return [compact[idx : idx + 800] for idx in range(0, min(len(compact), 8000), 800) if compact[idx : idx + 800]]


def _score_chunk(query: str, content: str) -> float:
    words = [word for word in query.lower().split() if word]
    if not words:
        return 0
    hits = sum(1 for word in words if word in content.lower())
    return min(0.98, hits / len(words) + 0.15) if hits else 0


@router.post("/upload")
async def upload_document(file: UploadFile = File(...), db: Session = Depends(get_db)):
    if not file.filename:
        raise HTTPException(400, "No file provided")

    content = await file.read()
    text = content.decode("utf-8", errors="ignore")
    content_hash = hashlib.sha256(content).hexdigest()
    existing = db.query(KnowledgeDocument).filter(KnowledgeDocument.content_hash == content_hash).first()
    if existing:
        return {
            "doc_id": existing.id,
            "filename": existing.filename,
            "concepts_extracted": existing.chunk_count,
            "chunks_created": existing.chunk_count,
            "persisted": True,
            "duplicate": True,
        }

    result = parse_pdf_content(text, file.filename)
    chunks = _extract_chunks(text)
    document = KnowledgeDocument(
        filename=file.filename,
        content_hash=content_hash,
        content_type=file.content_type or "text/plain",
        chunk_count=len(chunks),
    )
    db.add(document)
    db.commit()
    db.refresh(document)

    for idx, chunk in enumerate(chunks):
        keywords = [word.strip(".,:;()[]{}").lower() for word in chunk.split()[:16]]
        db.add(KnowledgeChunk(document_id=document.id, chunk_index=idx, content=chunk, keywords=keywords))
    db.commit()

    result.update({"doc_id": document.id, "chunks_created": len(chunks), "persisted": True})
    return result


@router.post("/search")
def search(body: SearchRequest, db: Session = Depends(get_db)):
    documents = {doc.id: doc for doc in db.query(KnowledgeDocument).all()}
    chunks = db.query(KnowledgeChunk).order_by(KnowledgeChunk.created_at.desc()).limit(500).all()
    results = []
    for chunk in chunks:
        score = _score_chunk(body.query, chunk.content)
        if score <= 0:
            continue
        document = documents.get(chunk.document_id)
        results.append(
            {
                "doc_id": chunk.document_id,
                "filename": document.filename if document else "unknown",
                "content": chunk.content[:500],
                "relevance": round(score, 3),
                "persisted": True,
            }
        )
    results.sort(key=lambda item: item["relevance"], reverse=True)
    if not results:
        results = search_knowledge(body.query, body.top_k)
    else:
        results = results[: body.top_k]
    return {"results": results, "total": len(results)}


@router.post("/generate")
def generate(body: GenerateRequest):
    if not body.prompt.strip():
        raise HTTPException(400, "Prompt is required")
    return generate_strategy(body.prompt, body.risk_level, body.market)


@router.get("/knowledge")
def get_knowledge(db: Session = Depends(get_db)):
    documents = db.query(KnowledgeDocument).order_by(KnowledgeDocument.created_at.desc()).all()
    if not documents:
        return {"documents": list_knowledge()}
    return {
        "documents": [
            {
                "id": doc.id,
                "filename": doc.filename,
                "concepts": doc.chunk_count,
                "chunks": doc.chunk_count,
                "created_at": doc.created_at,
                "persisted": True,
            }
            for doc in documents
        ]
    }
