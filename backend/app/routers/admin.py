from datetime import date, datetime, time, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..dependencies import get_current_admin
from ..models import DisasterResponse, User
from ..schemas import (
    DashboardSummary,
    DisasterResponseResponse,
    PaginatedResponses,
    ResponseStatusUpdate,
)
from .responses import _to_response

router = APIRouter(prefix="/admin", tags=["administration"])


@router.get("/summary", response_model=DashboardSummary)
def summary(admin: User = Depends(get_current_admin), db: Session = Depends(get_db)):
    del admin
    return DashboardSummary(
        total_citizens=db.scalar(select(func.count(User.id)).where(User.role == "citizen")) or 0,
        safe_responses=db.scalar(
            select(func.count(DisasterResponse.id)).where(DisasterResponse.response_type == "SAFE")
        ) or 0,
        help_requests=db.scalar(
            select(func.count(DisasterResponse.id)).where(DisasterResponse.response_type == "NEED_HELP")
        ) or 0,
        pending_responses=db.scalar(
            select(func.count(DisasterResponse.id)).where(DisasterResponse.rescue_status == "PENDING")
        ) or 0,
    )


@router.get("/responses", response_model=PaginatedResponses)
def list_responses(
    response_type: str | None = Query(default=None),
    rescue_status: str | None = Query(default=None),
    submitted_on: date | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    del admin
    query = select(DisasterResponse).options(joinedload(DisasterResponse.user))
    count_query = select(func.count(DisasterResponse.id))
    if response_type:
        query = query.where(DisasterResponse.response_type == response_type.upper())
        count_query = count_query.where(DisasterResponse.response_type == response_type.upper())
    if rescue_status:
        query = query.where(DisasterResponse.rescue_status == rescue_status.upper())
        count_query = count_query.where(DisasterResponse.rescue_status == rescue_status.upper())
    if submitted_on:
        start = datetime.combine(submitted_on, time.min, tzinfo=timezone.utc)
        end = datetime.combine(submitted_on, time.max, tzinfo=timezone.utc)
        query = query.where(DisasterResponse.submitted_at.between(start, end))
        count_query = count_query.where(DisasterResponse.submitted_at.between(start, end))

    total = db.scalar(count_query) or 0
    records = db.scalars(
        query.order_by(
            (DisasterResponse.response_type == "NEED_HELP").desc(),
            DisasterResponse.submitted_at.desc(),
        )
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return PaginatedResponses(
        items=[_to_response(record) for record in records],
        page=page,
        page_size=page_size,
        total=total,
    )


@router.get("/responses/{response_id}", response_model=DisasterResponseResponse)
def get_response(
    response_id: str,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    del admin
    response = db.scalar(
        select(DisasterResponse)
        .options(joinedload(DisasterResponse.user))
        .where(DisasterResponse.id == response_id)
    )
    if response is None:
        raise HTTPException(status_code=404, detail="Response not found")
    return _to_response(response)


@router.patch("/responses/{response_id}", response_model=DisasterResponseResponse)
def update_response_status(
    response_id: str,
    payload: ResponseStatusUpdate,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    response = db.scalar(
        select(DisasterResponse)
        .options(joinedload(DisasterResponse.user))
        .where(DisasterResponse.id == response_id)
    )
    if response is None:
        raise HTTPException(status_code=404, detail="Response not found")
    response.rescue_status = payload.rescue_status
    response.status_updated_by = admin.id
    db.commit()
    db.refresh(response)
    return _to_response(response)
