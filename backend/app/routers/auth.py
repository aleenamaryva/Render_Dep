from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..dependencies import current_token, get_current_user
from ..models import RevokedToken, User
from ..schemas import AuthResponse, LoginRequest, MessageResponse, RegisterRequest, UserResponse
from ..security import create_access_token, hash_password, verify_password
from ..database import get_db

router = APIRouter(tags=["authentication"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    email = str(payload.email).lower()
    existing = db.scalar(select(User).where(User.email == email))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account already exists for this email")

    user = User(
        full_name=payload.full_name.strip(),
        email=email,
        password_hash=hash_password(payload.password),
        phone_number=payload.phone_number.strip(),
        emergency_contact_name=payload.emergency_contact_name.strip(),
        emergency_contact_phone=payload.emergency_contact_phone.strip(),
        blood_group=payload.blood_group.strip(),
        medical_information=payload.medical_information,
        role="citizen",
    )
    db.add(user)
    try:
        db.commit()
        db.refresh(user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account already exists for this email")
    return _auth_response(user)


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    email = str(payload.email).lower()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="The email or password is incorrect")
    return _auth_response(user)


@router.get("/users/me", response_model=UserResponse)
def users_me(user: User = Depends(get_current_user)):
    return user


@router.post("/logout", response_model=MessageResponse)
def logout(
    token_data: tuple[str, dict] = Depends(current_token),
    db: Session = Depends(get_db),
):
    _, payload = token_data
    if db.get(RevokedToken, payload["jti"]) is None:
        expires_at = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        db.add(RevokedToken(jti=payload["jti"], expires_at=expires_at))
        db.commit()
    return {"message": "Logged out successfully"}


def _auth_response(user: User) -> AuthResponse:
    token, _, _ = create_access_token(user.id)
    return AuthResponse(
        access_token=token,
        user=UserResponse.model_validate(user),
    )
