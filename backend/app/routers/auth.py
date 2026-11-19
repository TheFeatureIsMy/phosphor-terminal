import re
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.tenant import DeviceSession, Membership, Tenant
from app.models.user import User, UserSettings
from app.schemas.auth import (
    UserCreate, UserLogin, UserResponse, TokenResponse,
    TokenRefresh, UserSettingsUpdate, UserSettingsResponse, TenantResponse,
)
from app.services.auth import (
    authenticate_user, create_access_token, create_refresh_token,
    decode_token, get_password_hash, get_user_by_id,
)

router = APIRouter(prefix="/auth", tags=["auth"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    sid = payload.get("sid")
    if sid:
        session = db.get(DeviceSession, sid)
        now_naive = datetime.now(timezone.utc).replace(tzinfo=None)
        if (
            session is None
            or session.revoked_at is not None
            or (session.expires_at is not None and session.expires_at < now_naive)
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Session revoked",
            )
    user = get_user_by_id(db, int(payload["sub"]))
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user




def _slug_for(username: str) -> str:
    base = re.sub(r"[^a-z0-9]+", "-", username.strip().lower()).strip("-")
    if not base:
        base = "tenant"
    return f"{base[:80]}-{uuid.uuid4().hex[:8]}"


def _membership_for(db: Session, user_id: int) -> Membership | None:
    return (
        db.query(Membership)
        .filter(Membership.user_id == user_id)
        .order_by(Membership.id.asc())
        .first()
    )


def _claims(db: Session, user: User) -> dict:
    claims = {"sub": str(user.id)}
    membership = _membership_for(db, user.id)
    if membership is not None:
        claims["tid"] = str(membership.tenant_id)
        claims["role"] = membership.role
    return claims


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(body: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.username == body.username).first():
        raise HTTPException(status_code=400, detail="Username already taken")
    if db.query(User).filter(User.email == body.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    existing_users = db.query(User).count()
    if existing_users > 0 and not settings.allow_public_registration:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Registration is closed; ask an administrator to create the account",
        )

    user = User(
        username=body.username,
        email=body.email,
        hashed_password=get_password_hash(body.password),
        # The bootstrap account owns the instance; later accounts can be
        # created by this superuser once admin-only routes land.
        is_superuser=existing_users == 0,
    )
    db.add(user)
    db.flush()

    # Every account gets its own tenant for now. Team invites / multiple
    # memberships can be layered on without changing the token contract.
    tenant = Tenant(name=body.username, slug=_slug_for(body.username))
    db.add(tenant)
    db.flush()
    db.add(Membership(user_id=user.id, tenant_id=tenant.id, role="owner"))
    db.commit()
    db.refresh(user)

    user_settings = UserSettings(user_id=user.id)
    db.add(user_settings)
    db.commit()

    return user


@router.post("/login", response_model=TokenResponse)
def login(
    request: Request,
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = authenticate_user(db, form.username, form.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    claims = _claims(db, user)
    if claims.get("tid"):
        sid = str(uuid.uuid4())
        db.add(DeviceSession(
            id=sid, user_id=user.id, tenant_id=int(claims["tid"]),
            device_name=request.headers.get("x-device-name"),
            user_agent=request.headers.get("user-agent"),
            ip_address=request.client.host if request.client else None,
            expires_at=datetime.now(timezone.utc).replace(tzinfo=None)
            + timedelta(days=settings.session_ttl_days),
        ))
        db.commit()
        claims["sid"] = sid
    return TokenResponse(
        access_token=create_access_token(claims),
        refresh_token=create_refresh_token(claims),
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(body: TokenRefresh, db: Session = Depends(get_db)):
    payload = decode_token(body.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = get_user_by_id(db, int(payload["sub"]))
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found")

    sid = payload.get("sid")
    if sid:
        session = db.get(DeviceSession, sid)
        if session is None or session.revoked_at is not None:
            raise HTTPException(status_code=401, detail="Session revoked")

    claims = _claims(db, user)
    if sid:
        claims["sid"] = sid
    return TokenResponse(
        access_token=create_access_token(claims),
        refresh_token=create_refresh_token(claims),
    )


@router.get("/sessions")
def list_sessions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(DeviceSession)
        .filter(DeviceSession.user_id == current_user.id)
        .order_by(DeviceSession.created_at.desc())
        .all()
    )
    return [
        {
            "id": row.id, "device_name": row.device_name,
            "ip_address": row.ip_address, "created_at": row.created_at,
            "last_seen_at": row.last_seen_at, "revoked": row.revoked_at is not None,
        }
        for row in rows
    ]


@router.post("/sessions/{session_id}/revoke")
def revoke_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from datetime import datetime, timezone

    session = db.get(DeviceSession, session_id)
    if session is None or session.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")
    session.revoked_at = datetime.now(timezone.utc)
    db.commit()
    return {"status": "revoked", "session_id": session_id}


@router.post("/logout")
def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from datetime import datetime, timezone

    header = request.headers.get("authorization", "")
    token = header[7:].strip() if header.lower().startswith("bearer ") else ""
    payload = decode_token(token) if token else None
    sid = payload.get("sid") if payload else None
    if sid:
        session = db.get(DeviceSession, sid)
        if session is not None and session.user_id == current_user.id:
            session.revoked_at = datetime.now(timezone.utc)
            db.commit()
    return {"status": "logged_out"}


@router.get("/tenant", response_model=TenantResponse)
def get_tenant(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    membership = _membership_for(db, current_user.id)
    if membership is None:
        raise HTTPException(status_code=404, detail="No tenant membership")
    tenant = db.get(Tenant, membership.tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return TenantResponse(
        id=tenant.id, name=tenant.name, slug=tenant.slug, role=membership.role,
        plan=tenant.plan,
    )


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.get("/settings", response_model=UserSettingsResponse)
def get_settings(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    settings = db.query(UserSettings).filter(UserSettings.user_id == current_user.id).first()
    if not settings:
        settings = UserSettings(user_id=current_user.id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


@router.put("/settings", response_model=UserSettingsResponse)
def update_settings(
    body: UserSettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    settings = db.query(UserSettings).filter(UserSettings.user_id == current_user.id).first()
    if not settings:
        settings = UserSettings(user_id=current_user.id)
        db.add(settings)

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(settings, field, value)

    db.commit()
    db.refresh(settings)
    return settings
