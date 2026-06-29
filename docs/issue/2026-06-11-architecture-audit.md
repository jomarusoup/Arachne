---
Title: "[audit] 하네스 아키텍처 감사 — AI 멀티 플랫폼 하네스 관점"
creation: 2026-06-11
modification: 2026-06-11
status: "in progress"
tags:
 - "arachne"
 - "audit"
 - "architecture"
aliases:
 - "architecture-audit-2026-06"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [audit] 하네스 아키텍처 감사

- **작성일**: 2026-06-11
- **유형**: audit (플랫폼 설계·DevEx·운영·보안 관점)
- **검수 기준**: df68f39 + 미커밋 데이터 자산 5종
- **범위**: 디렉터리 구조·설치기·hooks·commands·skills·agents·profiles·CI·verify·docs·MCP·AI 설정·Obsidian 연동

## 요약 (Executive Summary)

**전체 70/100** — 3년 유지 가능한 골격은 갖췄으나, 운영성(복구·버전 정책)과 정책 문서 중복이
주요 리스크.

| 축 | 점수 | 근거 |
| --- | --- | --- |
| 유지보수성 | 72 | bats 117건·4-플랫폼 CI·인덱스/규약 드리프트 검사 강함. 단 3-레인 정책이 6개 문서에 중복, 내용 동기화는 토큰 3그룹만 자동 검증 |
| 확장성 | 70 | profile·템플릿 계약이 명확(소유권 분리). 단 자산 추가마다 인덱스 5~7곳 수동 갱신, 개수 하드코딩 |
| 운영성 | 58 | 훅 quiet-fail 설계는 적절하나 로그 파일 부재, uninstall 없음, `.bak` 1세대뿐, 버전 정책(태그·CHANGELOG) 없음 |
| 문서 품질 | 78 | 정본 선언·한계 명시가 모범적. 단 skills frontmatter 등 문서-구현 불일치 다수 발견(감사로 수정) |
| 플랫폼 호환성 | 80 | Ubuntu·Rocky9·macOS·Windows 4-job CI는 동급 도구 대비 강점. statusline `date -d`는 GNU 전용(매OS 미동작, 문서화됨) |
| 보안 | 65 | 래퍼 인젝션 방어·테스트 존재. 단 dotfile 병합 손상 버그(수정), /tmp 고정 임시파일(수정), CI 최소권한 누락(수정), git-bus 커밋 메시지 무필터 주입 잔존 |

자동 수정 10건은 [CHANGELOG-AUDIT.md](../../CHANGELOG-AUDIT.md) (A-01~A-10).

## Findings (자동 수정 외 잔존 항목)

| ID | Severity | Category | 내용 | 권고 |
| --- | --- | --- | --- | --- |
| F-01 | HIGH | 운영성 | uninstall·복구 절차 부재 — 심볼릭·bin·dotfile 마커·settings를 제거/복원하는 명령이 없고 `.bak`은 1세대만 유지 | `arachne --uninstall` + RECOVERY 문서 (Phase 3) |
| F-02 | HIGH | 기술부채 | 3-레인 정책이 workflow.md(SSOT)+AGENTS+README+MULTI-CLI+ARCHITECTURE+USAGE 6곳에 표 단위로 복제 | 사람용 문서는 표를 줄이고 링크로 수렴, `check_convention_sync.sh`에 레인·폴백 토큰 그룹 추가 (Phase 2) |
| F-03 | MEDIUM | 플랫폼 | statusline 주간 리셋 계산이 GNU `date -d` 전용 — macOS 기본 설치에서 상태표시줄 고장 | epoch 산술로 이식 또는 macOS 분기 (Phase 2) |
| F-04 | MEDIUM | 운영성 | `git-bus-check.sh`가 **매 프롬프트** `git fetch` — 느린 네트워크·오프라인에서 입력 지연 | 마지막 fetch 후 N분 스로틀 (Phase 2) |
| F-05 | MEDIUM | 보안 | git-bus가 업스트림 커밋 제목을 무필터로 컨텍스트에 출력 — 멀티 CLI 버스 특성상 간접 프롬프트 인젝션 표면 | 제목 길이 제한 + "데이터로 취급" 안내문 동시 출력 (Phase 2) |
| F-06 | MEDIUM | 검증 | `minimal` profile CI가 `git diff --check`만 실행 — clean checkout에선 항상 통과(공허한 게이트) | README 존재·문서 링크 검사 등 최소 실질 검증 추가 검토 (Phase 2) |
| F-07 | MEDIUM | 운영성 | 버전 정책 부재 — install.sh 1.0.0 vs install.ps1 1.1.0 드리프트, git tag·CHANGELOG 없음 | 단일 VERSION 소스 + 태그 규칙 (Phase 3) |
| F-08 | LOW | 검증 | `arachne -c`의 Claude 검사가 CLAUDE.md 링크 1개만 확인(rules/hooks 등 미검사) | SYMLINK_TARGETS 전체 순회 (Phase 2) |
| F-09 | LOW | 운영성 | doc-drift 마커(`.docdrift-seen-*`)가 세션마다 누적, 정리 없음 | 훅 시작 시 7일 이전 마커 삭제 (Phase 2) |
| F-10 | LOW | DevEx | `register_bin` PATH 검사가 부분 문자열 매칭(grep) — 오탐 가능 | `case ":$PATH:"` 패턴으로 교체 (Phase 2) |

