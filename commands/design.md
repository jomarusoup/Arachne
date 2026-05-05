# /design [대상]

## 사용법
```
/design              DESIGN.md 전체 기준으로 디자인 개선 계획 제안
/design 색상         색상 팔레트만 변경
/design 타이포        폰트·크기·자간만 변경
/design 버튼         버튼 컴포넌트만 변경
/design 사이드바      사이드바 스타일만 변경
/design [컴포넌트명]  해당 컴포넌트만 변경
```

## 실행 순서

### 1. DESIGN.md 읽기 (항상 먼저)
```
Read DESIGN.md (프로젝트 루트)
```
디자인 스펙 전체를 파악한 뒤 진행. 세션에 이미 읽었으면 생략 가능.

### 2. 현재 CSS 상태 파악
대상에 따라 최소 범위만 읽기:

```bash
# 테마 변수 전체 (색상·폰트·radius 변경 시)
# taskflow.html 8~31줄 Read

# 특정 컴포넌트 (버튼·사이드바 등)
grep -n "\.btn\|BUTTONS" taskflow.html | head -10
grep -n "SIDEBAR\|\.nav-item\|\.logo" taskflow.html | head -10
grep -n "\.modal\|MODAL" taskflow.html | head -10
```

### 3. [PLAN] 제시 — 반드시 승인 후 진행

PLAN 형식:
```
[DESIGN PLAN] {대상}

현재: {현재 값}
변경: {DESIGN.md 기준 목표 값}
영향 범위: {CSS 변수만 / 컴포넌트 직접 / 양쪽}
예상 수정 줄: {N줄}
```

여러 영역 변경 시 **한 번에 전부 제안하지 않음** — 색상 / 타이포 / 컴포넌트로 나눠서 단계별 승인.

### 4. 수정 원칙

**변수 우선** — `:root` / `[data-theme]` 변수 수정 시 모든 컴포넌트에 자동 cascade:
```css
/* 다크 테마 */
:root,[data-theme="dark"] { ... }
/* 라이트 테마 */
[data-theme="light"] { ... }
```

**컴포넌트 직접 수정은 최소화** — 변수로 해결 안 되는 border-radius, letter-spacing, line-height, box-shadow 등만 직접 건드림.

**폰트 제약** — SF Pro는 외부 CDN 불가. `system-ui, -apple-system, BlinkMacSystemFont` 로 대체 (Apple 기기에서는 SF Pro로 렌더링됨).

### 5. /verify 실행
수정 후 반드시 실행.

### 6. /git 커밋
메시지 형식: `style: {변경 내용}`
예) `style: Apple 디자인 시스템 색상 팔레트 적용`

---

## DESIGN.md → taskflow.html 매핑 치트시트

| DESIGN.md 항목 | taskflow.html CSS 변수/선택자 |
|---|---|
| Pure Black `#000000` | `--bg` (다크), 섹션 배경 |
| Light Gray `#f5f5f7` | `--bg` (라이트), `--s2` |
| Near Black `#1d1d1f` | `--text` (라이트) |
| Apple Blue `#0071e3` | `--amber` 대체 (primary accent) |
| White text on dark | `--text` (다크) |
| Border radius 8px | `--r` |
| SF Pro / system-ui | `--sans` |
| Card shadow | `.grp-card`, `.modal` box-shadow |
| Nav glass blur | `#sidebar` backdrop-filter |

## 주의사항

- `--amber` 는 현재 primary accent (nav active, logo, btn-primary). Apple Blue `#0071e3`로 전환 시 모든 amber 참조 확인 필요
- 다크/라이트 테마 **둘 다** 수정 — 한쪽만 바꾸면 테마 전환 시 깨짐
- `color:var(--amber)` 하드코딩된 JS 내 인라인 스타일 있음 → grep으로 확인
  ```bash
  grep -n "color:var(--amber)\|#F4A832\|amber" taskflow.html | head -20
  ```
