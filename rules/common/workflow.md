## AI 역할 분담 (Claude / Gemini)

| 작업 | 담당 |
|---|---|
| 기능 기획, 요구사항 정리, 설계 문서 | **Gemini** (`gemini` CLI 사용) |
| README.md 갱신 | **Gemini** (전담) |
| 아이디어 탐색, 대안 비교 | **Gemini** |
| 코드 구현, 버그 수정, 리팩터링 | **Claude** |
| `~/.claude/` 설정 관리 | **Claude** |
| DB 마이그레이션 SQL 작성 | **Claude** |
| Docker / Nginx / systemd 설정 | **Claude** |

> 기획·설계가 필요하면 `gemini -p "..."` 로 직접 위임한다.
> 구현 단계에서만 Claude가 코드를 건드린다.

---

## Gemini 위임 트리거 — 즉시 전환 요청

아래 요청이 오면 코드를 건드리지 말고 사용자에게 전달:

```
이 작업은 Gemini 담당입니다.
터미널에서 실행: gemini -p "..."
```

| 트리거 | 전환 이유 |
|---|---|
| 기능 기획·요구사항 정리 요청 | Gemini 전담 |
| 설계 문서·아키텍처 설계 요청 | Gemini 전담 |
| README.md 수정 요청 | Gemini 전담 |
| 이슈 방향·우선순위 결정 요청 | Gemini 전담 |
| 브레인스토밍·대안 비교 요청 | Gemini 전담 |

---

## 토큰 절약 원칙

- 파일 전체 읽기 금지 — grep 먼저, 필요 범위만 Read
- Gemini가 설계한 내용을 재분석하지 않고 바로 구현
- Gemini 백그라운드 실행 중 동일 작업 선제 수행 금지

---

## 전역 행동 규칙

- **파일 전체 읽기 금지** — grep으로 위치 먼저, 해당 범위만 Read
- **README.md 직접 수정 금지** — Gemini CLI 전담 영역
- **수정 전 보고** — 기능 추가·삭제 전 `[PLAN]`으로 승인 요청
- **코딩 스타일 준수** — `~/.claude/rules/common/coding-style.md` 적용
- **수정 완료 시 자동 git push** — 별도 요청 없이 수정 → `/verify` → `git push` 순서로 진행
