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
