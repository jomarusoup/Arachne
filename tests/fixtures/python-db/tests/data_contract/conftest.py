################################################################################
# FILE NAME   : conftest.py
# DESCRIPTION : data contract 게이트 공용 fixture — in-memory DB·합성 사용자
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

from collections.abc import Iterator

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.models import Base, User


@pytest.fixture()
def session() -> Iterator[Session]:
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with Session(engine) as db_session:
        yield db_session
    engine.dispose()


@pytest.fixture()
def synthetic_user(session: Session) -> User:
    # 합성 데이터만 — 실제 개인정보 금지 (docs/DATA-HANDLING.md fixture 기준)
    user = User(
        email="user1@example.com",
        password_hash="test-password-hash",
        display_name="fixture-user",
    )
    session.add(user)
    session.commit()
    return user
