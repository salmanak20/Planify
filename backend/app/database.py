"""
Database configuration for Planify.
Uses SQLite (aiosqlite) for local development.
To switch to PostgreSQL, change DATABASE_URL in .env to:
  postgresql+asyncpg://user:password@localhost/planify
"""

from sqlalchemy import (
    Column, Integer, String, Text, Boolean, DateTime,
    ForeignKey, Enum, MetaData, Table, create_engine, event, text
)
from sqlalchemy.orm import declarative_base, relationship
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from databases import Database
from datetime import datetime
import enum

from app.core.config import settings

# ── Async engine for runtime queries ──────────────────────────────────────────
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    connect_args={"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {}
)

@event.listens_for(engine.sync_engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    if "sqlite" in settings.DATABASE_URL:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA synchronous=NORMAL")
        cursor.close()

AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()

# ── Sync engine used only for create_all at startup ───────────────────────────
_sync_url = settings.DATABASE_URL.replace("+aiosqlite", "").replace("+asyncpg", "")
_sync_engine = create_engine(
    _sync_url,
    connect_args={"check_same_thread": False} if "sqlite" in _sync_url else {}
)


async def init_db():
    """Create all tables on startup and enable WAL."""
    Base.metadata.create_all(bind=_sync_engine)
    # Also set WAL on the sync engine connection to be sure
    with _sync_engine.connect() as conn:
        conn.execute(text("PRAGMA journal_mode=WAL"))
        conn.execute(text("PRAGMA synchronous=NORMAL"))
        conn.commit()


async def get_db() -> AsyncSession:
    """FastAPI dependency: yields an async DB session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            # We still keep this as a safety net, but routes should commit explicitly for speed/feedback
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
