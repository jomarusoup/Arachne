---
Title: "ADR-0008 언어 범위 재정의 — C 서버, Rust 클라이언트·유틸, GC 런타임 제외, Rust 경계 이식"
creation: 2026-11-21
modification: 2026-11-21
tags:
 - "arachne"
 - "decision"
 - "objectives"
aliases:
 - "adr-language-scope"
---
MOC:: [[Arachne]]
FROM:: [[2026-11-20-harness-direction-plan]]

# ADR-0008: 언어 범위 재정의 — C 서버, Rust 클라이언트·유틸, GC 런타임 제외, Rust 경계 이식

## 상태

Accepted (2026-11-21 사용자 확정 — 언어 범위·계층·결정 D-01·02·03·05·07·08·11)

## 배경

1. [ADR-0007](0007-harness-direction-lowlatency.md)은 메인 언어를 C·C++·Rust·Go, 유틸 언어를 Python·Shell로,
   보조 계층을 Go 주력으로 두었다. 이 경우 유틸·보조가 GC 런타임으로 메인과 같은 장비에서 돌면서
   GC 정지·메모리 증가로 메인을 방해할 수 있다. "유틸은 메인을 늦추지 않는다"는 제약을 지키려면 언어부터
   메모리를 직접 통제할 수 있어야 한다.
2. 계획 결정 D-01의 권장안은 C++ + Dear ImGui였다. 하지만 데이터 수신 유실은 언어가 아니라 수신 구조
   (수신·렌더 스레드 분리, 버퍼 재사용, 시퀀스 갭 재요청)에서 결정된다. 그래서 Rust 클라이언트도 C++과
   같은 수준을 낸다. 오히려 Rust 클라이언트는 계획 2-5 Rust 유틸과 디코더 하나를 함께 쓸 수 있다.
3. C·C++ 메모리 안전 취약점이 계속 나오고 있고, 업계는 메모리 안전 언어로 옮겨 가고 있다
   (CISA·NSA 권고, Linux 커널·Android의 Rust 도입). 취약점은 외부 입력을 해석하는 코드(파서·디코더)에
   몰린다.

## 결정

1. **서버 메인은 C 중심이다.** 객체 지향은 C 컴파일러 안에서 패턴으로 쓴다: 불투명 핸들, 함수 포인터 ops 테이블,
   초기화 역순 해제(`c-server-patterns`). 이 구조는 Rust로 직접 대응된다(핸들 → 구조체 + impl,
   ops 테이블 → trait, `c-to-rust-migration`). C++은 범위에 남기되 기존 C++ 코드·라이브러리 연동에만 쓰고,
   서버 기본 언어로 쓰지 않는다.
2. **클라이언트는 Rust + egui다** (D-01). 최종 확정은 계획 2-7 스파이크에서 한다. 폼·텍스트 입력·접근성
   요구가 커지면 툴킷을 다시 판정한다.
3. **모든 계층은 메모리를 직접 통제하는 언어로만 만든다.** 서버 메인·보조·유틸과 클라이언트는 C·C++·Rust로
   만들고, 조회·조립은 Shell로 한다. GC 런타임 언어(Go·Python·JVM·Node)는 범위 밖이다. 이 결정은
   ADR-0007의 "Go 핫패스 금지"를 포함하고 더 넓힌다.
   - exporter(보조)는 Rust로 만든다. 공유메모리를 `PROT_READ`로 매핑하고 시퀀스 락으로 읽은 뒤
     `/metrics`로 내보낸다. D-09는 접근 방식 (a)를 유지하고 구현 언어만 cgo → Rust로 바꾼다.
   - Go·Python 자산(리뷰어·커맨드·규칙·스킬·profile)은 계획 2-1에서 아카이브한다. 하네스 자체 테스트가
     의존하는 Python fixture는 2-1에서 CI 통과 조건으로 따로 판정한다.
4. **Rust 강화는 경계부터 옮기는 방식으로 한다.** 전면 재작성은 하지 않는다.
   1. 외부 입력 디코더를 Rust crate 하나로 만든다. 클라이언트(2-7)와 유틸(2-5)이 이 crate를 함께 쓰고,
      C 디코더와 같은 테스트 벡터로 교차 검증한다.
   2. 보조·유틸을 Rust로 만든다(2-5·2-6). 메인에 영향이 없는 곳에서 경험을 쌓는다.
   3. 서버 메인 모듈은 C로 유지한다. Rust 이식은 측정으로 해당 모듈의 지연·할당 예산(`budgets.yaml`)을
      충족함을 보이고 `c-to-rust-migration`의 판단 기준을 통과한 모듈에만 한다.
   - 하네스 자산은 동결을 유지한다. 기존 Rust 규칙·스킬·리뷰어를 파이프라인에서 쓰고, 부족한 점은
     실패 기록으로 남겨 수확한다(수확 원칙).
   - 검증 도구(`cargo-deny`·`cargo-audit`·`cargo-fuzz`·Miri)는 파이프라인 CI(2-8)에서 먼저 쓴다.
     효과가 확인되면 4-4에서 rust profile로 승격한다.
