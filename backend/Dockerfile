# Build from repository root:
#   docker build -f backend/Dockerfile .
# Compose sets context to the parent of backend/ (repo root).
#
# Player website: build on the deploy machine first
#   (backend/scripts/build-web.ps1) so backend/static/web exists.
# The VPS never runs Flutter.

FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/alembic.ini .
COPY backend/alembic ./alembic
COPY backend/app ./app
COPY backend/scripts ./scripts
COPY backend/static/web ./static/web

RUN test -f static/web/index.html \
    || (echo "Missing backend/static/web/index.html — run backend/scripts/build-web.ps1 first" >&2 && exit 1)

RUN sed -i 's/\r$//' scripts/docker-entrypoint-dev.sh scripts/docker-entrypoint-prod.sh \
    && chmod +x scripts/docker-entrypoint-dev.sh scripts/docker-entrypoint-prod.sh

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
