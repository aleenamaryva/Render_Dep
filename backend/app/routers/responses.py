from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..dependencies import get_current_user
from ..models import DisasterResponse, User
from ..schemas import DisasterResponseCreate, DisasterResponseResponse, PaginatedResponses

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
    )
    db.add(response)
    db.commit()
    db.refresh(response)
    return _to_response(response)


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
    )
