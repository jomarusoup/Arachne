---
Title: "Idea 기록 규약"
creation: 2026-07-01
modification: 2026-10-06
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

`docs/idea/`는 **아직 실행이 정해지지 않은 후보와 입력 원문**을 두는 곳이다.
감사 기록과 문제 분석은 `docs/issue/`에, 기획(`[plan]`)과 실행하기로 정한 작업은 `docs/task/`에 둔다.
실행하기로 결정하면 `docs/task/`에 작업 문서를 만들고, 장기 설계 결정으로 확정되면
`docs/decisions/`에 ADR을 남긴다.
다음에 할 일을 고르거나 계획의 근거가 된 원문을 확인하려는 사람이 읽는다.

## 언제 idea에 쓰나

| 상황 | 기록 위치 |
| --- | --- |
| 개선 방향은 보이지만 아직 범위·담당·검증이 정해지지 않았다 | `idea/` |
| 조사·감사에서 나온 개선 후보를 보존하고 실행 여부를 나중에 정한다 | `idea/` |
| 감사 기록, 문제의 증상·재현·원인 분석을 남긴다 | `issue/` |
| 구체적인 수정 작업으로 착수한다 | `task/` |
| 구조적 선택을 확정해서 나중에 되돌아볼 필요가 있다 | `decisions/` |
| `[plan]` 문서의 근거가 되는 입력 원문을 보존한다 | `idea/` |

## 작성 기준

- 파일명은 `YYYY-MM-DD-<짧은-kebab-case-아이디어명>.md`로 쓴다.
- 배경, 관찰, 선택지, 권장 처리 순서를 분리한다.
- 실행이 확정되면 같은 파일을 무리하게 작업 추적용으로 쓰지 말고 task를 만든다.
- 오래된 idea는 삭제보다 “현재 판단” 섹션을 추가해 유효성을 갱신한다.

## 현재 묶음

| 묶음 | 포함 내용 |
| --- | --- |
| `python-web-*` | Python/Web profile 평가, gap 분석, 개선 로드맵 |
| `documentation-*` | 문서 최신성 점검에서 나온 구조 정리 후보 |
| `web-design-*` | UI/UX 문서 배치와 예시 관리 방향 |
| `programming-philosophy` | 시스템 프로그래밍 철학 원문(결정 레지스터, 원칙 본문, 위임 압축본). [철학 이식 계획](../task/2026-09-29-programming-philosophy-integration.md)과 ADR-0005의 입력이다 |
