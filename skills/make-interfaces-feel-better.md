---
name: make-interfaces-feel-better
description: 인터페이스를 세련되게 느껴지게 만드는 구체적 디자인-엔지니어링 디테일. UI 간격·타이포·보더·그림자·모션·히트 영역·아이콘·텍스트 래핑·인터랙션 상태를 검토·개선할 때 활용. 웹·데스크톱 공통.
triggers:
  paths: ["**/*.css", "**/*.tsx"]
  keywords: ["UI 폴리시", "동심 radius", "모션", "히트 영역", "광학 정렬"]
---

# 인터페이스를 더 낫게 만들기

작지만 쌓이면 인터페이스를 훨씬 세련되게 만드는 디자인-엔지니어링 디테일.

> 웹뿐 아니라 독립 데스크톱 UI에도 그대로 적용된다.

## 언제 사용하나

- 사용자가 UI가 어색하다/납작하다/제네릭하다/답답하다/덜컹거린다/미완성이라고 말할 때
- 컨트롤·카드·리스트·대시보드·내비게이션·폼·툴바를 만들 때
- 컴포넌트에 hover·active·focus·enter·exit·loading·empty 상태가 필요할 때
- 프론트엔드 리뷰에 구체적 before/after 권고가 필요할 때

## 핵심 원칙

### 동심 radius (Concentric Radius)

가까이 중첩된 둥근 표면에는:

```text
바깥 radius = 안쪽 radius + 패딩
```

패딩이 크면 공식을 강제하지 말고 레이어를 별개 표면으로 취급한다.
핵심은 공식 숭배가 아니라 **광학적 일관성**이다.

### 광학 정렬 (Optical Alignment)

기하학적 중앙이 항상 시각적 중앙은 아니다. 아이콘 버튼·재생 삼각형·화살표·별 등
비대칭 아이콘은 보통 작은 오프셋이 필요하다. 가능하면 SVG를 고치고, 아니면 픽셀 단위
margin/padding으로 조정한다.

### 그림자와 보더

분리·포커스 링에는 **보더**를, 카드·버튼·드롭다운·팝오버에 깊이가 필요하면 **레이어드 그림자**를
사용한다. 그림자는 투명하고 미묘해서 여러 배경에서 동작해야 한다.

### 텍스트 래핑

- 제목·짧은 타이틀에 `text-wrap: balance`
- 짧은~중간 본문·캡션·설명·리스트 항목에 `text-wrap: pretty`
- 긴 산문·코드·preformatted 콘텐츠에는 둘 다 피한다
- 카운터·타이머·가격·테이블 등 갱신되는 숫자에 `font-variant-numeric: tabular-nums`

### 폰트 스무딩

macOS에서 프로젝트가 이미 처리하지 않았다면 루트 레이아웃에 안티에일리어싱 적용:

```css
html {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}
```

### 이미지 아웃라인

이미지는 가장자리가 표면에 번지지 않도록 미묘한 인셋 아웃라인이 필요할 때가 많다.

```css
img {
    outline: 1px solid rgba(0, 0, 0, 0.1);
    outline-offset: -1px;
}

@media (prefers-color-scheme: dark) {
    img {
        outline-color: rgba(255, 255, 255, 0.1);
    }
}
```

중립적 흑/백 알파 아웃라인을 쓴다. 브랜드 팔레트로 틴트하지 않는다.

### 모션

인터랙티브 상태 변화에는 **CSS transition**을 쓴다 — 사용자가 동작 중 의도를 바꾸면
리타게팅되기 때문. keyframes는 단계적 일회성 등장·로딩 시퀀스에만 사용한다.

좋은 모션 기본값:

- **Enter**: opacity + 작은 `translateY` (+ 선택적 blur) 조합
- **Exit**: enter보다 짧고 조용하게, 보통 150ms
- **Press**: 촉각적 버튼에 `scale(0.96)`, 산만하면 끌 수 있게
- **아이콘 교체**: 즉각 토글 대신 opacity·scale·blur 크로스페이드

### Transition 범위

`transition: all`을 절대 쓰지 않는다. 변하는 속성만 명시:

```css
.button {
    transition-property: transform, background-color, box-shadow;
    transition-duration: 150ms;
    transition-timing-function: ease-out;
}
```

`will-change`는 `transform`·`opacity`·`filter` 같은 컴포지터 친화 속성의 첫 프레임
스터터에만 쓴다. `will-change: all` 금지.

### 히트 영역 (Hit Areas)

인터랙티브 컨트롤은 최소 40×40px, 가능하면 44×44px 히트 영역을 가져야 한다.
보이는 아이콘이 더 작으면 의사 요소(pseudo-element)로 확장하되, 확장된 히트 영역이
서로 겹치지 않게 한다.

## 리뷰 출력

UI 폴리시 패스를 리뷰할 때는 before/after 행으로 구체적 변경을 보고한다:

| 원칙 | Before | After |
| ---- | ------ | ----- |
| 동심 radius | 부모·자식 동일 radius | 부모 radius가 패딩을 반영 |
| Tabular 숫자 | 자릿수 변할 때 카운터 흔들림 | `tabular-nums` 사용 |
| Transition 범위 | `transition: all` | 명시적 transition 속성 |

스니펫만으로 명확하지 않으면 파일 경로·속성을 포함한다. 점검했지만 바꾸지 않은 원칙은 생략한다.

## 체크리스트

- [ ] 중첩된 둥근 요소가 광학적으로 일관적이다
- [ ] 아이콘이 시각적으로 중앙에 있다
- [ ] 버튼·카드·팝오버가 올바른 이유로 보더/그림자를 쓴다
- [ ] 제목·짧은 텍스트의 어색한 래핑을 피한다
- [ ] 동적 숫자가 tabular numeral을 쓴다
- [ ] 이미지에 필요한 곳에 중립 아웃라인이 있다
- [ ] enter·exit 애니메이션이 분리·미묘·중단 가능하다
- [ ] 버튼에 과장 없는 촉각적 active 상태가 있다
- [ ] `transition: all`·`will-change: all`이 없다
- [ ] 작은 컨트롤도 사용 가능한 히트 영역을 갖는다
