# [feat] 멀티-CLI 단일 SSOT 연결 (Claude Code · Gemini CLI · Codex CLI)

- **작성일**: 2026-06-05
- **유형**: feat (신규 구조 — 하네스 규약을 3개 CLI가 공유)
- **상태**: ✅ Phase 0~3 구현 완료 (`c123a7e`·`f23350e` + `--check`). 3 CLI SSOT 라이브. settings/config 병합만 수요 시 잔여
- **선행 의존**: 이슈 #25 (해소됨 — paths 자동활성화 네이티브 지원 확정)

> 목표: **`AGENTS.md` 한 파일을 단일 진실 공급원(SSOT)으로 두고**, Claude Code·Gemini CLI·Codex CLI가
> 모두 그것을 가리키게 한다. "한 파일 수정 = 세 CLI 동시 반영", **빌드/CI 가드 불필요**.

---

## 1. 핵심 결정 — CLI별 비대칭

import 지원 여부가 다르므로 연결 방식이 갈린다. 이 비대칭이 설계의 본질이다.

| CLI | 컨텍스트 파일 | 연결 방식 | SSOT 반영 시점 |
| --- | --- | --- | --- |
| Claude Code | `~/.claude/CLAUDE.md` | `@AGENTS.md` import | 다음 세션 자동 |
| **Gemini CLI** | `~/.gemini/GEMINI.md` | **AGENTS.md 직접 심볼릭** | **즉시 (재설치 불필요)** |
| Codex CLI | `~/.codex/AGENTS.md` | 마커 병합 (import 불가) | `arachne -i` 재실행 필요 |

- AGENTS.md(SSOT)는 **CLI 무관 공통 규약만** 담는다(작업원칙·코딩스타일·패턴·보안·테스트·git·이슈·언어포인터).
- Claude 전용(서브에이전트·훅·슬래시커맨드·모델라우팅·gask)은 `CLAUDE.md` 보충에 남긴다 → 드리프트 구조적 차단.

## 2. install.sh `--target` 설계

```
arachne -i --target claude|gemini|codex|all     (기본 all)
```

- `all` = **감지된 CLI에만** 설치 (`DetectCli`로 `~/.gemini`·`~/.codex` 또는 바이너리 존재 선검사 → 미설치 시 graceful skip, 에러 아님).
- 진입점: `case`에서 install/update 진입 후 `ParseTarget`로 2차 파싱(화이트리스트 검증).

| 함수 | 동작 |
| --- | --- |
| `install_claude` | 현행 `install()` 본체 (SYMLINK_TARGETS 링크 + `sed __HOME__` settings.json) |
| `install_gemini` | `backup_and_link AGENTS.md → ~/.gemini/GEMINI.md` (순수 심볼릭) |
| `install_codex` | `merge_dotfile AGENTS.md → ~/.codex/AGENTS.md` (마커 병합, 사용자 보충 보존) |
| `install_shared` | dotfiles 병합 + `register_bin` (타깃 무관, 항상 1회) |

- **`merge_dotfile` 재사용**: Codex 병합은 기존 마커 병합 로직을 그대로 씀. 단 마커를 Markdown 친화적
  `<!-- === ARACHNE BEGIN === -->`로 쓰도록 **마커 스타일 인자 추가**(Phase 2).
- 공통 자산: `rules/`·`skills/`는 Claude만 디렉터리 심볼릭(전체 로드). Gemini/Codex는 AGENTS.md 9장의
  **경로 참조 포인터**만 봄(import 부재로 디렉터리 자동로드 불가).
- Gemini `settings.json`·Codex `config.toml`(MCP·모델)은 **공통 규약과 직교** → Phase 3로 미룸.

## 3. CLAUDE.md 재배선 (19 import → 7)

| 현재 import | AGENTS 커버 | 조치 |
| --- | --- | --- |
| coding-style·patterns·issue-workflow·security·testing·git-workflow | O | **제거** (AGENTS 흡수) |
| workflow·development-workflow | 부분 | **축소 유지** (gask·에이전트 파이프라인만 남김) |
| agents·hooks·performance·ui-layout | X | **유지** (Claude 전용) |
| 언어 coding-style 7개 | △ | **제거 보류** — Phase 0 검증 후 결정 (아래 4장) |
| `@AGENTS.md` | — | **신규 추가** (import 블록 최상단) |

## 4. ✅ Phase 0 — 검증 완료 (paths 자동활성화 = 네이티브 지원)

**공식 문서(`code.claude.com/docs/en/memory`)로 확정**: `paths:` frontmatter 조건부 로드와
`~/.claude/rules/` 자동 로드는 **Claude Code 네이티브 기능**. 심볼릭 링크도 공식 지원.
(초기 가설 "Cursor 전용 기능, Claude Code 미지원"은 **반증됨**.)

