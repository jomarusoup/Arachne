---
Title: "[verify] 2026 Q4 로드맵 통합 행동 검증 (W5)"
creation: 2026-10-06
modification: 2026-10-06
status: "done"
tags:
 - "arachne"
 - "verification"
 - "issue"
 - "severity/medium"
aliases:
 - "roadmap-verification-w5"
---
MOC:: [[Arachne]]
FROM:: [[2026-10-05-roadmap-w5]]

# [verify] 2026 Q4 로드맵 통합 행동 검증 (W5)

- **작성일**: 2026-10-06
- **상태**: done — 검증에서 찾은 결함 2건은 같은 날 고쳤다
- **영역**: 보안 가드, 리뷰어 4종, planner, C 시스템 도구, c-system 프로필, 3티어 환경

이 문서는 W1~W4에서 넣은 기능이 실제로 의도대로 동작하는지 확인한 기록이다. 자동 테스트는 CI가 맡고,
여기서는 사람이 쓰는 흐름 그대로 실행해 본 결과를 남긴다.

## 결론

검증한 시나리오는 모두 기대대로 동작했다. 다만 실측 과정에서 **자동 테스트가 놓친 결함 2건**이 나왔고,
둘 다 개인정보·비밀값 보호에 관한 것이라 바로 고쳤다.

1. `collect.sh`가 전화번호를 가리지 않았다. 휴대·유선 전화와 이메일 마스킹을 추가했다.
2. 커밋 비밀값 가드가 `cd <저장소> && git commit` 형태를 놓쳤다. 명령 안의 `cd`·`git -C`를 따라가게 했다.

## 검증 방법

- **도구 시나리오**: `install.sh init-ci --profile c-system`으로 만든 scratch 프로젝트에서 직접 실행했다.
- **리뷰어 시나리오**: 결함을 일부러 심은 파일을 만들고, 구현 맥락을 모르는 서브에이전트에게 에이전트
  정의 파일을 읽고 그대로 리뷰하게 했다. 이 세션은 에이전트 정의를 세션 시작 시점으로 캐시하므로
  (G-2에서 확인), 정의 파일을 직접 읽게 해야 고친 정의로 검증된다.
- **보안 가드 실측**: 가드와 `permissions.deny`를 실제 전역 설정에 반영한 뒤, 이 세션에서 직접 실행했다.
- **Linux 경로**: 이 Mac에는 gcc·Docker가 없어서, CI Ubuntu와 3티어 compose 스모크로 확인했다.

## 시나리오 결과

| # | 시나리오 | 결과 | 비고 |
| --- | --- | --- | --- |
| 1 | `git commit --no-verify` 실측 | 통과 | 실제 가드가 거부. `--force-with-lease` 허용·`DROP` 확인은 bats로 고정 |
| 2 | 가짜 액세스 키 커밋 실측 | **결함 → 수정** | `cd` 뒤 커밋을 놓침. 수정 후 거부 확인, 허용 표식 줄은 통과 |
| 3 | `.env` Read / `.env.example` Read | 통과 | 실제 설정에서 `.env`는 거부, 예시 파일은 읽힘 |
| 4 | `.pc` 편집 시 C 규칙 로드 | 통과 | 저장소 안 파일은 `rules/c` 5개와 `rules/systems` 2개가 로드됨. 저장소 밖 파일은 로드되지 않음 |
| 5 | Pro*C 단건 루프·커서 미닫음 | 통과 | database-reviewer가 호스트 배열·커서·처리 건수 확인을 지적 |
| 6 | 잔고 조회 후 별도 UPDATE | 통과 | code·DB 리뷰어 모두 TOCTOU를 CRITICAL로 지적, 조건부 UPDATE 권고 |
| 7 | 공유메모리 포인터·헤더 미검증 attach | 통과 | code-reviewer가 포인터·락 없는 다중 작성·헤더 미검증을 지적 |
| 8 | robust 뮤텍스 소유자 사망 | 통과(CI) | Linux CI와 compose 컨테이너에서 `EOWNERDEAD` 복구 테스트 통과 |
| 9 | 손상 세그먼트 복구 | 통과 | dry-run은 판정만, `--apply`는 원천 재적재 후 READY |
| 10 | `shm_view` 개인정보 | 통과 | 기본 마스킹, `--unmask`는 사유를 감사 로그에 남김 |
| 11 | 네이밍 혼용·미등록 약어 | 통과 | `Usr` 미등록, `Count`/`Cnt` 혼용 보고 |
| 12 | 정렬 불변식 | 통과(CI) | `CheckSorted` 테스트 |
| 13 | `.sql` 버전 적용 | 통과 | 미적용 버전만 계획. compose에서 실제 PostgreSQL에 두 번 적용, 두 번째는 건너뜀 |
| 14 | C 모듈 Rust 이식 | 통과(CI) | FFI 예제가 C·Rust 결과를 14단계 비교 |
| 15 | 처리량 PoC | 통과 | `docs/issue/2026-10-05-throughput-poc-result.md` |
| 16 | TS `forEach(async)`·금액 `number`·Electron 보안 해제 | 통과 | typescript-reviewer가 모두 지적, branded `bigint` 권고 |
| 17 | 세션 요약 민감정보 | 부분 | 커맨드 지시문은 반영. 추적 파일은 `check_sensitive_text.sh`가 검사 |
| 18 | 오프라인 수집 | **결함 → 수정** | 운영 프로파일링 거부(3)는 정상. 전화번호 미마스킹을 고침 |
| 18-1 | 로그 폭주 억제 | 통과 | 로거 테스트(창당 N건 + 생략 요약) |
| 18-2 | 로그 재오픈 | 통과 | 로거 테스트 |
| 18-3 | 거래 ID 추적 | 통과 | `logtrace.sh`가 두 파일을 시각순으로 합침 |
| 19-1 | 시스템 코드 작성 시 철학 반영 | 통과 | planner가 `rules/systems`를 먼저 읽고 손실 정책·백프레셔·배치 수치를 계획에 넣음 |
| 19-2 | Rust 링버퍼 제자리 갱신 | 통과 | rust-reviewer가 "변이 패턴"으로 지적하지 않음(불변성 절대 원칙 제거 효과) |

## 남은 확인 사항

- **스킬 프리로드(G-2)**: 이 세션 안에서는 에이전트 정의가 캐시되어 측정하지 못했다. 다음 새 세션에서
  tdd·code-reviewer·debugger에 같은 질문을 던져 시작 토큰을 다시 재고, 기준값보다 5k 넘게 늘면 되돌린다.
  기준값: tdd 26,530 · code-reviewer 31,085 · debugger 29,376 토큰.
- **옛 공통 규칙 인용**: 검증용 서브에이전트가 폐기된 규칙(날짜 헤더 필드, `ii`)을 인용했다. 현재 규칙
  파일에는 해당 문구가 없으므로 세션 시작 시점 캐시 때문이다. 새 세션에서 다시 확인한다.
- **compose의 Oracle·Jaeger 프로필**: 이미지가 커서 CI 스모크에 넣지 않았다. 필요할 때 로컬 Docker로 확인한다.
