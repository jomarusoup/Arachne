################################################################################
# FILE NAME   : service.py
# DESCRIPTION : 서비스 계층 — commit/rollback 책임 단일 경계, idempotency key 처리
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import Order, User


#===============================================================================
# FUNCTION    : create_order
# DESCRIPTION : idempotency key 기반 주문 생성 — 동일 key 재시도는 기존 주문 반환.
#               레이스로 사전 조회를 통과해도 unique 제약이 중복을 차단한다.
# PARAMETERS  : Session session     - 요청 단위 DB 세션
#               int user_id         - 주문자
#               str idempotency_key - 클라이언트 재시도 식별자
#               Decimal amount      - 금액 (float 금지)
#               str currency        - 통화 코드
# RETURNED    : Order 생성됐거나 이미 존재하는 주문
#===============================================================================
def create_order(
    session: Session,
    user_id: int,
    idempotency_key: str,
    amount: Decimal,
    currency: str = "KRW",
) -> Order:
    existing = session.scalar(
        select(Order).where(Order.idempotency_key == idempotency_key)
    )
    if existing is not None:
        return existing

    order = Order(
        user_id=user_id,
        idempotency_key=idempotency_key,
        amount=amount,
        currency=currency,
    )
    session.add(order)
    try:
        session.commit()
    except IntegrityError:
        #-----------------------------------------------------------------------
        # 동시 삽입 레이스 — unique 제약이 막은 경우 기존 row를 반환
        #-----------------------------------------------------------------------
        session.rollback()
        winner = session.scalar(
            select(Order).where(Order.idempotency_key == idempotency_key)
        )
        if winner is None:
            raise
        return winner
    return order


#===============================================================================
# FUNCTION    : register_user_with_first_order
# DESCRIPTION : 사용자 + 첫 주문을 단일 트랜잭션으로 생성 — 주문 실패 시
#               사용자도 남지 않는다 (부분 커밋 금지)
# PARAMETERS  : Session session     - 요청 단위 DB 세션
#               str email           - 사용자 이메일 (PII)
#               str password_hash   - 해시된 비밀번호 (secret)
#               str display_name    - 공개 표시명
#               str idempotency_key - 첫 주문 재시도 식별자
#               Decimal amount      - 첫 주문 금액
# RETURNED    : tuple[User, Order] 생성된 사용자와 주문
#===============================================================================
def register_user_with_first_order(
    session: Session,
    email: str,
    password_hash: str,
    display_name: str,
    idempotency_key: str,
    amount: Decimal,
) -> tuple[User, Order]:
    try:
        user = User(
            email=email, password_hash=password_hash, display_name=display_name
        )
        session.add(user)
        session.flush()

        order = Order(
            user_id=user.id, idempotency_key=idempotency_key, amount=amount
        )
        session.add(order)
        session.commit()
    except Exception:
        session.rollback()
        raise
    return user, order