함의:
1. Arachne는 `rules`를 `~/.claude/rules`로 심볼릭 → **공통 규칙은 항상, 언어 규칙은 `paths` 매칭 시
   이미 자동 로드 중.** 각 언어 `security/patterns/hooks/testing`도 `paths` frontmatter가 있으면
   매칭 파일 열 때 로드됨(미로드 아님).
2. 따라서 **CLAUDE.md의 `@rules/...` 19개 import는 전부 중복** — 제거해도 콘텐츠 유실 없음
   (rules/ 자동 로더가 대체). #25 항목4가 "이중 로드"로 확정.
3. **Claude는 AGENTS.md조차 불필요** — rules/가 풀 디테일을 자동 로드하므로. AGENTS.md는
   rules/ 자동 로더가 없는 **Gemini/Codex 전용 휴대용 다이제스트**로 역할이 명확해짐.

→ 남은 실증 1건: `/memory` 실행해 심볼릭된 rules가 실제 로드 목록에 뜨는지 최종 확인(사용자만 가능).

> **공식 문서가 설계를 직접 축복**: "create a `CLAUDE.md` that imports it (`@AGENTS.md`).
> A symlink also works (`ln -s AGENTS.md CLAUDE.md`)." — 멀티-CLI SSOT 방향과 정확히 일치.

### 정밀화된 아키텍처 (Phase 0 결과 반영)
- **Claude**: `~/.claude/rules/` 네이티브 자동 로드(공통 항상 + 언어 paths). CLAUDE.md엔
  `@rules` import 제거, Claude 전용(agents·hooks·performance·ui-layout)만. `@AGENTS.md`도 선택사항
  (rules/와 중복이므로 굳이 import 안 해도 됨).
- **Gemini**: `~/.gemini/GEMINI.md` ← AGENTS.md 심볼릭 (유일 규칙 소스).
- **Codex**: `~/.codex/AGENTS.md` ← AGENTS.md 마커 병합 (유일 규칙 소스).
- 새 드리프트 축: `AGENTS.md`(다이제스트) ↔ `rules/`(풀) 간 내용 동기화. #25와 연계해 관리.

## 5. 단계적 구현

| Phase | 작업 | 독립 검증 |
| --- | --- | --- |
| **0** | ✅ **완료** — paths 자동로드 = 네이티브 지원 확인(공식 문서). 남은 건 `/memory` 실증 1건 | 지원 확정. `@rules` import 제거 안전 |
| **1** | ✅ **완료**(`c123a7e`) — CLAUDE.md `@rules/...` 19개 제거 + `install_gemini`(AGENTS.md→`~/.gemini/GEMINI.md` 심볼릭) | `readlink -e ~/.gemini/GEMINI.md` = AGENTS.md 확인 |
| **2** | ✅ **완료**(`f23350e`) — `merge_dotfile` 마커 접미사 인자화 + `install_codex` + 디스패처 `all`에 codex(감지 시) | bats 4종(마커·멱등성·보충 보존·SSOT 반영) 그린, 실환경 `~/.codex/AGENTS.md` 생성 |
| **3** | ✅ **`arachne --check` 완료** — 3 CLI 연결 점검(심볼릭 댕글링·Codex stale 탐지, OK/SKIP/FAIL). settings/config 병합은 범위 직교라 미착수(수요 시) | bats 3종 그린, 실환경 3 CLI OK |

## 6. 검증 — SSOT 전파 테스트

```bash
echo "<!-- SSOT-PROBE-12345 -->" >> ~/Arachne/AGENTS.md
grep SSOT-PROBE ~/.gemini/GEMINI.md          # 심볼릭 → 즉시 보임
arachne -i --target codex; grep SSOT-PROBE ~/.codex/AGENTS.md   # 병합 → 재설치 후
# Claude는 다음 세션에서 @import 반영
# 정리: probe 제거 + (codex) 재설치
```

## 7. 리스크

| 리스크 | 완화 |
| --- | --- |
| Gemini 심볼릭 댕글링(REPO 이동) | `arachne --check` `readlink -e` 탐지 + `update`로 복구 |
| **Codex 재설치 망각**(AGENTS 수정 후 stale) | `update_arachne`가 codex 마커 갱신 포함 + `--check`가 마커↔AGENTS diff로 stale 경고 + 문서 명시 |
| **paths 미작동 상태로 언어 import 제거**(콘텐츠 유실) | **Phase 0 검증 전까지 제거 금지** |
| AGENTS 요약 ↔ Claude 전용 모순 | 축소판이 AGENTS와 "상세화 관계"만, "상반" 금지 — 1회 정독 검증 |
| settings 분기 부재 | 의도된 범위(규약 SSOT와 직교) — Phase 3 |

## 권장
- generate+validate 방식 모방 금지(Arachne는 심볼릭 설치라 배포 제약 없음).
- **점진**: Phase 0 → 1(Claude+Gemini) → 수요 검증 후 2(Codex) → 3.
- 관련: `AGENTS.md`(SSOT 초안 완성), `install.sh`(`install`·`merge_dotfile`·`case` 변경 대상),
  `CLAUDE.md`(import 블록 재배선).
