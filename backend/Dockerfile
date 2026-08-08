# Build from repository root:
#   docker build -f backend/Dockerfile .
# Compose sets context to the parent of backend/ (repo root).

# ---- Flutter web (player site) ----
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /src
# Path packages must exist before `flutter pub get` (see frontend/pubspec.yaml).
COPY frontend/pubspec.yaml frontend/pubspec.lock ./frontend/
COPY packages/random_table_engine ./packages/random_table_engine
WORKDIR /src/frontend
RUN flutter config --no-analytics \
    && flutter pub get
COPY frontend/ ./
# Empty API_BASE_URL → same-origin when served from this API.
RUN flutter build web --release --dart-define=API_BASE_URL=

# ---- API + static web ----
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
COPY --from=web /src/frontend/build/web ./static/web

RUN sed -i 's/\r$//' scripts/docker-entrypoint-dev.sh scripts/docker-entrypoint-prod.sh \
    && chmod +x scripts/docker-entrypoint-dev.sh scripts/docker-entrypoint-prod.sh

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
