################################################################################
# FILE NAME   : test_schema_snapshot.py
# DESCRIPTION : schema 계약 게이트 — snapshot 비교·breaking change 검출·직렬화 형식
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

import json
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.contract import detect_breaking_changes, export_contract
from app.schemas import OrderCreate, OrderOut

SNAPSHOT_PATH = Path(__file__).parent / "snapshots" / "order_out.schema.json"


def test_OrderOut_계약이_snapshot과_일치한다() -> None:
    # Arrange
    snapshot = json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))

    # Act / Assert: breaking change 없음 — 의도적 변경이면 snapshot을 갱신하고
    # diff를 리뷰에 포함한다 (docs/DATA-HANDLING.md)
    assert detect_breaking_changes(snapshot, export_contract(OrderOut)) == []


def test_필드_제거는_breaking_change로_검출된다() -> None:
    # Arrange: 현재 계약에서 amount 필드를 제거한 변형
    current = export_contract(OrderOut)
    mutated = {name: spec for name, spec in current.items() if name != "amount"}

    # Act / Assert: 게이트가 제거를 검출 → CI 실패 경로
    assert detect_breaking_changes(current, mutated) == ["removed: amount"]


def test_타입_변경과_신규_필수_필드도_검출된다() -> None:
    # Arrange
    current = export_contract(OrderOut)
    mutated = json.loads(json.dumps(current))
    mutated["amount"]["type"] = "float"
    mutated["coupon_code"] = {"type": "str", "required": True}

    # Act / Assert
    assert detect_breaking_changes(current, mutated) == [
        "type-changed: amount",
        "new-required: coupon_code",
    ]


def test_금액은_손실없는_문자열로_직렬화된다() -> None:
    # Arrange: float이면 0.1 오차가 생기는 값
    order = OrderOut(
        id=1,
        user_id=1,
        idempotency_key="json-key-1",
        amount=Decimal("10.10"),
        currency="KRW",
        status="pending",
        created_at=datetime(2026, 6, 11, 0, 0, tzinfo=timezone.utc),
    )

    # Act
    payload = json.loads(order.model_dump_json())

    # Assert: Decimal → 문자열, datetime → tz 포함 RFC 3339
    assert payload["amount"] == "10.10"
    assert payload["created_at"].endswith(("Z", "+00:00"))


def test_unknown_field_입력은_거부된다() -> None:
    # Arrange / Act / Assert: 묵묵한 drop 금지 (extra="forbid")
    with pytest.raises(ValidationError):
        OrderCreate(
            user_id=1,
            idempotency_key="forbid-key-1",
            amount=Decimal("10.00"),
            unknown_field="dropped-silently",
        )
