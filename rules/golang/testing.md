---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go 테스팅

> [common/testing.md](../common/testing.md) 를 확장한다.

## 프레임워크

표준 `go test` + **테이블 드리븐 테스트**.

## 테스트 실행

```bash
go test ./...                    # 전체 테스트
go test -race ./...              # 레이스 컨디션 검사
go test -cover ./...             # 커버리지
go test -v -run TestName ./...   # 특정 테스트
```

## 테이블 드리븐 테스트

```go
func TestParseHeader(t *testing.T) {
    tests := []struct {
        name    string
        input   []byte
        want    *Header
        wantErr bool
    }{
        {"유효한 헤더", []byte{0x01, 0x02}, &Header{Type: 1, Len: 2}, false},
        {"빈 입력", []byte{}, nil, true},
        {"nil 입력", nil, nil, true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseHeader(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("wantErr=%v got err=%v", tt.wantErr, err)
            }
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("want=%v got=%v", tt.want, got)
            }
        })
    }
}
```

## 커버리지 리포트

```bash
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```
