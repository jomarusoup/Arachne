# archive/multi-cli — 3-레인 협업 런타임 (ADR-0004로 제거)

2026-08-29, [ADR-0004](../../docs/decisions/0004-remove-3lane-runtime.md)에 따라
3-레인 협업 런타임(위임 래퍼·가용성 폴백·쿼터 쿨다운·계측)을 현역에서 제거하고 여기 보존한다.
**규약 배포 계층(AGENTS.md SSOT + install.sh의 Gemini/Codex/Copilot 어댑터)은 현역 유지.**

## 보존 내용

| 파일 | 원위치 | 역할 |
| --- | --- | --- |
| `gemini-task.sh` | 레포 루트 | Gemini reader/advisor 위임 래퍼 (gtask) |
| `codex-task.sh` | 레포 루트 | Codex tester/fixer 위임 래퍼 (ctask) |
| `arachne-task.sh` | 레포 루트 | 가용성 폴백 디스패처 (atask) + 쿼터 쿨다운 + 계측(MetricAppend) |
| `hooks/atask-quota-warn.sh` | `hooks/` | UserPromptSubmit 쿼터 경고 훅 |
| `tests/*.bats` | `tests/` | atask·wrapper_security·solo_mode·metrics 테스트 |

## 재도입 절차 (다른 CLI 실사용 재개 시)

1. 파일들을 원위치로 `git mv` 복원
2. `install.sh` `BIN_TARGETS`에 래퍼 6항목 복원, `settings.template.json`에
   permissions(allow/ask)·`atask-quota-warn.sh` 훅 등록 복원
3. `tests/smoke_hooks.sh` atask 스텝, `tests/check_convention_sync.sh` 3-레인 토큰 쌍,
   `rules/common/workflow.md`·`AGENTS.md` 3-레인 절 복원
4. 재도입 전 [감사](../../docs/issue/2026-08-22-harness-runtime-audit.md)의 미수리 결함
   (B-01~03·B-07·B-08, C-01~04 — 쿼터 오판·상태 파일 경합)을 먼저 수리할 것
5. ADR-0004를 supersede하는 새 ADR로 결정 기록

## 재도입 전 벤더 변경 반영 (2026-09-13 감사에서 확인 — 래퍼를 그대로 복원하지 말 것)

보존된 래퍼는 제거 시점(2026-08)의 벤더 인터페이스 기준이다. 이후 확인된 변경:

1. **Gemini CLI 지속성** — 무료·소비자(Google AI Pro/Ultra) 티어는 **2026-06-18부로
   Antigravity CLI로 대체**됐다(유료 API 키·엔터프라이즈만 Gemini CLI 유지, 공식:
   developers.googleblog.com "transitioning-gemini-cli-to-antigravity-cli").
   재도입 시 인증 방식을 먼저 확인하고 대상 CLI(Gemini CLI vs Antigravity CLI)를 재선정할 것.
2. **Codex 래퍼 인터페이스** — `codex mcp-server`(MCP 서버 모드)는 제거됐고, headless의
   안정 인터페이스는 `codex exec --json`(JSONL 이벤트 스트림)이다. ctask의 plain-text
   출력 + 정규식 에러 판별(`ERROR_PATTERN`)을 `--json` 이벤트 파싱으로 재작성할 것.
3. **Gemini 래퍼 인터페이스** — `--output-format json`(단일 JSON: response·stats·error)
   / stream-JSON과 종료코드 계약(0 성공 / 1 일반·API 오류 / 42 입력 오류 / 53 턴 한도)이
   공식화됐다. gtask의 stderr 노이즈 정규식 필터(`NOISE_PATTERN`)를 JSON 파싱으로 대체할 것.
4. **레인 배정표 재검토** — read→gemini / test→codex 배정은 2026-08 모델 강점 기준이다.
   재도입 시점의 모델·CLI 지형(서브에이전트·스킬 정식화 포함)으로 원점 재검토할 것.
5. **스킬 공유** — 세 CLI 모두 Agent Skills(SKILL.md) 표준을 읽는다. Arachne `skills/`는
   2026-09-13부로 표준 포맷(`skills/<이름>/SKILL.md`)이므로 `~/.agents/skills`를 통한
   레인 간 스킬 공유가 가능하다 (Codex: `~/.agents/skills`, Gemini: `~/.agents/skills` 별칭).
