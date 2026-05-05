---
paths:
  - "src/css/*.css"
  - "src/index.html"
  - "src/js/*.js"
---
# UI 레이아웃 기준

사용자는 열 폭·버튼 간격·컴포넌트 크기에 민감하다. 아래 기준을 UI 수정 시 기본값으로 삼는다.

## 열 폭 (테이블)

- `table-layout:auto` 기본 — 내용에 따라 유동적으로 결정
- `table-layout:fixed` + 하드코딩 px 조합 **금지**
- **greedy 열 패턴** — 주된 텍스트 열 하나에 `width:100%` 또는 `flex:1` 부여해 나머지 열이 content 크기로 수축하게 함

```css
/* 예: 두 번째 열을 greedy로 */
.my-table th:nth-child(2) { width: 100%; }
```

- 액션 열(버튼 전용): `width:32px` 이하, 내용 기준 최소화
- 텍스트 열 헤더 내부 div에 `min-width:80px` — 빈 열이 너무 좁아지지 않게

## 버튼 크기·간격

| 용도 | 클래스 | padding | font-size |
|---|---|---|---|
| 주요 액션 | `btn btn-primary` | 8px 16px | 13px |
| 보조 액션 | `btn btn-ghost btn-sm` | 4px 10px | 12px |
| 테이블 헤더 인라인 | `.inv-th-btn` 계열 | 2px 5px | 11px |
| 탭 컨트롤 | `.inv-tab-ctrl-btn` 계열 | 3px 6px | 12px |

- flex gap: 버튼 그룹 `gap:8px`, 인라인 아이콘 버튼 `gap:2~4px`
- **호버 시 표시 패턴** — 행·열 컨트롤은 `:hover`에서만 노출

```css
.ctrl { display:none; }
.row:hover .ctrl { display:inline-flex; }
```

## 패딩

| 위치 | 값 |
|---|---|
| 테이블 `th` | `padding:9px 12px` |
| 테이블 `td` | `padding:8px 12px` |
| 컨테이너 body | `padding:20px` |
| toolbar/filter 영역 | `margin-bottom:14~16px` |

## 신규 컴포넌트 체크리스트

새 테이블·그리드 추가 시 반드시 확인:

- [ ] `table-layout:auto` 또는 `flex` 유동 폭
- [ ] greedy 열 지정 여부
- [ ] 액션 버튼 호버 표시 여부
- [ ] 빈 상태(empty state) 메시지
- [ ] `overflow-x:auto` 감싸기 (가로 스크롤 대비)
