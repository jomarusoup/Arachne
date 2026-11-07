---
description: Go 빌드·go vet·린터 오류를 하나씩 최소 수정으로 해결 — go-build-resolver 에이전트 호출
---

# /go-build — Go 빌드 오류 해결

**go-build-resolver** 에이전트를 호출해 Go 빌드 오류를 한 번에 하나씩, 최소 변경으로 고친다.
목표는 빌드 녹색이다 — 리팩터링·설계 변경은 하지 않는다.

## 동작

1. **진단** — `go build` · `go vet` · `staticcheck` · `golangci-lint` · `go mod verify`
2. **분류** — 파일별로 묶고 build → vet → lint 순으로 정렬 (첫 오류의 연쇄 결과는 묶어서 처리)
3. **점진 수정** — 오류 하나에 수정 하나
4. **수정마다 재빌드** — 남은 오류 수 추적, 늘어나면 되돌림
5. **최종 확인** — `go vet ./...` · `go test ./...` 통과 확인 후 요약

## 언제 사용하나

- `go build ./...`가 실패할 때
- `go vet ./...`·`golangci-lint run`이 경고를 낼 때
- `go.mod`·`go.sum`이 깨졌을 때 (checksum mismatch, 누락 모듈)
- pull·rebase 후 빌드가 깨졌을 때

## 진단 명령

```bash
go build ./...
go vet ./...
staticcheck ./...
golangci-lint run
go mod verify
go mod tidy -v
```

## 수정 예시

```
$ go build ./...
internal/order/service.go:31:9: undefined: Repository
internal/order/handler.go:58:2: missing return

[FIXED] internal/order/service.go:31
오류: undefined: Repository
원인: storage 패키지로 옮겨진 타입을 이전 이름으로 참조
수정: storage.Repository 로 정정 + import 추가
남은 오류: 1

[FIXED] internal/order/handler.go:58
오류: missing return
원인: 상태 switch 의 default 분기 반환 누락
수정: default 분기에 return nil, ErrUnknownStatus 추가
남은 오류: 0

빌드 상태: SUCCESS | 수정한 오류: 2 (build 2) | 수정 파일: internal/order/service.go, internal/order/handler.go
후속: go vet pass · go test ./... pass
```

## 수정 전략

1. **빌드 오류 먼저** — 컴파일돼야 나머지 검사가 의미 있다
2. **vet 경고 다음** — 의심 구문 (printf 인자 불일치, 복사된 락 등)
3. **lint 지적 마지막** — 스타일·모범 사례
4. **한 번에 하나** — 수정마다 재빌드로 확인
5. **최소 변경** — `//nolint`·`_ = x`로 증상만 숨기지 않는다

## 중단 조건

- 같은 오류가 3회 시도 후에도 지속
- 수정이 새 오류를 더 많이 만듦
- 패키지 구조 변경이 필요 (예: import cycle 해소가 설계 판단을 요구) → `planner`
- 외부 의존성·네트워크·자격증명 부재

## 연계

- 빌드 녹색 후 테스트: `/go-test`
- 품질 리뷰: `/go-review`
- 커밋 전 검증: `/verify` (스킬 `verification-loop`)
- cgo·링커·런타임 크래시는 `debugger` 에이전트
- 에이전트: `agents/go-build-resolver.md` · 스킬: `golang-patterns`
