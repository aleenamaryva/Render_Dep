# LifeTrace FastAPI Backend

This backend provides the first server-side authentication layer for LifeTrace:

```text
Flutter Android app -> FastAPI -> PostgreSQL
```

Firebase Authentication, Firebase Cloud Messaging, OpenStreetMap, and rescue prioritization are intentionally not included.

## Requirements

- Python 3.11 or newer (tested with Python 3.12)
- PostgreSQL 14 or newer
- Flutter for the Android client

## Backend structure

```text
backend/
  app/
    config.py          # Environment settings
    database.py        # SQLAlchemy engine and sessions
    dependencies.py    # Bearer-token and database dependencies
    main.py            # FastAPI application
    models.py          # SQLAlchemy models
    schemas.py         # Pydantic request/response validation
    security.py        # Argon2 password hashing and JWTs
    routers/auth.py    # Authentication endpoints
    routers/responses.py
    routers/admin.py   # Protected admin endpoints
  admin/               # Map-free browser dashboard
  alembic/
    env.py
    versions/0001_initial.py
    versions/0002_roles_and_response_status.py
  tests/
  .env.example
  requirements.txt
  alembic.ini
```

## 1. Create a virtual environment

From the repository root in PowerShell:

```powershell
cd C:\Users\ALEENA\softwarep1\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

If PowerShell blocks activation, run this once in an elevated or permitted shell, or use:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

## 2. Create PostgreSQL database and user

Using `psql` as a PostgreSQL administrator:

```sql
CREATE USER lifetrace WITH PASSWORD 'replace-with-a-real-password';
CREATE DATABASE lifetrace OWNER lifetrace;
```

Do not use these example values as production credentials.

## 3. Configure environment variables

Copy the example file:

```powershell
Copy-Item .env.example .env
```

Edit `.env` with a real long secret and your PostgreSQL password:

```dotenv
DATABASE_URL=postgresql+psycopg://lifetrace:your-password@localhost:5432/lifetrace
JWT_SECRET_KEY=generate-a-long-random-secret
ACCESS_TOKEN_EXPIRE_MINUTES=30
CORS_ORIGINS=http://localhost:3000
```

`.env` is ignored by Git. Never commit database passwords or JWT secrets.

## 4. Run database migrations

With `.venv` active and PostgreSQL running:

```powershell
alembic upgrade head
```

The initial migration creates:

- `users`, including an Argon2 password hash and profile/emergency fields
- `disaster_responses`, ready for the next authenticated response-sync phase
- `revoked_tokens`, used to invalidate JWTs on logout

Flutter now obtains GPS only when the citizen taps a response button, posts the coordinates to `POST /responses`, and updates local history only after the backend accepts the record. Offline queueing is not implemented yet, so a failed request is shown as an error and is not reported as saved.

## 5. Start FastAPI

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open Swagger UI at:

```text
http://127.0.0.1:8000/docs
```

Health check:

```text
http://127.0.0.1:8000/health
```

## 6. Authentication API

### `POST /register`

Accepts the same fields collected by the Flutter registration screen:

```json
{
  "full_name": "Test Citizen",
  "phone_number": "+1234567890",
  "email": "citizen@example.com",
  "emergency_contact_name": "Emergency Contact",
  "emergency_contact_phone": "+1987654321",
  "blood_group": "O+",
  "medical_information": "No known allergies",
  "password": "correct-password"
}
```

Returns `201` with `access_token`, `token_type`, and a `user` object. Passwords are hashed with Argon2 and are never returned.

### `POST /login`

```json
{
  "email": "citizen@example.com",
  "password": "correct-password"
}
```

Returns `401` for invalid credentials.

### `GET /users/me`

Send:

```text
Authorization: Bearer <access_token>
```

Returns only the authenticated user's profile.

### `POST /logout`

Send the same bearer token. Its JWT ID is stored in `revoked_tokens`, so the token cannot be reused after logout until it would otherwise expire.

### `POST /responses`

This authenticated endpoint accepts `disaster_id`, `response_type`, `latitude`, and `longitude`. Coordinates are range-validated and each record starts with rescue status `PENDING`.

## Admin dashboard

Create the first administrator from the backend virtual environment. The password is entered through a private prompt and is never stored in source code:

```powershell
cd C:\Users\ALEENA\softwarep1\backend
.\.venv\Scripts\python.exe -m app.create_admin --email admin@example.com --name "LifeTrace Admin" --phone "+1234567890"
```

Public registration always creates a `citizen` role. It cannot assign an administrator role.

Start the backend and open the dashboard at:

```text
http://127.0.0.1:8000/dashboard/
```

The dashboard uses protected FastAPI endpoints and contains no maps or mapping APIs. It provides summary counts, urgent response ordering, filters, pagination, response details, and `PENDING`/`ASSIGNED`/`RESOLVED` status updates. Coordinates are displayed as text; missing coordinates are displayed as `Location unavailable`.

Admin endpoints:

- `GET /admin/summary`
- `GET /admin/responses`
- `GET /admin/responses/{response_id}`
- `PATCH /admin/responses/{response_id}`

Citizens receive HTTP `403` from these endpoints, and unauthenticated callers receive HTTP `401`.

## 7. Connect Flutter

The Flutter client reads the base URL from `API_BASE_URL` and has no invented default URL.

Android emulator:

```powershell
cd C:\Users\ALEENA\softwarep1
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Physical Android phone:

1. Find the computer's LAN address with `ipconfig`.
2. Start Uvicorn with `--host 0.0.0.0`.
3. Put the computer and phone on the same Wi-Fi network.
4. Allow Python/Uvicorn through the Windows firewall on the private network.
5. Run, replacing the address with the computer's LAN IPv4 address:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000
```

These plain HTTP URLs are for local development only. Production must use HTTPS and a protected deployment.

After the hosted HTTPS API has been verified, build a production APK with its real URL:

```powershell
cd C:\Users\ALEENA\softwarep1
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST
```

The APK will be generated at `build\app\outputs\flutter-apk\app-release.apk`. Do not replace `YOUR_API_HOST` until the backend provider has assigned and verified the public HTTPS hostname.

## 8. Public deployment

The repository includes `Dockerfile`, `.dockerignore`, and `render.yaml` for a beginner-friendly Render web service deployment. Use Render for the FastAPI service and a managed PostgreSQL provider such as Render PostgreSQL, Neon, or Supabase for the database. Do not expose PostgreSQL directly to the public internet; only the FastAPI service should connect to it.

Deployment requires manual provider setup and credentials; this project does not contain a public URL.

1. Create a managed PostgreSQL database with your chosen provider.
2. Create a Render Web Service from this repository, using the included `render.yaml`, or configure Docker manually with `backend/Dockerfile` and the repository root as the Docker context.
3. Set these service environment variables in the hosting provider dashboard:

```text
DATABASE_URL=<managed PostgreSQL connection URL>
JWT_SECRET_KEY=<long random secret>
ACCESS_TOKEN_EXPIRE_MINUTES=30
CORS_ORIGINS=<dashboard origin, or an allowed comma-separated list>
```

4. Deploy and verify:

```text
https://YOUR_API_HOST/health
https://YOUR_API_HOST/docs
https://YOUR_API_HOST/dashboard/
```

The included Docker command runs `alembic upgrade head` before Uvicorn starts. For a provider that separates release commands, run `alembic upgrade head` once as the release/migration command and start the service with:

```text
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

Do not claim public availability until `/health`, `/docs`, registration, login, response submission, and the admin dashboard have been tested through the hosted HTTPS URL.

## 9. Run tests

Backend tests use an isolated SQLite database and do not require PostgreSQL:

```powershell
cd C:\Users\ALEENA\softwarep1\backend
.\.venv\Scripts\python.exe -m pytest
```

Flutter tests remain:

```powershell
cd C:\Users\ALEENA\softwarep1
flutter pub get
flutter analyze
flutter test
```

## Common errors

- `connection refused`: PostgreSQL is stopped, the port is wrong, or the database URL is incorrect.
- `password authentication failed`: check the PostgreSQL user/password in `.env`.
- `database does not exist`: create the `lifetrace` database before running Alembic.
- Phone cannot connect: use the computer LAN IP, not `localhost` or `127.0.0.1`; confirm both devices share Wi-Fi and the firewall allows port 8000.
- `Backend not connected` in Flutter: pass `--dart-define=API_BASE_URL=...` when launching the app.
- `401` after logout: expected; logout revokes the JWT.
- `403` on `/admin`: the signed-in account is a citizen; create/promote an admin with the bootstrap command.

## Security notes

JWT access tokens expire after the configured period and are revoked on logout. The current Flutter client keeps the token in memory only, so restarting the app requires logging in again. A later phase should add secure token storage and HTTPS before production use.
