FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install production dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini .
COPY admin ./admin

# SQLite database will be stored on Render's persistent disk at /data
# The DATABASE_URL env var should be: sqlite:////data/lifetrace.db
RUN mkdir -p /data

EXPOSE 8000

# On startup: run migrations then start the server
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
