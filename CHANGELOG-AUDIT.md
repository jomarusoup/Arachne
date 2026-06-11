# CHANGELOG-AUDIT

하네스 아키텍처 감사에서 승인 없이 수정 가능한 항목(버그·문서 불일치·검증 누락·Python/Web 개선)만
기록한다. 구조 변경 제안은 감사 보고서(docs/issue/2026-06-11-architecture-audit.md)에 있다.

---

## 2026-06-11 — Architecture Audit (1차)

### A-01 `merge_dotfile` 중복 제거가 사용자 dotfile 문법을 파괴 [CRITICAL]

- **문제**: `arachne -i/-u`의 dotfiles 병합이, 사용자 `.bash_profile`/`.zshrc`에 함수가 있으면
  (`{`·`}` 단독 줄 존재) ARACHNE 섹션의 동일 구조 줄을 "중복"으로 제외해 **문법이 깨진
  병합본을 생성**했다. 재현: 함수 하나 있는 프로필에 병합 → `bash -n` 실패.
- **원인**: 중복 감지가 줄 단위 완전일치(grep -qxF)를 **모든 비주석 줄**에 적용 — 블록 구조
  줄과 함수 본문이 의미 없이 매칭됨.
- **수정**: 중복 제거 대상을 한 줄로 의미가 완결되는 `export `/`alias ` 줄로 한정
  (`install.sh` `merge_dotfile`). 회귀 테스트 2건 추가(`tests/install.bats`).
- **영향도**: 사용자 함수가 있는 모든 환경의 로그인 셸 복구. 기존에 깨진 병합본은
  `arachne -i` 재실행으로 재생성 필요.
- **롤백**: `install.sh`의 해당 case 블록을 이전 무조건 dedup 로직으로 복원.

### A-02 신규 데이터 자산 5종 인덱스 미등록 (CI 인덱스 검사 FAIL) [HIGH]

- **문제**: `agents/database-reviewer.md`, `rules/python/data-handling.md`,
  `skills/{json-contracts,database-migrations,postgres-patterns}.md`가 어느 인덱스에도 없어
  `tests/check_index.sh` FAIL — 커밋 시 CI가 깨지는 상태였다.
- **원인**: data-handling-hardening task(P0) 진행 중 자산만 생성되고 인덱스 연결 단계 미완.
- **수정**: skills/README.md(데이터·DB 섹션), docs/USAGE.md(스킬 분류·에이전트 표),
  CLAUDE.md(트리·에이전트), README.md·docs/ARCHITECTURE.md(개수·에이전트 목록),
  rules/README.md(python 트리), rules/common/agents.md(에이전트 표·활성화 기준)에 등록.
  `rules/python/data-handling.md`의 존재하지 않는 `docs/DATA-HANDLING.md` 링크는 예정
  산출물 표기로 교체.
- **영향도**: `bash tests/check_index.sh` PASS 복구. database-reviewer가 문서상 발견 가능.
- **롤백**: 인덱스 항목 제거(자산 파일 자체는 본 감사 범위 밖).

### A-03 web/python-web profile CI에서 Playwright 브라우저 미설치 [HIGH / Python·Web]

- **문제**: profile commands가 `pnpm exec playwright test`를 실행하지만 GitHub runner에는
  브라우저가 없어 fresh 프로젝트의 CI가 반드시 실패한다.
- **원인**: 템플릿이 로컬(브라우저 설치됨) 기준으로만 작성됨.
- **수정**: `templates/project/profiles/{web,python-web}/commands`에
  `if [ -n "${CI:-}" ]; then pnpm exec playwright install --with-deps; fi` 추가 —
  CI에서만 설치, 로컬은 1회 수동 설치 전제. PROJECT-CI.md 실패 해석 표·PYTHON-WEB-PROFILE.md 갱신.
- **영향도**: 신규 init-ci 프로젝트만 해당(기존 프로젝트의 commands는 프로젝트 소유라 불변).
- **롤백**: 두 템플릿에서 해당 줄 제거.

### A-04 statusline 고정 `/tmp` 임시 파일 [MEDIUM / 보안]

- **문제**: `statusline-command.sh`가 예측 가능한 `/tmp/.claude_track_tmp`에 기록 —
  공유 시스템에서 심볼릭 링크 공격에 취약하고 자체 bash 보안 규칙(mktemp 의무) 위반.
