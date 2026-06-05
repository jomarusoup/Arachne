# [refactor] Arachne 자기일관성·유지보수성 개선

- **작성일**: 2026-06-05
- **유형**: refactor (동작 변화 없는 구조·일관성 개선)
- **근거**: 전체 프로젝트 객관 진단(실측 기반)

> 핵심 문제: 하네스가 **스스로 강제하는 규칙을 스스로 지키지 않고**, 인덱스가
> 4중 수동 동기화 구조라 이미 드리프트가 발생 중. 콘텐츠 품질은 양호하나
> 자기일관성·검증 자동화가 약함.

---

## 🔴 CRITICAL — 자기규칙 위반

### 1. 테스트를 강제하면서 자기 테스트가 검증되지 않음
- `rules/common/testing.md`는 80% 커버리지·TDD·bats를 강제.
- 실측: `tests/install.bats`·`tests/hooks.bats`는 **존재하나 `bats` 미설치**로 로컬 미실행,
  `.github/workflows` 부재로 **CI가 없어 자동 검증 0회**.
- → 작성됐으나 한 번도 실행 검증되지 않은 사실상 데드 테스트.

**해결**: CI 워크플로 1개 추가(`shellcheck` + `bats` + 인덱스 일치 검사).

### 2. `set -euo pipefail` 강제하면서 미준수
- `rules/bash/patterns.md`: "스크립트 상단 필수". 실측:
  | 파일 | set 옵션 |
  |---|---|
  | `install.sh` | `set -e`만 (−u −o pipefail 누락) |
  | `hooks/*.sh` 4개 | **없음** |
  | `statusline-command.sh` | 없음 |
  | `tmux.sh`·`gask.sh` | ✅ 준수 |
- 훅에 `set -u` 부재 → 미정의 변수가 빈 문자열로 처리되어 git 비교 오탐 가능.

**해결**: `install.sh`·`hooks/*.sh`·`statusline-command.sh`에 `set -euo pipefail` 적용
(훅은 의도적 continue가 필요하면 `set -uo pipefail`).

---

## 🟠 HIGH — 구조적 유지보수 결함

### 3. 인덱스 4중 수동 동기화 → 드리프트 발생
- 스킬/에이전트 추가 시 `CLAUDE.md` 트리 + `rules/README.md` + `skills/README.md` + `docs/USAGE.md`
  4곳을 손으로 갱신해야 함. 현재 드리프트:
  - `CLAUDE.md` "tests/ (예정)" — 실제 테스트 존재(낡음)
  - `docs/USAGE.md §3 분류표` — 신규 6개 스킬(python/web/meta) 누락
  - `docs/USAGE.md §1·§2` — `/python-review`·`python-reviewer` 누락

**해결**: 파일시스템 → 인덱스 생성 스크립트, 또는 "인덱스 ↔ 실제 파일 일치" 검증 bats 테스트
1개 추가(CI가 드리프트를 잡게).

### 4. 매 세션 19개 rules @import — 토큰 절약 철학과 충돌
- `CLAUDE.md`가 공통 12 + 언어별 coding-style 7개를 **항상 로드**.
- 언어 규칙은 이미 확장자 paths 자동 활성화가 있어 **이중 로드**(`.rs` 편집 시 @import+paths).
- "토큰 절약"을 표방하면서 무관한 언어 스타일 7종을 매 세션 선결제.

**해결**: 언어 coding-style 7개 `@import` 제거 → paths 자동 활성화에만 위임.

---

## 🟡 MEDIUM

### 5. git 이력 위생
- `5ffaaef`·`5680bf4`가 동일 메시지("chore: install.sh 개선 및 dotfiles 병합 메커니즘 추가") 중복 커밋.
- 향후 커밋 메시지 규율 재확인(리베이스 사고 방지).

### 6. 문서 중복(gask)
- `gask`가 단기간에 `workflow.md`·`README.md`·`USAGE.md`·`install.sh`에 동시 반영되며 설명 분산.
- 단일 출처(SSOT) 지정 후 나머지는 링크 참조 권장.

### 7. 범위 과확장 리스크
- "웹·MVP ~ 저수준 시스템" + 7개 언어 + 26 스킬. 1인 하네스치고 표면적이 넓어 드리프트가
  구조적으로 발생(3번이 증거). 인덱스 자동화 없이는 관리 비용이 복리 증가.

---

## 권장 처리 순서
1. **CI 1개 추가** (shellcheck + bats + 인덱스 일치) — 1·2·3을 동시 해소하는 최대 레버리지
2. `set -euo pipefail` 일괄 적용 (자기규칙 준수)
3. 언어 coding-style 7개 @import 제거 (토큰세 절감)
4. 인덱스 드리프트 수정 또는 생성 자동화

## 정상 확인(개선 불필요)
- 비밀값 하드코딩 없음, `settings` 권한 최소(`Bash(gask:*)`), `.gitignore` 적정
- shellcheck 전체 클린, LICENSE 존재, 문서 역할 분리(README/CLAUDE/USAGE) 명확
