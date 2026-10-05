---
paths:
  - "**/*.html"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.vue"
---
# 웹 보안 (브라우저 경계)

> [common/security.md](../common/security.md)와 [javascript/security.md](../javascript/security.md)를
> 브라우저 쪽으로 확장한다. XSS를 막는 마지막 방어선은 응답 헤더다.

## CSP — nonce 기반

콘텐츠 보안 정책(Content Security Policy, CSP)은 도메인 허용 목록 대신 **요청마다 새로 만든
nonce**로 스크립트를 허용한다. 도메인 허용 목록은 그 도메인에 올라간 아무 스크립트나 실행되게 둔다.

```
Content-Security-Policy:
  default-src 'self';
  script-src 'nonce-{요청별 난수}' 'strict-dynamic';
  object-src 'none';
  base-uri 'none';
  frame-ancestors 'none';
  form-action 'self'
```

- nonce는 요청마다 암호학적 난수(128비트 이상)로 만든다. 고정값이나 빌드 시점 값은 CSP를 무력화한다.
- `'unsafe-inline'`과 `'unsafe-eval'`은 쓰지 않는다. 인라인 이벤트 속성(`onclick="..."`)도 함께 없앤다.
- 처음 도입할 때는 `Content-Security-Policy-Report-Only`로 위반 보고를 받아 본 뒤 강제로 바꾼다.
- Next.js처럼 SSR(서버 사이드 렌더링)을 쓰면 미들웨어에서 nonce를 만들고 같은 값을 헤더와
  `<script nonce>`에 넣는다. nonce를 쓰는 페이지는 정적 캐시하지 않는다.

## 보안 헤더

| 헤더 | 권장값 | 막는 것 |
|---|---|---|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | HTTPS 다운그레이드 |
| `X-Content-Type-Options` | `nosniff` | MIME 추측으로 인한 스크립트 실행 |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | URL 경로·쿼리의 외부 유출 |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | 쓰지 않는 브라우저 기능 남용 |
| CSP `frame-ancestors` | `'none'` 또는 `'self'` | 클릭재킹 (`X-Frame-Options`는 구형 브라우저 보조용) |

- HSTS(HTTP Strict Transport Security)는 모든 하위 도메인이 HTTPS인지 확인한 뒤 `includeSubDomains`를 켠다.
  `preload`는 되돌리기 어려우므로 운영 도메인이 안정된 뒤에만 신청한다.
- 헤더는 앱 코드 한 곳(미들웨어)이나 리버스 프록시 한 곳에서만 붙인다. 두 곳에서 붙이면 값이 어긋난다.
- 쿠키는 `Secure; HttpOnly; SameSite=Lax` 이상으로 둔다. 세션 쿠키를 JS에서 읽을 이유는 없다.

## SRI와 서드파티 스크립트 통제

외부 CDN에서 불러오는 스크립트·스타일에는 하위 리소스 무결성(Subresource Integrity, SRI) 해시를 붙인다.
CDN이 변조되면 해시가 맞지 않아 브라우저가 실행을 거부한다.

```html
<script src="https://cdn.jsdelivr.net/npm/lib@1.2.3/dist/lib.min.js"
        integrity="sha384-{빌드 시 계산한 해시}"
        crossorigin="anonymous"></script>
```

- 버전을 고정한다(`@1.2.3`). `@latest`처럼 움직이는 URL에는 SRI를 걸 수 없다.
- 해시는 `openssl dgst -sha384 -binary lib.min.js | openssl base64 -A`로 계산한다.
- 가능하면 서드파티 스크립트를 번들에 포함해 자체 출처에서 서빙한다. 외부 출처가 줄면 CSP도 단순해진다.
- 분석·광고·채팅 위젯 같은 태그는 추가 전에 목적·수집 데이터·출처를 기록하고 승인받는다.
  이런 스크립트는 페이지의 모든 DOM과 입력값을 읽을 수 있다.
- 결제·로그인·개인정보 입력 화면에는 서드파티 스크립트를 싣지 않는다.
- 외부 링크를 새 탭으로 열 때는 `rel="noopener noreferrer"`를 붙인다.

## 점검

```bash
# 응답 헤더 확인
curl -sI https://example.com | grep -iE 'content-security|strict-transport|x-content-type|referrer|permissions'

# SRI 누락 확인: integrity 없는 외부 스크립트
grep -rnE '<script[^>]+src="https?://' --include='*.html' . | grep -v 'integrity='
```

민감정보를 브라우저에 저장하는 기준은 `skills/sensitive-data-handling/SKILL.md`를 따른다.
