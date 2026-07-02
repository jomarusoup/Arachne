---
description: UI·컴포넌트 설계 문서 작성 및 디자인 개선 계획 제안
---
# /design [대상]

## 사용법

```
/design              프로젝트 전체 디자인 개선 계획 제안
/design 색상         색상 팔레트만 변경
/design 타이포       폰트·크기·자간만 변경
/design 버튼         버튼 컴포넌트만 변경
/design [컴포넌트명] 해당 컴포넌트만 변경
```

## 실행 순서

### 1. 디자인 스펙 읽기 (항상 먼저)

다음 순서로 디자인 문서를 읽는다.

1. `docs/design/DESIGN.md` — 프로젝트 제품 디자인 정본
2. `docs/design/README.md` — 분리 문서 인덱스가 있으면 관련 문서까지 추적
3. 루트 `DESIGN.md` — legacy fallback. 자동 이동·삭제 금지
4. 문서가 없으면 `rules/common/ui-layout.md`와 `rules/web/design-quality.md` 기준을 적용하고,
   새 디자인 문서 생성은 [PLAN]에서 범위와 소유권을 먼저 제안

수정 후 디자인 결정이나 QA 결과가 바뀌면 `docs/design/decisions/` 또는 관련 design 문서를 갱신할지
확인한다.

### 2. 현재 상태 파악

대상에 따라 최소 범위만 읽기:

```bash
# CSS 변수·테마 (색상·폰트·radius 변경 시)
sgrep ":root|data-theme|--color|--font"

# 특정 컴포넌트
sgrep "\.btn|\.modal|\.sidebar|컴포넌트명"
```

### 3. [PLAN] 제시 — 반드시 승인 후 진행

```
[DESIGN PLAN] {대상}

현재: {현재 값}
변경: {목표 값}
영향 범위: {CSS 변수만 / 컴포넌트 직접 / 양쪽}
예상 수정 줄: {N줄}
```

여러 영역 변경 시 색상 / 타이포 / 컴포넌트로 나눠 단계별 승인.

### 4. 수정 원칙

- **CSS 변수 우선** — `:root` 변수 수정 시 모든 컴포넌트에 cascade 적용
- 다크·라이트 테마 **둘 다** 수정
- 컴포넌트 직접 수정은 변수로 해결 안 되는 경우만

### 5. /verify 실행

수정 후 반드시 실행.

### 6. /git 커밋

메시지 형식: `style: {변경 내용}`
