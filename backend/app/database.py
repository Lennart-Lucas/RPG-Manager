from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import get_database_url_async, settings

engine = create_async_engine(
    get_database_url_async(),
    echo=settings.debug,
)

async_session_factory = async_sessionmaker(
    engine,
    expire_on_commit=False,
)


async def dispose_engine() -> None:
    await engine.dispose()


__all__ = ["engine", "async_session_factory", "dispose_engine"]
