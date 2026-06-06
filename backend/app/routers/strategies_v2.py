"""Strategy v2.5 API — CRUD + versions + DSL validation + lifecycle."""
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.domain.enums import StrategyVersionStatus
from app.domain.strategy import StrategyV2, StrategyVersion
from app.repositories.strategy_repository import StrategyRepository
from app.schemas.strategy_v2 import (
    CreateStrategyRequest,
    CreateVersionRequest,
    DSLErrorResponse,
    DSLValidationResponse,
    StrategyV2Response,
    StrategyVersionResponse,
    TransitionVersionStatusRequest,
    UpdateStrategyRequest,
    ValidateDSLRequest,
    VersionDiffResponse,
)
from app.services.dsl_hasher import compute_dsl_hash
from app.services.dsl_validator import DSLValidator
from app.services.strategy_diff import compute_dsl_diff
from app.services.strategy_transition import (
    InvalidTransitionError,
    is_system_only,
    validate_transition,
)

router = APIRouter(prefix="/api/v2/strategies", tags=["strategies-v2"])

_validator = DSLValidator()


@router.get("", response_model=list[StrategyV2Response])
def list_strategies(
    status: str | None = None,
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db),
):
    repo = StrategyRepository(db)
    return [
        StrategyV2Response.model_validate(s)
        for s in repo.list_strategies(status=status, offset=offset, limit=limit)
    ]


@router.post("", response_model=StrategyV2Response, status_code=201)
def create_strategy(req: CreateStrategyRequest, db: Session = Depends(get_db)):
    repo = StrategyRepository(db)
    strategy = StrategyV2(
        name=req.name,
        description=req.description,
        strategy_type=req.strategy_type,
        source_type=req.source_type,
        status="draft",
    )
    repo.create_strategy(strategy)
    db.commit()
    db.refresh(strategy)
    return StrategyV2Response.model_validate(strategy)


@router.post("/validate-dsl", response_model=DSLValidationResponse)
def validate_dsl(req: ValidateDSLRequest):
    report = _validator.validate(req.dsl)
    return DSLValidationResponse(
        valid=report.valid,
        error_count=report.error_count,
        warning_count=report.warning_count,
        safe_hold_required=report.safe_hold_required,
        safe_hold_reasons=report.safe_hold_reasons,
        errors=[
            DSLErrorResponse(code=e.code, path=e.path, message=e.message, severity=e.severity)
            for e in report.errors
        ],
        warnings=[
            DSLErrorResponse(code=e.code, path=e.path, message=e.message, severity=e.severity)
            for e in report.warnings
        ],
    )


@router.get("/{strategy_id}", response_model=StrategyV2Response)
def get_strategy(strategy_id: uuid.UUID, db: Session = Depends(get_db)):
    repo = StrategyRepository(db)
    strategy = repo.get_strategy_by_id(strategy_id)
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    return StrategyV2Response.model_validate(strategy)


@router.patch("/{strategy_id}", response_model=StrategyV2Response)
def update_strategy(
    strategy_id: uuid.UUID,
    req: UpdateStrategyRequest,
    db: Session = Depends(get_db),
):
    repo = StrategyRepository(db)
    strategy = repo.get_strategy_by_id(strategy_id)
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")

    updates = req.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(strategy, field, value)

    repo.update_strategy(strategy)
    db.commit()
    db.refresh(strategy)
    return StrategyV2Response.model_validate(strategy)




