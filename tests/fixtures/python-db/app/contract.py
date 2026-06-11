################################################################################
# FILE NAME   : contract.py
# DESCRIPTION : 응답 스키마 계약 추출·breaking change 검출 — snapshot 비교 게이트
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
from __future__ import annotations

from typing import Any

from pydantic import BaseModel


#===============================================================================
# FUNCTION    : annotation_name
# DESCRIPTION : 필드 annotation을 pydantic 버전과 무관한 안정적 이름으로 변환
# PARAMETERS  : Any annotation - 모델 필드 타입 annotation
# RETURNED    : str 타입 이름
#===============================================================================
def annotation_name(annotation: Any) -> str:
    return getattr(annotation, "__name__", str(annotation))


#===============================================================================
# FUNCTION    : export_contract
# DESCRIPTION : 모델의 필드명·타입·필수 여부를 계약 dict로 추출
# PARAMETERS  : type[BaseModel] model - 대상 Pydantic 모델
# RETURNED    : dict 필드명 → {type, required} (이름순 정렬)
#===============================================================================
def export_contract(model: type[BaseModel]) -> dict[str, dict[str, Any]]:
    contract = {
        name: {
            "type": annotation_name(field.annotation),
            "required": field.is_required(),
        }
        for name, field in model.model_fields.items()
    }
    return dict(sorted(contract.items()))


#===============================================================================
# FUNCTION    : detect_breaking_changes
# DESCRIPTION : 이전 계약(snapshot) 대비 호환성 깨는 변경을 검출
#               — 필드 제거, 타입 변경, 신규 필수 필드
# PARAMETERS  : dict old - snapshot 계약
#               dict new - 현재 계약
# RETURNED    : list[str] 위반 설명 (없으면 빈 리스트)
#===============================================================================
def detect_breaking_changes(
    old: dict[str, dict[str, Any]],
    new: dict[str, dict[str, Any]],
) -> list[str]:
    issues = []
    for name, spec in sorted(old.items()):
        if name not in new:
            issues.append(f"removed: {name}")
        elif new[name]["type"] != spec["type"]:
            issues.append(f"type-changed: {name}")
    for name, spec in sorted(new.items()):
        if name not in old and spec["required"]:
            issues.append(f"new-required: {name}")
    return issues
