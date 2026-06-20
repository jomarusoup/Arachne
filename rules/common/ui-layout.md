# UI 레이아웃 기준

웹 UI 수정 시 기본값으로 삼는 범용 레이아웃 원칙.
프로젝트별 구체적인 클래스명·수치는 각 프로젝트의 `CLAUDE.md`에서 정의한다.

## 참고 예시 위치

UI/UX 예시는 프로젝트 문서의 `docs/ui-ux/examples/`에 둔다.

- 화면 단위 예시: `docs/ui-ux/examples/<screen-name>.md`
- 컴포넌트 단위 예시: `docs/ui-ux/examples/component-<name>.md`
- 개선 전후 기록: `docs/ui-ux/examples/<target>-before-after.md`

예시 문서는 문제, 사용자, 레이아웃 의도, 간격·정렬 규칙, 상태(loading/empty/error), 검증 방법을 포함한다.

## 간격 시스템

기본 간격은 4px 배수를 사용한다.

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `space-1` | 4px | 아이콘과 짧은 라벨 사이 |
| `space-2` | 8px | 인라인 컨트롤, 버튼 그룹 |
| `space-3` | 12px | compact 셀 내부 |
| `space-4` | 16px | 폼 필드 간격, 카드 내부 최소 패딩 |
| `space-5` | 20px | 일반 컨테이너 패딩 |
| `space-6` | 24px | 섹션 내부 여백 |
| `space-8` | 32px | 주요 섹션 간격 |

간격은 같은 숫자를 반복하는 것이 아니라 정보의 관계를 표현해야 한다.
서로 가까운 정보는 4~8px, 같은 그룹은 12~16px, 다른 그룹은 24px 이상으로 분리한다.

## 정렬 원칙

- 텍스트와 숫자는 기준선을 맞춘다. 아이콘은 광학적으로 중앙에 맞춘다.
- 폼 label, input, help text는 같은 좌측 축에 놓는다.
- 테이블 숫자 열은 우측 정렬, 텍스트 열은 좌측 정렬을 기본으로 한다.
- 툴바의 주요 액션은 한쪽 끝에 모으고, 필터와 검색은 스캔 순서에 맞춘다.
- 카드 그리드는 카드 내부 요소의 시작점이 서로 맞아야 한다.
- 버튼 안 아이콘과 텍스트 사이 간격은 6~8px을 기본으로 한다.

## 밀도

| 화면 성격 | 밀도 | 기준 |
| --- | --- | --- |
| 운영 대시보드 | 높음 | 더 많은 행, 낮은 장식, 빠른 스캔 |
| 설정/폼 | 중간 | label, help, error가 안정적으로 보임 |
| 랜딩/브랜드 | 낮음 | 여백과 시각 자산으로 메시지 전달 |
| 모바일 작업 화면 | 중간 | 터치 영역 44px 이상, 줄바꿈 안정성 우선 |

SaaS·운영 도구는 marketing hero보다 반복 작업의 스캔성과 조작성에 맞춘다.

## 열 폭 (테이블)

- `table-layout:auto` 기본 — 내용에 따라 유동적으로 결정
- `table-layout:fixed` + 하드코딩 px 조합 **금지**
- **greedy 열 패턴** — 주된 텍스트 열 하나에 `width:100%` 또는 `flex:1` 부여해 나머지 열이 content 크기로 수축하게 함

```css
/* 두 번째 열을 greedy로 */
.my-table th:nth-child(2) { width: 100%; }
```

- 액션 열(버튼 전용): `width:32px` 이하, 내용 기준 최소화
- 텍스트 열 헤더에 `min-width:80px` — 빈 열이 너무 좁아지지 않게

## 버튼 크기·간격

| 용도               | padding  | font-size |
| ------------------ | -------- | --------- |
| 주요 액션          | 8px 16px | 13px      |
| 보조 액션          | 4px 10px | 12px      |
| 테이블 헤더 인라인 | 2px 5px  | 11px      |
| 탭 컨트롤          | 3px 6px  | 12px      |

- flex gap: 버튼 그룹 `gap:8px`, 인라인 아이콘 버튼 `gap:2~4px`
- 최소 히트 영역: 40×40px, 터치 중심 화면은 44×44px 이상
- **호버 시 표시 패턴** — 행·열 컨트롤은 `:hover`에서만 노출

```css
.ctrl { display:none; }
.row:hover .ctrl { display:inline-flex; }
```

## 패딩

| 위치                | 값                      |
| ------------------- | ----------------------- |
| 테이블 `th`         | `padding:9px 12px`      |
| 테이블 `td`         | `padding:8px 12px`      |
| 컨테이너 body       | `padding:20px`          |
| toolbar/filter 영역 | `margin-bottom:14~16px` |

## 상태별 레이아웃

- Loading: 기존 레이아웃 크기를 유지한다. 로딩 텍스트가 레이아웃을 밀지 않게 한다.
- Empty: 사용자가 다음에 할 수 있는 행동을 하나만 명확히 제시한다.
- Error: 복구 가능한 액션과 오류 요약을 보여준다. stack trace를 UI에 노출하지 않는다.
- Disabled: 이유가 필요한 경우 tooltip/help text로 설명한다.

## 신규 컴포넌트 체크리스트

새 테이블·그리드 추가 시 반드시 확인:

- [ ] `table-layout:auto` 또는 `flex` 유동 폭
- [ ] greedy 열 지정 여부
- [ ] 액션 버튼 호버 표시 여부
- [ ] 빈 상태(empty state) 메시지
- [ ] `overflow-x:auto` 감싸기 (가로 스크롤 대비)
- [ ] 4px 기반 간격 체계를 따른다
- [ ] 텍스트·숫자·아이콘 정렬 기준이 명확하다
- [ ] loading/empty/error/disabled 상태가 레이아웃을 깨지 않는다
