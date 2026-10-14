from sqlalchemy import select

from app.database import SessionLocal
from app.models import User


REGISTER_PAYLOAD = {
    "full_name": "Test Citizen",
    "phone_number": "+1234567890",
    "email": "citizen@example.com",
    "emergency_contact_name": "Emergency Contact",
    "emergency_contact_phone": "+1987654321",
    "blood_group": "O+",
    "medical_information": "No known allergies",
    "password": "correct-password",
}


def register(client):
    return client.post("/register", json=REGISTER_PAYLOAD)


def login(client, password="correct-password"):
    return client.post(
        "/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": password},
    )


def auth_header(response):
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_successful_registration_and_password_hashing(client):
    response = register(client)

    assert response.status_code == 201
    assert response.json()["user"]["email"] == REGISTER_PAYLOAD["email"]
    assert "password_hash" not in response.json()["user"]

    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.email == REGISTER_PAYLOAD["email"]))
        assert user is not None
        assert user.password_hash != REGISTER_PAYLOAD["password"]
        assert user.password_hash.startswith("$argon2")


def test_duplicate_registration_is_rejected(client):
    assert register(client).status_code == 201
    response = register(client)
    assert response.status_code == 409
    assert "already exists" in response.json()["detail"]


def test_successful_login(client):
    register(client)
    response = login(client)
    assert response.status_code == 200
    assert response.json()["token_type"] == "bearer"
    assert response.json()["user"]["email"] == REGISTER_PAYLOAD["email"]


def test_incorrect_password_is_rejected(client):
    register(client)
    response = login(client, password="wrong-password")
    assert response.status_code == 401


def test_users_me_requires_valid_token(client):
    response = client.get("/users/me")
    assert response.status_code == 401

    registration = register(client)
    response = client.get("/users/me", headers=auth_header(registration))
    assert response.status_code == 200
    assert response.json()["full_name"] == REGISTER_PAYLOAD["full_name"]
    assert "password_hash" not in response.json()


def test_logout_revokes_token(client):
    registration = register(client)
    headers = auth_header(registration)

    response = client.post("/logout", headers=headers)
    assert response.status_code == 200
    assert response.json()["message"] == "Logged out successfully"

    response = client.get("/users/me", headers=headers)
    assert response.status_code == 401


def test_registration_validation_rejects_missing_fields(client):
    response = client.post("/register", json={"email": "not-an-email", "password": "123"})
    assert response.status_code == 422
