from __future__ import annotations
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
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


@router.post("/upload")
async def upload_document(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(400, "No file provided")

    content = await file.read()
    text = content.decode("utf-8", errors="ignore")

    result = parse_pdf_content(text, file.filename)
    return result


@router.post("/search")
def search(body: SearchRequest):
    results = search_knowledge(body.query, body.top_k)
    return {"results": results, "total": len(results)}


@router.post("/generate")
def generate(body: GenerateRequest):
    if not body.prompt.strip():
        raise HTTPException(400, "Prompt is required")
    return generate_strategy(body.prompt, body.risk_level, body.market)


@router.get("/knowledge")
def get_knowledge():
    return {"documents": list_knowledge()}
