from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)
    phone_number: str = Field(min_length=7, max_length=30)
    email: EmailStr
    emergency_contact_name: str = Field(min_length=1, max_length=120)
    emergency_contact_phone: str = Field(min_length=7, max_length=30)
    blood_group: str = Field(min_length=1, max_length=10)
    medical_information: str | None = None
    password: str = Field(min_length=6, max_length=128)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    phone_number: str
    email: EmailStr
    role: str
    emergency_contact_name: str
    emergency_contact_phone: str
    blood_group: str
    medical_information: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class AuthResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    user: UserResponse


class MessageResponse(BaseModel):
    message: str


class DisasterResponseCreate(BaseModel):
    disaster_id: str | None = None
    response_type: Literal["SAFE", "NEED_HELP"]
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)

    @field_validator("response_type")
    @classmethod
    def normalize_response_type(cls, value: str) -> str:
        return value.upper()


class DisasterResponseResponse(BaseModel):
    id: str
    user_id: str
    citizen_name: str
    citizen_email: EmailStr
    citizen_phone: str
    emergency_contact_name: str
    emergency_contact_phone: str
    disaster_id: str | None = None
    response_type: Literal["SAFE", "NEED_HELP"]
    rescue_status: Literal["PENDING", "ASSIGNED", "RESOLVED"]
    latitude: float
    longitude: float
    submitted_at: datetime
    status_updated_at: datetime | None = None
    status_updated_by: str | None = None
    packet_id: str | None = None
    is_mesh_relayed: bool = False
    hop_count: int = 0
    relayed_by_user_id: str | None = None


class MeshPacketIn(BaseModel):
    packet_id: str
    user_id: str
    citizen_name: str | None = None
    citizen_phone: str | None = None
    emergency_contact_name: str | None = None
    emergency_contact_phone: str | None = None
    blood_group: str | None = None
    disaster_id: str | None = None
    response_type: Literal["SAFE", "NEED_HELP"]
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    submitted_at: datetime | None = None
    hop_count: int = 0
    relayed_by: list[str] = []


class MeshRelayBatchRequest(BaseModel):
    packets: list[MeshPacketIn]


class MeshRelayBatchResponse(BaseModel):
    accepted_count: int
    ignored_count: int
    accepted_ids: list[str]


class ResponseStatusUpdate(BaseModel):
    rescue_status: Literal["PENDING", "ASSIGNED", "RESOLVED"]


class PaginatedResponses(BaseModel):
    items: list[DisasterResponseResponse]
    page: int
    page_size: int
    total: int


class DashboardSummary(BaseModel):
    total_citizens: int
    safe_responses: int
    help_requests: int
    pending_responses: int

