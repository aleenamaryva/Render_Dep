from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False, default="citizen", server_default="citizen")
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(30), nullable=False)
    emergency_contact_name: Mapped[str] = mapped_column(String(120), nullable=False)
    emergency_contact_phone: Mapped[str] = mapped_column(String(30), nullable=False)
    blood_group: Mapped[str] = mapped_column(String(10), nullable=False)
    medical_information: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    responses: Mapped[list["DisasterResponse"]] = relationship(
        back_populates="user",
        foreign_keys="DisasterResponse.user_id",
    )


class DisasterResponse(Base):
    __tablename__ = "disaster_responses"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    disaster_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    response_type: Mapped[str] = mapped_column(String(20), nullable=False)
    rescue_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="PENDING", server_default="PENDING"
    )
    latitude: Mapped[float] = mapped_column(nullable=False)
    longitude: Mapped[float] = mapped_column(nullable=False)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    status_updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    status_updated_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    packet_id: Mapped[str | None] = mapped_column(String(64), unique=True, index=True, nullable=True)
    is_mesh_relayed: Mapped[bool] = mapped_column(Boolean, default=False, server_default="0", nullable=False)
    hop_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    relayed_by_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)

    user: Mapped[User] = relationship(
        back_populates="responses",
        foreign_keys=[user_id],
    )


class RevokedToken(Base):
    __tablename__ = "revoked_tokens"

    jti: Mapped[str] = mapped_column(String(36), primary_key=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
