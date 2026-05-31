---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go 훅

> [common/hooks.md](../common/hooks.md) 를 확장한다.

## PostToolUse — 편집 후 자동 실행

- **gofmt / goimports** — `.go` 파일 편집 후 자동 포맷
- **go vet** — 편집 후 정적 분석
- **staticcheck** — 수정된 패키지 추가 정적 검사

## 커밋 전 체크

```bash
gofmt -l ./...          # 포맷 미준수 파일 목록
go vet ./...            # 정적 분석
staticcheck ./...       # 추가 검사
go build ./...          # 빌드 확인
go test -race ./...     # 레이스 컨디션 포함 테스트
```
