################################################################################
# FILE NAME   : test_idempotency.py
# DESCRIPTION : idempotency 게이트 — 동일 key 재시도·레이스에서 중복 row 차단
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

from decimal import Decimal

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Order, User
from app.service import create_order


def test_동일_idempotency_key_재시도는_기존_주문_반환(
    session: Session, synthetic_user: User
) -> None:
    # Arrange / Act: 같은 key로 두 번 호출
    first = create_order(
        session, synthetic_user.id, "retry-key-1", Decimal("10.00")
    )
    second = create_order(
        session, synthetic_user.id, "retry-key-1", Decimal("10.00")
    )

    # Assert: 같은 주문, 중복 row 없음
    assert first.id == second.id
    assert session.scalar(select(func.count()).select_from(Order)) == 1


def test_동시_삽입_레이스에서도_중복_row_없음(
    session: Session, synthetic_user: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Arrange: 선행 주문이 이미 커밋된 상태
    create_order(session, synthetic_user.id, "race-key-1", Decimal("10.00"))

    #---------------------------------------------------------------------------
    # 사전 조회가 None을 반환하는 레이스 재현 — 첫 scalar 호출만 가로채
    # "조회 시점엔 없었지만 삽입 시점엔 존재"하는 동시성 상황을 만든다
    #---------------------------------------------------------------------------
    real_scalar = session.scalar
    call_state = {"count": 0}

    def racy_scalar(statement: object) -> object:
        call_state["count"] += 1
        if call_state["count"] == 1:
            return None
        return real_scalar(statement)

    monkeypatch.setattr(session, "scalar", racy_scalar)

    # Act: unique 제약 충돌 → 기존 주문 반환 경로
    winner = create_order(
        session, synthetic_user.id, "race-key-1", Decimal("10.00")
    )

    # Assert: 예외 없이 기존 주문, row는 여전히 1개
    assert winner.idempotency_key == "race-key-1"
    assert real_scalar(select(func.count()).select_from(Order)) == 1