## Missing Design (문서화되지 않았지만 필요한 설계)

1. **Uninstall/Recovery Guide** — 근거: 설치기가 홈 디렉터리 6곳+(심볼릭·bin·dotfile 마커·
   settings·~/.codex·~/.copilot)을 변경하지만 역방향 절차가 어디에도 없다. `.bak`은 재설치마다
   덮어써 1세대만 남는다.
2. **Versioning/Release 정책** — 근거: 두 설치기의 버전 문자열이 이미 갈라졌고(1.0.0/1.1.0)
   태그·릴리스 노트가 없어 "어느 시점으로 롤백"이 정의 불가. `arachne -u`는 항상 최신 main.
3. **운영 로그 위치** — 근거: 훅은 전부 quiet-fail(-e 제외)인데 실패가 세션 출력 외 어디에도
   남지 않아 사후 장애 추적이 불가. `~/.claude/logs/` 같은 best-effort 로그 파일 정의 필요.
4. **데이터 분류·운영 기준(docs/DATA-HANDLING.md)** — 근거: data-handling 규칙이 이미 참조
   의도를 가진 예정 산출물 (data-handling-hardening task).

## Technical Debt 전망

- **3개월**: 자산 추가 시 인덱스 5~7곳 수동 갱신 누락 반복(이번 감사에서도 발생) → check_index가
  잡아주나 커밋 전 로컬 실행에 의존. 개수 표기 드리프트 재발.
- **6개월**: 3-레인 정책 사본 6곳 중 한 곳만 갱신되는 내용 드리프트 — 토큰 검사 3그룹 밖이라
  CI가 못 잡는다. profile이 4종 이상으로 늘면 `templates/project/profiles/*/commands`와
  arachne.yml의 분기 매핑이 함께 늘어 install.sh 단일 파일(약 1,000줄)이 책임 과다로 비대화.
- **1년**: 언어 규칙 8언어×5파일 + 스킬 31개의 유지 비용이 우선순위(Python·Web)와 역전 —
  2·3순위 언어 자산이 전체의 60%+를 차지하나 검증은 인덱스 수준뿐. 버전 정책 부재로 다중 머신
  간 "어느 하네스 버전인가"를 git 해시로만 식별.

## Patch Plan

| Phase | 내용 | 상태 |
| --- | --- | --- |
| **1** | CHANGELOG-AUDIT A-01~A-11 (병합 손상·인덱스·Playwright·테스트 밀폐·보안 소수정·문서 정합) | ✅ 완료 (2026-06-11) |
| **2** | A-12~A-19: fetch 스로틀(F-04), 레인 토큰 동기화 검사(F-02), VERSION 단일화(F-07), -c 전체 링크 검사(F-08), 마커 정리(F-09), PATH 검사(F-10), git-bus 출력 방어(F-05), minimal 의도 문서화(F-06 결정 종결) | ✅ 완료 (2026-06-11) |
| **3** | F-01(uninstall/recovery)·F-03(statusline macOS)·릴리스 태그 정책·훅 로그 | 트리거 대기 — [followup task](../task/2026-06-11-audit-followup.md) |
| **4** | 구조 단순화(승인 필요): ① 3-레인 사람용 문서의 표 사본 제거 ② install.sh에서 project-ci 서브커맨드 분리 ③ 2·3순위 언어 rules/skills의 pack화(설치 선택제) | 보류 — 같은 task에 트리거 명시 |

> 잔존 항목의 상세·트리거 조건·검증 명령은
> [docs/task/2026-06-11-audit-followup.md](../task/2026-06-11-audit-followup.md)가 정본이다.

## 원본 템플릿 대비 구조 평가

이 하네스는 원본 템플릿 모음의 구조를 그대로 답습하지 않고 이미 올바르게 분기했다:
SSOT(AGENTS.md) + CLI별 어댑터, 프로젝트 CI 소유권 분리(.arachne/commands), 위임 래퍼의 역할
프리앰블·인젝션 방어는 원본에 없는 고유 설계로 유지 가치가 높다. 반대로 원본에서 물려받은
"모든 언어 풀셋 동봉" 구조는 Python·Web 우선 목표와 비용이 역전되고 있어, 장기적으로는
profile이 전역 rules/skills 설치 범위까지 선택하는 pack 모델(Phase 4-③)이 더 단순하다.

## 검증

```bash
shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh
bats tests/*.bats
bash tests/validate_settings.sh
bash tests/check_index.sh
bash tests/check_convention_sync.sh
```
