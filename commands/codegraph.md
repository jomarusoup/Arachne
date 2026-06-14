---
description: codegraph CLI로 코드 그래프·심볼·영향 범위 분석 (조사 단계 보조)
---
# /codegraph — 코드 그래프·영향 분석

[codegraph](https://github.com/colbymchenry/codegraph) CLI를 사용해 코드베이스의
심볼·의존 관계를 그래프로 분석한다. `development-workflow §0 조사·재사용`,
`issue-workflow 범위 파악·의존성 확인` 단계에서 변경 영향 범위를 빠르게 파악할 때 쓴다.

## 전제

`codegraph` 가 PATH에 있어야 한다. 없으면 Arachne 확장 설정으로 설치:

```bash
command -v codegraph >/dev/null 2>&1 \
    && echo "codegraph: $(codegraph --version 2>/dev/null || echo installed)" \
    || echo "[안내] 미설치 — 'arachne -i --with-extras' 또는 'bash ~/Arachne/setup-extras.sh --codegraph' 로 설치"
```

## 사용

```bash
# 사용 가능한 서브커맨드 확인 (버전에 따라 다름)
codegraph --help
```

전형적인 흐름:

1. 코드베이스 인덱싱/그래프 생성 — `codegraph` 의 분석 커맨드 실행
2. 심볼·참조·의존 관계 질의로 영향 범위 도출
3. 결과를 조사 단계 근거로 사용 — 변경 대상이 어디서 호출·참조되는지 확인

## 적용 지침

- `$ARGUMENTS` 가 있으면 그대로 `codegraph` 인자로 전달해 실행한다.
- 인자가 없으면 먼저 `codegraph --help` 로 현재 버전의 커맨드를 확인한 뒤,
  요청 맥락(영향 분석·의존 추적·심볼 검색)에 맞는 서브커맨드를 선택해 실행한다.
- 대규모 출력은 컨텍스트에 통째로 끌어오지 말고 필요한 범위만 요약해 사용한다
  (토큰 절약 — `rules/common/performance.md`).
