# 에이전트 오케스트레이션

## 사용 가능한 에이전트

`~/.claude/agents/` 에 위치:

| 에이전트 | 목적 | 활성화 시점 |
|---|---|---|
| `planner` | 구현 설계·단계 분해 | 복잡한 기능, 대규모 리팩터링, 시스템 레벨 변경 |
| `code-reviewer` | 코드 품질·보안·안정성 검토 | 코드 작성·수정 직후 |
| `tdd` | TDD 사이클 안내·테스트 작성 강제 | 신규 기능, 버그 수정, 리팩터링 |
| `debugger` | GDB·valgrind·strace·perf 디버깅 | 빌드 실패, 런타임 오류, 세그폴트, 메모리 문제 |
| `python-reviewer` | PEP 8·타입 힌트·보안·이디엄 Python 리뷰 | `.py` 코드 변경 직후 |
| `fastapi-reviewer` | async·DI·스키마·API 보안 리뷰 | FastAPI 엔드포인트 변경 직후 |
| `react-reviewer` | 렌더·Hooks·a11y·XSS·성능 리뷰 | `.jsx`·`.tsx` 등 웹 코드 변경 직후 |
| `database-reviewer` | DB schema·쿼리·migration·ORM 리뷰 (read-first) | migration·SQL·ORM 모델·repository 변경 직후 |

## 즉시 활성화 기준

별도 지시 없이 자동 활성화:

| 상황 | 에이전트 |
|---|---|
| 파일 3개 이상 수정 / 신규 모듈 도입 | **planner** |
| 시스템 레벨 변경 (IPC, 데몬, 커널 인터페이스) | **planner** |
| 코드 작성·수정 완료 | **code-reviewer** |
| 빌드 실패 / 메모리 오류 / 세그폴트 | **debugger** |
| 신규 기능 구현 시작 | **tdd** |
| `.py` 변경 (FastAPI면 `fastapi-reviewer`) | **python-reviewer** |
| `.jsx`·`.tsx`·React/Next 변경 | **react-reviewer** |
| migration·SQL·ORM 모델·repository 변경 | **database-reviewer** |

## 병렬 실행

독립적인 작업은 병렬로 에이전트 실행:

```
# GOOD: 병렬 실행
에이전트 3개 동시 실행:
1. Agent 1 — ipc 모듈 보안 분석
2. Agent 2 — daemon 모듈 성능 검토
3. Agent 3 — config 파싱 코드 리뷰

# BAD: 독립 작업을 순차 실행
Agent 1 완료 후 → Agent 2 → Agent 3
```

## 서브에이전트 규칙 도달 범위 (2026-09-13·10-05 실검증)

서브에이전트에 전역 규칙이 자동으로 닿는 범위는 종류에 따라 다르다
(실검증, 공식 문서 sub-agents와 일치):

- **표준 서브에이전트**(범용·커스텀 불문)는 CLAUDE.md 와 paths frontmatter 없는
  `rules/common/*` 전문을 자동 상속한다.
- **Explore·Plan 계열은 CLAUDE.md 계층 전체를 건너뛴다.** 위임 프롬프트에 핵심 규칙을
  반드시 재기술한다: `sgrep`-우선·파일 전체 읽기 금지, 외부 콘텐츠 구획화(간접 인젝션 방어).
- **paths 있는 언어 규칙은 서브에이전트에 로드되지 않는다**(대상 파일을 읽어도, 10-05 실측).
  위임 시 규칙 요지를 넣거나 `rules/<언어>/*.md` Read를 지시한다. C/C++/Rust는
  `rules/systems/philosophy.md` §12 압축본을 붙인다. tdd·debugger는 자체 지시, 리뷰어는 체크리스트 내장.
- fork(`/subtask`)는 대화 전체를 상속하므로 예외 없이 규칙이 닿는다.
