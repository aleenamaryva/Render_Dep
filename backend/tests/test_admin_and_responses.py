from sqlalchemy import select

from app.database import SessionLocal
from app.models import User
from app.security import hash_password

from test_auth import REGISTER_PAYLOAD, auth_header, register


def make_admin(client):
    payload = {**REGISTER_PAYLOAD, "email": "admin@example.com"}
    response = client.post("/register", json=payload)
    assert response.status_code == 201
    with SessionLocal() as db:
        admin = db.scalar(select(User).where(User.email == payload["email"]))
        admin.role = "admin"
        db.commit()
    login = client.post("/login", json={"email": payload["email"], "password": payload["password"]})
    return login


def create_response(client, response_type="NEED_HELP", latitude=51.5, longitude=-0.1, email=None):
    registration_payload = {**REGISTER_PAYLOAD}
    if email is not None:
        registration_payload["email"] = email
    registration = client.post("/register", json=registration_payload)
    return client.post(
        "/responses",
        headers=auth_header(registration),
        json={
            "disaster_id": "alert-1",
            "response_type": response_type,
            "latitude": latitude,
            "longitude": longitude,
        },
    )


def test_response_creation_and_coordinate_validation(client):
    response = create_response(client)
    assert response.status_code == 201
    assert response.json()["rescue_status"] == "PENDING"
    assert response.json()["latitude"] == 51.5

    invalid = create_response(client, latitude=91, email="second@example.com")
    assert invalid.status_code == 422


def test_citizen_cannot_access_admin_api(client):
    registration = register(client)
    response = client.get("/admin/summary", headers=auth_header(registration))
    assert response.status_code == 403


def test_admin_can_filter_paginate_and_update_response_status(client):
    response = create_response(client)
    response_id = response.json()["id"]
    admin_login = make_admin(client)
    headers = auth_header(admin_login)

    summary = client.get("/admin/summary", headers=headers)
    assert summary.status_code == 200
    assert summary.json()["help_requests"] == 1
    assert summary.json()["pending_responses"] == 1

    listing = client.get(
        "/admin/responses",
        headers=headers,
        params={"response_type": "NEED_HELP", "rescue_status": "PENDING", "page": 1, "page_size": 1},
    )
    assert listing.status_code == 200
    assert listing.json()["total"] == 1
    assert len(listing.json()["items"]) == 1

    updated = client.patch(
        f"/admin/responses/{response_id}",
        headers=headers,
        json={"rescue_status": "ASSIGNED"},
    )
    assert updated.status_code == 200
    assert updated.json()["rescue_status"] == "ASSIGNED"
    assert updated.json()["status_updated_by"] == admin_login.json()["user"]["id"]


def test_admin_endpoints_require_authentication(client):
    assert client.get("/admin/summary").status_code == 401
    assert client.get("/admin/responses").status_code == 401


def test_citizen_can_retrieve_own_responses(client):
    registration = register(client)
    headers = auth_header(registration)

    # Empty initially
    initial = client.get("/responses/my", headers=headers)
    assert initial.status_code == 200
    assert initial.json()["total"] == 0
    assert initial.json()["items"] == []

    # Submit response
    created = client.post(
        "/responses",
        headers=headers,
        json={
            "disaster_id": "alert-flood",
            "response_type": "SAFE",
            "latitude": 10.5,
            "longitude": 76.2,
        },
    )
    assert created.status_code == 201

    # Fetch response history
    my_responses = client.get("/responses/my", headers=headers)
    assert my_responses.status_code == 200
    assert my_responses.json()["total"] == 1
    assert len(my_responses.json()["items"]) == 1
    item = my_responses.json()["items"][0]
    assert item["response_type"] == "SAFE"
    assert item["latitude"] == 10.5
    assert item["longitude"] == 76.2
    assert item["disaster_id"] == "alert-flood"

