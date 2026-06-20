---
Title: "UI 예시: 대시보드 리스트 before/after"
creation: 2026-06-20
modification: 2026-06-20
tags:
 - "arachne"
 - "ui-ux"
 - "example"
aliases:
 - "dashboard-list-ui-example"
---
MOC:: [[Arachne]]
FROM:: [[../README]]

# UI 예시: 대시보드 리스트 before/after

운영형 대시보드나 관리자 리스트 화면을 개선할 때 참고하는 예시다.

## 사용자

반복적으로 항목을 스캔하고 상태를 비교한 뒤 빠르게 조치를 취하는 운영자.

## Before

- 모든 카드와 버튼의 간격이 16px로 동일해 정보 관계가 보이지 않는다.
- 텍스트, 숫자, 상태 배지가 같은 정렬축을 공유하지 않는다.
- loading 상태에서 행 높이가 변해 스크롤 위치가 흔들린다.
- 빈 상태가 "No data"뿐이라 다음 행동을 알 수 없다.

## After

- 같은 행 내부 요소는 8px, 필드 그룹은 12~16px, 섹션은 24px 이상으로 분리한다.
- 주요 텍스트 열은 좌측 정렬, 숫자·금액·카운터는 우측 정렬한다.
- 행 높이는 loading/loaded/error 상태에서 동일하게 유지한다.
- 빈 상태에는 원인과 1개 주요 액션을 둔다.

## 간격 기준

| 대상 | 값 |
| --- | --- |
| 행 내부 아이콘-텍스트 | 6~8px |
| 셀 padding | 8px 12px |
| 필터와 리스트 사이 | 16px |
| 섹션 사이 | 24~32px |
| 아이콘 버튼 hit area | 40×40px 이상 |

## 정렬 기준

- 첫 번째 텍스트 열을 greedy 열로 둔다.
- 액션 열은 내용 기준 최소 폭으로 둔다.
- 상태 배지는 텍스트 baseline과 시각적으로 맞춘다.
- 카운터는 `font-variant-numeric: tabular-nums`를 사용한다.

## 상태

| 상태 | 기준 |
| --- | --- |
| Loading | skeleton 또는 고정 높이 placeholder |
| Empty | 원인 한 줄 + 주요 액션 하나 |
| Error | 요약 + retry + 상세 로그 위치 |
| Disabled | 비활성 이유를 tooltip 또는 help text로 제공 |

## 검증

- 모바일 폭에서 긴 이름이 버튼을 밀지 않는다.
- 행 hover 시 액션 버튼이 나타나도 행 높이가 변하지 않는다.
- 숫자 자릿수가 바뀌어도 열 폭이 크게 흔들리지 않는다.
