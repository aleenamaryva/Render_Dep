from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..dependencies import get_current_user
from ..models import DisasterResponse, User
from ..schemas import (
    DisasterResponseCreate,
    DisasterResponseResponse,
    MeshRelayBatchRequest,
    MeshRelayBatchResponse,
    PaginatedResponses,
)

router = APIRouter(prefix="/responses", tags=["disaster responses"])


@router.post("", response_model=DisasterResponseResponse, status_code=status.HTTP_201_CREATED)
def create_response(
    payload: DisasterResponseCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    response = DisasterResponse(
        user_id=user.id,
        disaster_id=payload.disaster_id,
        response_type=payload.response_type,
        latitude=payload.latitude,
        longitude=payload.longitude,
        is_mesh_relayed=False,
        hop_count=0,
    )
    db.add(response)
    db.commit()
    db.refresh(response)
    return _to_response(response)


@router.post("/mesh-relay", response_model=MeshRelayBatchResponse, status_code=status.HTTP_200_OK)
def relay_mesh_responses(
    payload: MeshRelayBatchRequest,
    relay_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    accepted_ids: list[str] = []
    ignored_count = 0

    for packet in payload.packets:
        if packet.packet_id:
            existing = db.scalar(select(DisasterResponse).where(DisasterResponse.packet_id == packet.packet_id))
            if existing:
                ignored_count += 1
                continue

        user = db.scalar(select(User).where(User.id == packet.user_id))
        if not user:
            user = User(
                id=packet.user_id,
                full_name=packet.citizen_name or "Offline Citizen",
                email=f"mesh_{packet.user_id[:8]}@lifetrace.mesh",
                password_hash="mesh_relay_user_placeholder",
                phone_number=packet.citizen_phone or "Unknown",
                emergency_contact_name=packet.emergency_contact_name or "Unknown",
                emergency_contact_phone=packet.emergency_contact_phone or "Unknown",
                blood_group=packet.blood_group or "N/A",
                role="citizen",
            )
            db.add(user)
            db.flush()

        response = DisasterResponse(
            user_id=user.id,
            disaster_id=packet.disaster_id,
            response_type=packet.response_type,
            latitude=packet.latitude,
            longitude=packet.longitude,
            submitted_at=packet.submitted_at or func.now(),
            packet_id=packet.packet_id,
            is_mesh_relayed=True,
            hop_count=packet.hop_count,
            relayed_by_user_id=relay_user.id,
        )
        db.add(response)
        accepted_ids.append(packet.packet_id)

    db.commit()
    return MeshRelayBatchResponse(
        accepted_count=len(accepted_ids),
        ignored_count=ignored_count,
        accepted_ids=accepted_ids,
    )


@router.get("", response_model=PaginatedResponses)
@router.get("/my", response_model=PaginatedResponses)
def get_my_responses(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = (
        select(DisasterResponse)
        .options(joinedload(DisasterResponse.user))
        .where(DisasterResponse.user_id == user.id)
        .order_by(DisasterResponse.submitted_at.desc())
    )
    total = db.scalar(
        select(func.count(DisasterResponse.id)).where(DisasterResponse.user_id == user.id)
    ) or 0
    items = db.scalars(query.offset((page - 1) * page_size).limit(page_size)).all()
    return PaginatedResponses(
        items=[_to_response(item) for item in items],
        page=page,
        page_size=page_size,
        total=total,
    )


def _to_response(response: DisasterResponse) -> DisasterResponseResponse:
    user = response.user
    return DisasterResponseResponse(
        id=response.id,
        user_id=user.id,
        citizen_name=user.full_name,
        citizen_email=user.email,
        citizen_phone=user.phone_number,
        emergency_contact_name=user.emergency_contact_name,
        emergency_contact_phone=user.emergency_contact_phone,
        disaster_id=response.disaster_id,
        response_type=response.response_type,
        rescue_status=response.rescue_status,
        latitude=response.latitude,
        longitude=response.longitude,
        submitted_at=response.submitted_at,
        status_updated_at=response.status_updated_at,
        status_updated_by=response.status_updated_by,
        packet_id=response.packet_id,
        is_mesh_relayed=response.is_mesh_relayed,
        hop_count=response.hop_count,
        relayed_by_user_id=response.relayed_by_user_id,
    )

