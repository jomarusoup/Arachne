################################################################################
# FILE NAME   : schemas.py
# DESCRIPTION : Pydantic v2 입력·출력 스키마 — 입력 extra=forbid, 출력 allow-list,
#               Decimal→문자열·tz-aware datetime 직렬화 (skills/json-contracts 준수)
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, field_serializer

from app.models import OrderStatus


#-------------------------------------------------------------------------------
# 입력 스키마 — unknown field 거부 (묵묵한 drop 금지)
#-------------------------------------------------------------------------------
class OrderCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_id: int
    idempotency_key: str
    amount: Decimal
    currency: str = "KRW"


#-------------------------------------------------------------------------------
# 출력 스키마 — 분류표 allow-list 기반, raw ORM 직접 노출 금지
#-------------------------------------------------------------------------------
class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    idempotency_key: str
    amount: Decimal
    currency: str
    status: OrderStatus
    created_at: datetime

    #===========================================================================
    # FUNCTION    : serialize_amount
    # DESCRIPTION : 금액 Decimal을 손실 없는 문자열로 직렬화 (float 금지)
    # PARAMETERS  : Decimal value - 금액
    # RETURNED    : str 소수점 보존 문자열
    #===========================================================================
    @field_serializer("amount", when_used="json")
    def serialize_amount(self, value: Decimal) -> str:
        return format(value, "f")


class UserOut(BaseModel):
    """공개 표면 — PII(email)·secret(password_hash) 미포함."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    display_name: str
    created_at: datetime


class UserPrivateOut(BaseModel):
    """소유자 전용 표면 — email은 인가 범위 allow-list로만 노출."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    display_name: str
    created_at: datetime


# 소유자 응답에서 인가된 PII 필드 (docs/DATA-HANDLING.md ⚠️ 소유자·인가 범위)
OWNER_ALLOWED_FIELDS: frozenset[str] = frozenset({"email"})
