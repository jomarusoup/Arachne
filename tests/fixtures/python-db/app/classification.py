################################################################################
# FILE NAME   : classification.py
# DESCRIPTION : 데이터 분류표와 노출 표면 검사 — docs/DATA-HANDLING.md 분류표 구현
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

from collections.abc import Mapping

# docs/DATA-HANDLING.md 4등급 분류 — 신규 필드는 반드시 여기에 등록한다
DATA_CLASSIFICATION: dict[str, dict[str, str]] = {
    "users": {
        "id": "internal",
        "email": "pii",
        "password_hash": "secret",
        "display_name": "public",
        "created_at": "internal",
    },
    "orders": {
        "id": "internal",
        "user_id": "internal",
        "idempotency_key": "internal",
        "amount": "internal",
        "currency": "public",
        "status": "internal",
        "created_at": "internal",
    },
}

# 응답·로그·metric·cache 기본 차단 등급
EXPOSE_BLOCKED: frozenset[str] = frozenset({"pii", "secret"})


#===============================================================================
# FUNCTION    : find_exposed_fields
# DESCRIPTION : 직렬화된 payload에서 차단 등급 필드 노출을 검출
# PARAMETERS  : str table                    - 분류표 테이블명
#               Mapping payload              - 직렬화된 필드 dict
#               frozenset allowed            - 인가 범위에서 허용된 필드 (소유자 등)
# RETURNED    : list[str] 차단 위반 필드명 (없으면 빈 리스트)
#===============================================================================
def find_exposed_fields(
    table: str,
    payload: Mapping[str, object],
    allowed: frozenset[str] = frozenset(),
) -> list[str]:
    table_grades = DATA_CLASSIFICATION.get(table, {})
    violations = [
        name
        for name in payload
        if table_grades.get(name) in EXPOSE_BLOCKED and name not in allowed
    ]
    return sorted(violations)


#===============================================================================
# FUNCTION    : find_unclassified_fields
# DESCRIPTION : 분류표에 등록되지 않은 필드를 검출 — 미분류 신규 필드 차단
# PARAMETERS  : str table       - 분류표 테이블명
#               Mapping payload - 직렬화된 필드 dict
# RETURNED    : list[str] 미분류 필드명 (없으면 빈 리스트)
#===============================================================================
def find_unclassified_fields(table: str, payload: Mapping[str, object]) -> list[str]:
    table_grades = DATA_CLASSIFICATION.get(table, {})
    return sorted(name for name in payload if name not in table_grades)
