# 멀티-CLI 가이드 — Claude Code · Gemini CLI · Codex CLI

Arachne는 **하나의 공통 규약(`AGENTS.md`)을 세 개의 AI 코딩 CLI가 동시에 따르도록** 연결한다.
한 파일만 고치면 세 도구가 같은 규칙으로 움직인다. 이 문서는 각 CLI에서 어떻게 쓰고, 셋이
서로 어떻게 영향을 주고받는지 설명한다.

> 한 줄 요약: **`AGENTS.md` = 단일 진실 공급원(SSOT).** 세 CLI는 이 한 파일을 각자의 방식으로 본다.

---

## 1. 큰 그림

```
                ┌──────────────────────────────┐
                │   AGENTS.md  (SSOT, 공통 규약) │   ← 여기만 고친다
                └───────────────┬──────────────┘
        ┌───────────────────────┼────────────────────────┐
        │ 심볼릭(즉시)            │ 마커 병합(재설치)         │ rules/ 자동 로드
        ▼                       ▼                         ▼
  ~/.gemini/GEMINI.md     ~/.codex/AGENTS.md       ~/.claude/rules/  (+ CLAUDE.md 보충)
        │                       │                         │
     Gemini CLI              Codex CLI                Claude Code
```

- **공통 규약**(작업 원칙·코딩 스타일·패턴·보안·테스트·git·이슈·언어 포인터)은 `AGENTS.md`에만 둔다.
- **도구 전용 기능**(Claude의 서브에이전트·훅·슬래시 커맨드·모델 라우팅·`gask`)은 `CLAUDE.md`에만 둔다.
  → 공유 규약과 도구 전용이 파일 단위로 분리돼 **드리프트가 구조적으로 차단**된다.

---

## 2. 각 CLI는 SSOT를 어떻게 보는가 (비대칭이 핵심)

| CLI | 연결 파일 | 연결 방식 | 반영 시점 | 무엇을 보나 |
| --- | --- | --- | --- | --- |
| **Claude Code** | `~/.claude/rules/` (+ `CLAUDE.md`) | 디렉터리 심볼릭 → **네이티브 자동 로드** | 다음 세션 | `rules/`의 **풀 디테일** (AGENTS.md보다 상세) |
| **Gemini CLI** | `~/.gemini/GEMINI.md` | **AGENTS.md 심볼릭** | **즉시** (재설치 0회) | AGENTS.md 다이제스트 |
| **Codex CLI** | `~/.codex/AGENTS.md` | **AGENTS.md 마커 병합** | `arachne -i --target codex` 재실행 후 | AGENTS.md 다이제스트 |

**왜 비대칭인가** — import 지원 여부가 도구마다 다르기 때문이다.
- Claude는 `~/.claude/rules/`를 네이티브로 자동 로드한다. 그래서 Claude는 AGENTS.md를 굳이 import하지
  않는다 — `rules/`가 더 상세한 풀 버전을 이미 준다.
- Gemini는 글로벌 컨텍스트 파일(`~/.gemini/GEMINI.md`) 하나를 읽는다. 심볼릭이라 **AGENTS.md 수정이 즉시** 반영된다.
- Codex는 import가 없어 심볼릭 대신 **본문을 병합**한다. 사용자가 직접 추가한 내용(마커 밖)을 보존하되,
  마커 안 본문은 재설치할 때 AGENTS.md로 갱신된다.

> 이 비대칭은 실측으로 검증됨: Gemini·Codex 모두 비대화 모드에서 AGENTS.md에 심은 고유 토큰을
> 출력함(런타임 로딩 확인). 4장 참고.

---

## 3. CLI별 동작 — 무엇이 작동하나

### 3.0 능력 매트릭스

Arachne 구성요소가 각 CLI에서 실제로 작동하는지. **공통 규약만 셋이 공유**하고, 나머지는
대부분 Claude 전용이다(import·이벤트 훅·서브에이전트 개념이 Claude Code에만 있으므로).

