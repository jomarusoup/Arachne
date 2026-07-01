---
Title: "Idea 기록 규약"
creation: 2026-07-01
modification: 2026-07-01
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "idea"
aliases:
 - "idea-log"
---
MOC:: [[Arachne]]
FROM:: [[arachne-docs]]

# Idea 기록

`docs/idea/`는 **아직 실행이 확정되지 않은 개선 후보, 감사 결과, 로드맵 초안**을 두는 곳이다.
실행하기로 결정하면 `docs/task/`에 작업 문서를 만들고, 장기 설계 결정으로 확정되면
`docs/decisions/`에 ADR을 남긴다.

## 언제 idea에 쓰나

| 상황 | 기록 위치 |
| --- | --- |
| 개선 방향은 보이지만 아직 범위·담당·검증이 정해지지 않았다 | `idea/` |
| 조사나 감사 결과를 보존하고 후속 작업을 나중에 고르고 싶다 | `idea/` |
| 구체적인 수정 작업으로 착수한다 | `task/` |
| 구조적 선택을 확정해서 나중에 되돌아볼 필요가 있다 | `decisions/` |

## 작성 기준

- 파일명은 `YYYY-MM-DD-<짧은-kebab-case-아이디어명>.md`로 쓴다.
- 배경, 관찰, 선택지, 권장 처리 순서를 분리한다.
- 실행이 확정되면 같은 파일을 무리하게 작업 추적용으로 쓰지 말고 task를 만든다.
- 오래된 idea는 삭제보다 “현재 판단” 섹션을 추가해 유효성을 갱신한다.

## 현재 묶음

| 묶음 | 포함 내용 |
| --- | --- |
| `python-web-*` | Python/Web profile 평가, gap 분석, 개선 로드맵 |
| `documentation-*` | 문서 최신성 감사와 구조 정리 후보 |
| `web-design-*` | UI/UX 문서 배치와 예시 관리 방향 |
