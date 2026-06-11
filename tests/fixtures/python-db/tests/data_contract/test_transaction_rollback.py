################################################################################
# FILE NAME   : test_transaction_rollback.py
# DESCRIPTION : 트랜잭션 게이트 — 실패한 service operation의 rollback 검증
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

from decimal import Decimal

import pytest
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import Order, User
from app.service import register_user_with_first_order


def test_실패한_작업은_부분_커밋을_남기지_않는다(session: Session) -> None:
    # Arrange: check 제약(amount >= 0)을 위반하는 주문 금액
    invalid_amount = Decimal("-1.00")

    # Act: 사용자 + 주문 단일 트랜잭션이 주문 단계에서 실패
    with pytest.raises(IntegrityError):
        register_user_with_first_order(
            session,
            email="user2@example.com",
            password_hash="test-password-hash",
            display_name="rollback-user",
            idempotency_key="rollback-key-1",
            amount=invalid_amount,
        )

    # Assert: 사용자·주문 모두 남지 않음 (부분 커밋 금지)
    assert session.scalar(select(func.count()).select_from(User)) == 0
    assert session.scalar(select(func.count()).select_from(Order)) == 0


def test_정상_작업은_사용자와_주문을_함께_커밋한다(session: Session) -> None:
    # Arrange / Act
    user, order = register_user_with_first_order(
        session,
        email="user3@example.com",
        password_hash="test-password-hash",
        display_name="commit-user",
        idempotency_key="commit-key-1",
        amount=Decimal("10.00"),
    )

    # Assert
    assert order.user_id == user.id
    assert session.scalar(select(func.count()).select_from(Order)) == 1