| Arachne 구성요소 | Claude Code | Gemini CLI | Codex CLI |
| --- | :---: | :---: | :---: |
| 공통 규약 (`AGENTS.md` / `rules/common`) | ✅ `rules/` 풀버전 자동 로드 | ✅ `GEMINI.md` | ✅ `~/.codex/AGENTS.md` |
| 언어 규칙 (`rules/<언어>/*`) | ✅ `paths`로 확장자 매칭 시 자동 로드 | ⚠️ AGENTS §9 **경로 포인터만** (본문 자동 로드 X) | ⚠️ 동일 |
| 서브에이전트 (`agents/`) | ✅ | ❌ | ❌ |
| 슬래시 커맨드 (`commands/`) | ✅ `/이름` | ❌ | ❌ |
| 이벤트 훅 (`hooks/`) | ✅ Session·PreCompact·Prompt | ❌ | ❌ |
| 스킬 (`skills/`) | ✅ 자동 참조 | ❌ | ❌ |
| 상태표시줄 (`statusline`) | ✅ | ❌ | ❌ |
| `gask` 위임 | ✅ **호출 주체** | — (위임 **대상**) | ❌ |
| MCP 서버 | ✅ `settings.json` | 별도 `~/.gemini` 설정(미관리) | 별도 `~/.codex/config.toml`(미관리) |

> 요점: **Gemini·Codex는 "공통 규약을 읽는 것"까지**가 Arachne가 주는 전부다. 에이전트·훅·커맨드 같은
> 오케스트레이션은 Claude Code 고유 기능이라 이식되지 않는다. (Gemini·Codex가 가진 **자체** 에이전트·MCP
> 기능은 별개이며 Arachne가 아직 관리하지 않는다 — [설계문서](issue/2026-06-05-multi-cli-ssot.md) Phase 3.)

### 3.1 Claude Code — 풀 스택으로 동작

별도 설정 불필요 — `arachne -i` 후 자동이다.

**런타임 동작**: 세션 시작 시 `~/.claude/rules/`를 네이티브로 읽고(공통=항상), `CLAUDE.md`의 Claude
전용 보충을 적용한다. 파일 편집 시 확장자에 맞는 언어 규칙이 추가 로드되고, 이벤트마다 훅이 실행되며,
상태표시줄이 렌더된다. 에이전트·슬래시 커맨드를 호출할 수 있다.

- **공통 규칙**(`rules/common/*`): 매 세션 자동 로드.
- **언어 규칙**(`rules/<언어>/*`): 해당 확장자 파일을 열면 `paths` frontmatter로 자동 활성화
  (예: `*.rs` 편집 → `rules/rust/*` 로드).
- **서브에이전트·슬래시 커맨드·훅·`gask`·모델 라우팅**: `CLAUDE.md` + `agents/`·`commands/`·`hooks/`에 정의.
  자세한 사용은 [USAGE.md](USAGE.md).

### 3.2 Gemini CLI — 공통 규약 + gask 위임 대상

**런타임 동작**: Gemini는 매 호출마다 글로벌 컨텍스트 `~/.gemini/GEMINI.md`(→ AGENTS.md 심볼릭)를
로드한다. 즉 **공통 규약만** 적용되고, 에이전트·훅·커맨드는 없다. 비대화 호출 시 신뢰 폴더 검사가 있어
헤드리스 환경에선 `--skip-trust`가 필요하다(`gask`가 자동 처리). 실측: `gemini --skip-trust -p`가
AGENTS.md에 심은 고유 토큰을 출력 → 런타임 로딩 확인됨.

- Arachne는 Claude가 Gemini에 작업을 위임하는 `gask` 래퍼를 제공한다(비용 최적화 — [USAGE.md §6](USAGE.md)).

```bash
gask "이 설계 검토해줘: $(cat module.c)"     # 자문 → 답변 stdout
gask "이 로그 에러 원인만 요약: $(cat app.log)"
```

> `gask`는 헤드리스 호출이라 `--skip-trust`로 동작한다. 임의 디렉터리에서 불려도 신뢰 설정 없이 응답한다.

### 3.3 Codex CLI — 공통 규약(병합본)

**런타임 동작**: Codex는 새 세션마다 글로벌 지침 `~/.codex/AGENTS.md`를 로드한다. 이 파일엔 SSOT 본문이
마커(`<!-- === ARACHNE … === -->`)로 병합돼 있고, 마커 밖 사용자 내용은 보존된다. **공통 규약만** 적용되고
에이전트·훅·커맨드는 없다(Codex 자체 기능은 별개). 실측: 프로젝트 AGENTS.md가 없는 중립 디렉터리에서
`codex exec`가 전역 지침의 고유 토큰을 출력 → 런타임 로딩 확인됨.