5. **나머지 계획 결정을 권장안으로 확정한다.**

   | 결정 | 확정 내용 |
   |---|---|
   | D-02 | 모니터링은 Prometheus `/metrics` + Grafana. 웹 코드 0줄 |
   | D-03 | 처리량 목표는 사람이 정하고, 지연·자원 예산은 기준 장비 실측 기준선 × 여유율. 공개 벤치는 방법론만 참고 |
   | D-05 | 기준 장비는 현재 작업 서버(i5-8400 6C, Rocky 9.8, 커널 5.14) — `budgets.yaml` `environment` |
   | D-07 | 계획 결정 레지스터의 D-07 행(확정 목록) |
   | D-08 | Gemini·Codex·Copilot 어댑터와 `install-copilot.ps1`은 아카이브하고, `AGENTS.md`는 공용 규약 문서로 유지 |
   | D-11 | 파이프라인 프로젝트는 별도 비공개 저장소 |

### 대체하는 기존 결정

| 기존 | 내용 | 이 ADR의 처리 |
|---|---|---|
| ADR-0007 범위·계층(OBJECTIVES §2·§3) | 메인 C·C++·Rust·Go, 유틸 Python·Shell, 보조 Go 주력 | **대체** — 결정 1·3 |
| ADR-0007 공통 제약 "Go는 핫패스 금지" | Go를 메인 핫패스에서만 금지 | **일반화** — GC 런타임 언어를 모든 계층에서 범위 밖으로 |
| 계획 D-01 권장안 | C++ + Dear ImGui | **대체** — Rust + egui |
| 계획 D-06 | "Go 핫패스 금지" 위치 | **해소** — OBJECTIVES §3의 언어 제약이 정본 |
| 계획 D-09 | cgo exporter | **구현 언어만 대체** — Rust, 접근 방식(PROT_READ + 시퀀스 락) 유지 |
| 계획 D-15 | `report.mjs` → Python 재작성 | **대체** — Shell(awk) 우선, 부족하면 Rust |
| 계획 D-16 | Rust 유틸·C++ 클라이언트 디코더 | **대체** — Rust 유틸·Rust 클라이언트(같은 crate) |
| ADR-0006 D-06 | Rust는 C 모듈의 점진 이식 대상 | **유지·구체화** — 결정 4의 경계 우선 순서 |

## 대안

- **ADR-0007 범위 유지(Go 보조·Python 유틸)**: 생태계가 넓고 개발이 빠르다. 하지만 GC 런타임이 메인과
  같은 장비에서 돌고, 규칙·리뷰어·스킬 자산이 두 언어만큼 더 남는다(축소 지향과 충돌). 기각.
- **C++ + Dear ImGui 클라이언트**: C 헤더를 그대로 include할 수 있다. 하지만 디코더가 Rust 유틸과
  별도 구현이 되고 메모리 안전성 이점이 없다. 기각.
- **서버 메인도 Rust로 전면 이식**: 기준선 없이 바꾸면 정확성·지연 회귀를 판정할 수 없다. 측정 후 모듈
  단위로 하는 결정 4의 3번으로 대신한다. 기각.

## 결과

- [`docs/OBJECTIVES.md`](../OBJECTIVES.md) §2 범위·§3 계층·공통 제약을 갱신한다.
- [`objectives/budgets.yaml`](../../objectives/budgets.yaml) `environment`에 기준 장비를 기록하고,
  보조 계층 주석을 Rust exporter로 바꾼다.
- [계획](../task/2026-11-20-harness-direction-plan.md): 성공 기준 1, 작업 2-2·2-6·2-7·2-8·4-4, 결정
  레지스터 D-01~D-11·D-15·D-16을 갱신한다.
- 아카이브 실행(Go·Python 자산 포함)은 계획 2-1이 맡는다. 이 ADR은 대상만 정한다.
- ADR-0007 본문은 기록이므로 고치지 않는다. 대체 관계는 이 ADR이 정본이다.

## 검증

```bash
bats tests/objectives.bats
bash tests/check_index.sh && bash tests/check_convention_sync.sh
grep -nE 'Go 주력|Python, Shell|C, C\+\+, Rust, Go' docs/OBJECTIVES.md   # 0건
```