@router.delete("/{strategy_id}", status_code=204)
def delete_strategy(
    strategy_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    repo = StrategyRepository(db)
    strategy = repo.get_strategy_by_id(strategy_id)
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    repo.delete_strategy(strategy)
    db.commit()
    return None

@router.post("/{strategy_id}/versions", response_model=StrategyVersionResponse, status_code=201)
def create_version(
    strategy_id: uuid.UUID,
    req: CreateVersionRequest,
    db: Session = Depends(get_db),
):
    repo = StrategyRepository(db)
    strategy = repo.get_strategy_by_id(strategy_id)
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")

    report = _validator.validate(req.rule_dsl)
    if not report.valid:
        raise HTTPException(status_code=422, detail={
            "message": "DSL validation failed",
            "errors": [
                {"code": e.code, "path": e.path, "message": e.message, "severity": e.severity}
                for e in report.errors
            ],
        })

    dsl_hash = compute_dsl_hash(req.rule_dsl)
    version_no = repo.next_version_no(strategy_id)

    version = StrategyVersion(
        strategy_id=strategy_id,
        version_no=version_no,
        status="draft",
        dsl_version=req.rule_dsl.get("schema_version", "2.5"),
        rule_dsl=req.rule_dsl,
        dsl_hash=dsl_hash,
        created_by=req.created_by,
    )
    repo.create_version(version)
    db.commit()
    db.refresh(version)
    return StrategyVersionResponse.model_validate(version)


@router.get("/{strategy_id}/versions", response_model=list[StrategyVersionResponse])
def list_versions(strategy_id: uuid.UUID, db: Session = Depends(get_db)):
    repo = StrategyRepository(db)
    strategy = repo.get_strategy_by_id(strategy_id)
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")

    from sqlalchemy import select
    stmt = (
        select(StrategyVersion)
        .where(StrategyVersion.strategy_id == strategy_id)
        .order_by(StrategyVersion.version_no.desc())
    )
    versions = list(db.scalars(stmt).all())
    return [StrategyVersionResponse.model_validate(v) for v in versions]


@router.get("/{strategy_id}/versions/diff", response_model=VersionDiffResponse)
def diff_versions(
    strategy_id: uuid.UUID,
    from_vid: uuid.UUID = Query(..., description="Source version ID"),
    to_vid: uuid.UUID = Query(..., description="Target version ID"),
    db: Session = Depends(get_db),
):
    repo = StrategyRepository(db)
    strategy = repo.get_strategy_by_id(strategy_id)
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")

    v_from = repo.get_version_by_strategy_and_id(strategy_id, from_vid)
    if not v_from:
        raise HTTPException(status_code=404, detail="Source version not found")

    v_to = repo.get_version_by_strategy_and_id(strategy_id, to_vid)
    if not v_to:
        raise HTTPException(status_code=404, detail="Target version not found")

    diff = compute_dsl_diff(v_from.rule_dsl, v_to.rule_dsl)
    return VersionDiffResponse(
        from_version_no=v_from.version_no,
        to_version_no=v_to.version_no,
        **diff,
    )


@router.get("/{strategy_id}/versions/{version_id}", response_model=StrategyVersionResponse)
def get_version(
    strategy_id: uuid.UUID,
    version_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    repo = StrategyRepository(db)
    version = repo.get_version_by_strategy_and_id(strategy_id, version_id)
    if not version:
        raise HTTPException(status_code=404, detail="Version not found")
    return StrategyVersionResponse.model_validate(version)


@router.patch("/{strategy_id}/versions/{version_id}/status", response_model=StrategyVersionResponse)
def transition_version_status(
    strategy_id: uuid.UUID,
    version_id: uuid.UUID,
    req: TransitionVersionStatusRequest,
    db: Session = Depends(get_db),
):
    repo = StrategyRepository(db)
    version = repo.get_version_by_strategy_and_id(strategy_id, version_id)
    if not version:
        raise HTTPException(status_code=404, detail="Version not found")

    from_status = StrategyVersionStatus(version.status)
    try:
        to_status = StrategyVersionStatus(req.to_status)
    except ValueError:
        raise HTTPException(status_code=422, detail=f"Invalid status: {req.to_status}")

    if is_system_only(from_status, to_status):
        raise HTTPException(
            status_code=403,
            detail=f"Transition {from_status.value} -> {to_status.value} is system-only",
        )

    try:
        validate_transition(from_status, to_status)
    except InvalidTransitionError as e:
        raise HTTPException(status_code=409, detail=str(e))

    version.status = to_status.value
    db.commit()
    db.refresh(version)
    return StrategyVersionResponse.model_validate(version)