- 비대화 실행:

```bash
codex exec "이 함수 리뷰해줘"
codex exec -C <작업디렉터리> --skip-git-repo-check "..."
```

- **주의**: AGENTS.md를 수정했으면 Codex는 자동 반영이 아니다. `arachne -i --target codex`
  (또는 전체 `arachne -u`)로 재병합해야 한다. 까먹어도 `arachne --check`가 stale을 잡는다.

---

## 4. 셋은 서로 어떻게 영향을 주는가

### 4.1 전파 — "한 파일 수정 = 세 CLI"

`AGENTS.md`를 고치면:

| CLI | 전파 | 추가 작업 |
| --- | --- | --- |
| Gemini | **즉시** (심볼릭) | 없음 |
| Claude | 다음 세션 | 없음 (단, 풀 규칙은 `rules/`에서 — AGENTS.md와 함께 갱신 권장) |
| Codex | 재병합 후 | `arachne -i --target codex` 또는 `arachne -u` |

> `AGENTS.md`(다이제스트) ↔ `rules/`(풀 버전)는 별도 동기화 축이다. 규약을 바꾸면 양쪽을 함께 손봐야 한다.
> CI의 인덱스 검사가 파일 누락은 잡지만, **내용 동기화는 사람 책임**이다.

### 4.2 협업 — Claude ↔ Gemini 비용 라우팅

토큰 무겁고 정밀도가 덜 중요한 작업(설계·요약·조사·1차 리뷰·장문 생성)은 Claude가 `gask`로 Gemini에
위임한다. 구현·디버깅·보안 리뷰·설정 관리는 Claude가 한다. 정책의 단일 출처는
[`rules/common/workflow.md`](../rules/common/workflow.md), 사람용 설명은 [USAGE.md §6](USAGE.md).

또 다른 채널은 **git-bus**다 — 다른 터미널에서 Gemini가 직접 커밋한 경우, `hooks/gemini-check.sh`가
다음 프롬프트 때 새 커밋을 알린다(비동기 메시지 버스).

### 4.3 독립성 — 서로를 깨지 않는다

- Codex 병합은 **마커 밖 사용자 내용을 보존**한다(직접 추가한 메모가 재설치로 사라지지 않음).
- Gemini 심볼릭이 끊겨도(레포 이동 등) Claude·Codex는 영향 없다.
- 한 CLI 미설치 시 `arachne -i`는 그 CLI만 graceful skip한다(나머지 정상 설치).

---

## 5. 상태 점검 — `arachne --check`

세 CLI 연결을 한 번에 점검한다. 심볼릭 댕글링과 Codex stale을 잡는다.

```bash
arachne --check
```

```
[Arachne] 연결 상태 점검
  [OK]   Claude : ~/.claude/CLAUDE.md -> 레포
  [OK]   Gemini : ~/.gemini/GEMINI.md -> AGENTS.md
  [OK]   Codex  : ~/.codex/AGENTS.md (AGENTS.md 최신)
[Arachne] 모든 연결 정상
```

- `[OK]` 정상 / `[SKIP]` 미감지(미설치) / `[FAIL]` 끊김·stale → 안내대로 재설치.
- 하나라도 FAIL이면 종료코드 1 (스크립트·CI에서 활용 가능).

---

## 6. 흔한 작업 흐름

```bash
# 규약을 바꾸고 싶다 → AGENTS.md 수정 후
vim ~/Arachne/AGENTS.md
arachne -i --target codex      # Gemini는 자동, Codex만 재병합
arachne --check                # 세 CLI 정상 확인

# 전부 최신으로 (다른 머신에서 pull 받은 뒤 등)
arachne -u                     # git pull + 감지된 CLI 전체 재설치

# 새 CLI를 방금 로그인했다 (예: Codex)
arachne -i --target codex      # 또는 arachne -i (all)
```

---

## 7. 관련 문서

- [README.md](../README.md) — 설치·CLI 커맨드 개요
- [USAGE.md](USAGE.md) — 커맨드·에이전트·스킬·훅·규칙·협업 상세
- [AGENTS.md](../AGENTS.md) — 공통 규약 SSOT 본문
- [멀티-CLI SSOT 설계](issue/2026-06-05-multi-cli-ssot.md) — 설계 결정·Phase 기록
