from contextlib import asynccontextmanager
import logging
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.routes import auth, authors, catalog, extract, files, health
from app.config import settings
from app.database import dispose_engine
from app.middleware.security_headers import SecurityHeadersMiddleware

logger = logging.getLogger(__name__)

STATIC_WEB_DIR = Path(__file__).resolve().parent.parent / "static" / "web"


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await dispose_engine()


def create_app() -> FastAPI:
    docs_url = None if settings.is_production else "/docs"
    redoc_url = None if settings.is_production else "/redoc"
    openapi_url = None if settings.is_production else "/openapi.json"

    app = FastAPI(
        title="RPG Manager API",
        version="0.1.0",
        lifespan=lifespan,
        docs_url=docs_url,
        redoc_url=redoc_url,
        openapi_url=openapi_url,
    )

    app.state.limiter = auth.limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(
        request: Request, exc: Exception
    ) -> JSONResponse:
        if isinstance(exc, (HTTPException, RequestValidationError)):
            raise exc
        logger.exception(
            "Unhandled error on %s %s", request.method, request.url.path
        )
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"},
        )

    app.add_middleware(SlowAPIMiddleware)
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_origin_regex=settings.effective_cors_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health.router)
    app.include_router(auth.router, prefix=settings.api_prefix)
    app.include_router(authors.router, prefix=settings.api_prefix)
    app.include_router(files.router, prefix=settings.api_prefix)
    app.include_router(catalog.search_router, prefix=settings.api_prefix)
    app.include_router(catalog.router, prefix=settings.api_prefix)
    app.include_router(extract.router, prefix=settings.api_prefix)

    if STATIC_WEB_DIR.is_dir():
        index_html = STATIC_WEB_DIR / "index.html"
        static_root = STATIC_WEB_DIR.resolve()
        _no_cache_names = {
            "index.html",
            "flutter_bootstrap.js",
            "flutter.js",
            "main.dart.js",
            "version.json",
            "flutter_service_worker.js",
            ".last_build_id",
            "manifest.json",
        }

        def _file_response(path: Path) -> FileResponse:
            # Entrypoint JS/HTML must not stick in the browser after deploys.
            if path.name.lower() in _no_cache_names:
                headers = {"Cache-Control": "no-cache, must-revalidate"}
            else:
                headers = {"Cache-Control": "public, max-age=86400"}
            return FileResponse(path, headers=headers)

        def _reserved_spa_path(full_path: str) -> bool:
            p = full_path.lower().strip("/")
            if not p:
                return False
            if p == "health" or p.startswith("health/"):
                return True
            if p == "api" or p.startswith("api/"):
                return True
            if p in {"docs", "redoc", "openapi.json"}:
                return True
            if p.startswith("docs/") or p.startswith("redoc/"):
                return True
            return False

        @app.get("/")
        async def serve_web_index() -> FileResponse:
            if not index_html.is_file():
                raise HTTPException(status_code=404, detail="Web UI not built")
            return _file_response(index_html)

        @app.get("/{full_path:path}")
        async def serve_web_spa(full_path: str) -> FileResponse:
            if _reserved_spa_path(full_path):
                raise HTTPException(status_code=404, detail="Not found")

            candidate = (STATIC_WEB_DIR / full_path).resolve()
            try:
                candidate.relative_to(static_root)
            except ValueError as exc:
                raise HTTPException(status_code=404, detail="Not found") from exc

            if candidate.is_file():
                return _file_response(candidate)
            if index_html.is_file():
                return _file_response(index_html)
            raise HTTPException(status_code=404, detail="Web UI not built")
    else:
        logger.warning(
            "Flutter web build not found at %s — API-only mode", STATIC_WEB_DIR
        )

    return app


app = create_app()
