################################################################################
# FILE NAME   : test_pii_exposure.py
# DESCRIPTION : PII 게이트 — 응답 표면의 PII·secret 노출과 미분류 필드 차단
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

from datetime import datetime, timezone

from app.classification import find_exposed_fields, find_unclassified_fields
from app.schemas import OWNER_ALLOWED_FIELDS, UserOut, UserPrivateOut

SYNTHETIC_CREATED_AT = datetime(2026, 6, 11, 0, 0, tzinfo=timezone.utc)


def test_공개_응답은_PII와_secret을_노출하지_않는다() -> None:
    # Arrange: 공개 표면 직렬화
    payload = UserOut(
        id=1, display_name="fixture-user", created_at=SYNTHETIC_CREATED_AT
    ).model_dump()

    # Act / Assert: 차단 등급 노출 없음 + 미분류 필드 없음
    assert find_exposed_fields("users", payload) == []
    assert find_unclassified_fields("users", payload) == []


def test_소유자_응답의_email은_allow_list로만_허용된다() -> None:
    # Arrange: 소유자 전용 표면 (email 포함)
    payload = UserPrivateOut(
        id=1,
        email="user1@example.com",
        display_name="fixture-user",
        created_at=SYNTHETIC_CREATED_AT,
    ).model_dump()

    # Act / Assert: 인가 범위 없으면 위반, 소유자 allow-list면 통과
    assert find_exposed_fields("users", payload) == ["email"]
    assert find_exposed_fields("users", payload, OWNER_ALLOWED_FIELDS) == []


def test_secret_필드가_포함된_payload는_게이트가_차단한다() -> None:
    # Arrange: raw ORM 직렬화 실수를 재현한 위반 payload
    leaked = {
        "id": 1,
        "email": "user1@example.com",
        "password_hash": "test-password-hash",
        "display_name": "fixture-user",
    }

    # Act / Assert: secret은 allow-list로도 허용 불가 — 항상 위반
    assert "password_hash" in find_exposed_fields("users", leaked)
    assert "password_hash" in find_exposed_fields(
        "users", leaked, OWNER_ALLOWED_FIELDS
    )


def test_분류표에_없는_신규_필드는_미분류로_검출된다() -> None:
    # Arrange: 분류 등록 없이 추가된 필드
    payload = {"id": 1, "loyalty_tier": "gold"}

    # Act / Assert
    assert find_unclassified_fields("users", payload) == ["loyalty_tier"]
