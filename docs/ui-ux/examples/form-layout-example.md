---
Title: "UI 예시: 폼 레이아웃"
creation: 2026-06-20
modification: 2026-06-20
tags:
 - "arachne"
 - "ui-ux"
 - "example"
aliases:
 - "form-layout-ui-example"
---
MOC:: [[Arachne]]
FROM:: [[../README]]

# UI 예시: 폼 레이아웃

설정 화면, 생성/수정 화면, 온보딩 입력 화면을 만들 때 참고한다.

## 사용자

실수 없이 값을 입력하고 저장 결과를 확인해야 하는 사용자.

## 레이아웃 기준

- label, input, help text의 좌측 축을 맞춘다.
- 한 필드 내부 label-input-help 간격은 6~8px로 유지한다.
- 필드와 필드 사이는 16px을 기본으로 한다.
- 섹션과 섹션 사이는 24~32px로 분리한다.
- primary action은 폼 흐름의 끝에 두고, destructive action은 시각적으로 분리한다.

## 너비 기준

| 입력 유형 | 권장 너비 |
| --- | --- |
| 이름, 제목 | 360~520px |
| 이메일, URL | 420~640px |
| 짧은 숫자 | 120~180px |
| 긴 설명 | 100%, max-width 720px |

## 상태 기준

- Error text는 input 바로 아래에 둔다.
- Help text와 error text가 동시에 필요한 경우 error를 우선한다.
- 저장 중에도 폼 전체 레이아웃은 유지한다.
- 성공 메시지는 다음 행동을 방해하지 않게 배치한다.

## 검증

- 긴 label과 긴 오류 메시지가 모바일에서 줄바꿈된다.
- 키보드 focus 순서가 시각 순서와 같다.
- required/optional 정보가 일관되다.