- **수정**: `mktemp` 사용으로 교체.
- **영향도**: 동작 동일, 경로만 무작위화.
- **롤백**: 고정 경로 복원(권장 안 함).

### A-05 git-bus 출력이 모든 업스트림 커밋을 "[Gemini 작업 감지]"로 표시 [MEDIUM / 문서-구현 불일치]

- **문제**: 문서 3곳(README·ARCHITECTURE·USAGE)이 "작성 CLI 판별 없음"을 명시하는데 훅 출력
  라벨이 Gemini로 단정.
- **수정**: `hooks/git-bus-check.sh` 라벨을 `[git-bus] 업스트림 새 커밋 N건 (작성 CLI 판별 없음)`으로
  교체, 주석 중립화. `hooks/session-end.sh`의 `UpdateGeminiRef` → `UpdateUpstreamRef` 일치 개명.
- **영향도**: 출력 문자열만 변경(테스트가 해당 문자열에 의존하지 않음을 확인).
- **롤백**: 문자열·함수명 복원.

### A-06 저장소 CI workflow 최소 권한 누락 [MEDIUM / 보안]

- **문제**: `.github/workflows/ci.yml`에 `permissions` 블록이 없어 기본 토큰 권한으로 실행 —
  프로젝트 템플릿 `arachne.yml`은 `contents: read`를 쓰는데 자체 CI만 미적용(불일치).
- **수정**: 최상위 `permissions: contents: read` 추가.
- **영향도**: 검증 전용 CI라 기능 변화 없음, 토큰 권한만 축소.
- **롤백**: 블록 제거.

### A-07 skills frontmatter 문서-구현 불일치 [MEDIUM]

- **문제**: CLAUDE.md·USAGE.md가 "skills는 frontmatter 없음"이라 기술하지만 실제 30개 스킬
  전부 `name`·`description` frontmatter를 가짐.
- **수정**: 두 문서의 형식 설명을 실제 구현(frontmatter + 본문)으로 정정.
- **롤백**: 문구 복원.

### A-08 문서 하드코딩 개수 드리프트 (스킬 28→31, 에이전트 7→8) [LOW]

- **문제**: README·CLAUDE.md·ARCHITECTURE·skills/README의 개수 표기가 신규 자산 반영 전 값.
- **수정**: 31개·8개로 갱신. (개수 표기 자체의 제거 또는 CI 검증화는 보고서 제안 P2-3.)

### A-09 `pre-compact.sh` 데드 코드 제거 [LOW]

- **문제**: `CollectProjectState()`가 정의만 되고 호출되지 않으며, 동일 로직이 인라인 중복.
- **수정**: 미사용 함수 제거(동작 불변).

### A-11 atask 테스트의 PATH 격리 불완전 — 실제 Claude CLI 호출 [HIGH / 검증]

- **문제**: `tests/atask.bats`의 "미설치 CLI 는 건너뛴다" 테스트가 PATH를 `/usr/bin:/bin`
  디렉터리 허용으로 격리했는데, 호스트에 `/usr/bin/claude`가 있으면 **실제 Claude CLI가
  테스트 중 호출**돼 간헐 실패(비결정 응답)와 토큰 소모가 발생했다(감사 중 재현).
- **원인**: "claude는 ~/.local/bin에만 있다"는 호스트 배치 가정.
- **수정**: 필요한 도구만 심볼릭 링크한 밀폐 PATH(safebin)를 구성해 어떤 배치에서도
  claude 미감지를 보장. 5회 반복 실행으로 안정성 확인.
- **영향도**: 테스트 결정성 복구, 테스트 실행 중 외부 API 호출 차단.
- **롤백**: 이전 디렉터리 허용 방식 복원(권장 안 함).

### A-10 `arachne-task.sh` 주석 오기 [LOW]

- **문제**: 모델 환경변수 주석이 구형 명칭(`GASK_MODEL`/`CASK_MODEL`)을 안내 — 실제 권장은
  `GTASK_MODEL`/`CTASK_MODEL`.
- **수정**: 주석 정정(코드 동작 불변 — 구형 변수는 래퍼에서 여전히 폴백 지원).
