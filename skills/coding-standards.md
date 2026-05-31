---
name: coding-standards
description: 프로젝트 공통 코딩 컨벤션 — 네이밍, 가독성, 불변성, 코드 품질 검토. 프레임워크별 세부사항은 frontend-patterns 또는 backend-patterns 스킬 사용.
origin: ECC
---

# 코딩 표준 및 모범 사례

프로젝트 전반에 적용되는 기준 코딩 컨벤션.

이 스킬은 공통 기반이지, 세부 프레임워크 플레이북이 아니다.

- React·상태·폼·렌더링·UI 아키텍처 → `frontend-patterns`
- 레포지토리/서비스 레이어·엔드포인트 설계·검증 → `backend-patterns` 또는 `api-design`
- 가장 짧은 재사용 가능한 규칙 레이어가 필요할 때 → `rules/common/coding-style.md`

## 언제 활성화하나

- 새 프로젝트 또는 모듈 시작
- 품질·유지보수성 코드 리뷰
- 컨벤션 따르도록 기존 코드 리팩터링
- 네이밍·포매팅·구조적 일관성 강제
- 린팅·포매팅·타입 체킹 설정
- 새 기여자 온보딩

## 범위 경계

이 스킬 활성화 대상:
- 설명적 네이밍
- 불변성 기본값
- 가독성, KISS, DRY, YAGNI 강제
- 에러 처리 기대치 및 코드 스멜 리뷰

이 스킬을 주요 소스로 사용하지 않을 것:
- React 컴포지션, 훅, 렌더링 패턴
- 백엔드 아키텍처, API 설계, DB 레이어링
- 더 좁은 스킬이 있는 도메인별 프레임워크 가이드

## 코드 품질 원칙

### 1. 가독성 우선

- 코드는 쓰는 것보다 읽히는 횟수가 더 많음
- 명확한 변수·함수 이름
- 주석보다 자기 문서화 코드 선호
- 일관된 포매팅

### 2. KISS (단순하게 유지)

- 작동하는 가장 단순한 해결책
- 과도한 엔지니어링 금지
- 조기 최적화 금지
- 영리한 코드 < 이해하기 쉬운 코드

### 3. DRY (반복하지 않기)

- 공통 로직을 함수로 추출
- 재사용 가능한 컴포넌트 생성
- 모듈 간 유틸리티 공유
- 복사-붙여넣기 프로그래밍 금지

### 4. YAGNI (필요할 때만 만들기)

- 필요하기 전에 기능 만들지 않기
- 투기적 일반화 금지
- 필요할 때만 복잡성 추가
- 단순하게 시작, 필요시 리팩터링

## TypeScript/JavaScript 표준

### 변수 네이밍

```typescript
/* 올바름: 설명적인 이름 */
const marketSearchQuery = 'election'
const isUserAuthenticated = true
const totalRevenue = 1000

/* 잘못됨: 불명확한 이름 */
const q = 'election'
const flag = true
const x = 1000
```

### 함수 네이밍

```typescript
/* 올바름: 동사-명사 패턴 */
async function fetchMarketData(marketId: string) { }
function calculateSimilarity(a: number[], b: number[]) { }
function isValidEmail(email: string): boolean { }

/* 잘못됨: 불명확하거나 명사만 */
async function market(id: string) { }
function similarity(a, b) { }
```

### 불변성 패턴 (중요)

```typescript
/* 올바름: spread 연산자 사용 */
const updatedUser = { ...user, name: 'New Name' }
const updatedArray = [...items, newItem]

/* 잘못됨: 직접 변이 */
user.name = 'New Name'  // 금지
items.push(newItem)     // 금지
```

### 에러 처리

```typescript
/* 올바름: 포괄적 에러 처리 */
async function fetchData(url: string) {
    try {
        const response = await fetch(url)
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`)
        }
        return await response.json()
    } catch (error) {
        console.error('Fetch 실패:', error)
        throw new Error('데이터 가져오기 실패')
    }
}

/* 잘못됨: 에러 처리 없음 */
async function fetchData(url) {
    const response = await fetch(url)
    return response.json()
}
```

### 비동기/await 모범 사례

```typescript
/* 올바름: 가능한 경우 병렬 실행 */
const [users, markets, stats] = await Promise.all([
    fetchUsers(),
    fetchMarkets(),
    fetchStats()
])

/* 잘못됨: 불필요하게 순차 실행 */
const users = await fetchUsers()
const markets = await fetchMarkets()
const stats = await fetchStats()
```

### 타입 안전성

```typescript
/* 올바름: 적절한 타입 */
interface Market {
    id: string
    name: string
    status: 'active' | 'resolved' | 'closed'
}

function getMarket(id: string): Promise<Market> { }

/* 잘못됨: any 사용 */
function getMarket(id: any): Promise<any> { }
```

## API 설계 표준

```
GET    /api/markets          # 전체 목록
GET    /api/markets/:id      # 특정 항목 조회
POST   /api/markets          # 생성
PUT    /api/markets/:id      # 전체 업데이트
PATCH  /api/markets/:id      # 부분 업데이트
DELETE /api/markets/:id      # 삭제
```

### 응답 형식

```typescript
/* 올바름: 일관된 응답 구조 */
interface ApiResponse<T> {
    success: boolean
    data?: T
    error?: string
    meta?: { total: number; page: number; limit: number }
}
```

## 파일 구성

```
src/
├── components/     # React 컴포넌트
├── hooks/          # 커스텀 React 훅
├── lib/            # 유틸리티 및 설정
│   ├── api/       # API 클라이언트
│   └── utils/     # 헬퍼 함수
└── types/          # TypeScript 타입
```

## 주석 가이드

```typescript
/* 올바름: '왜'를 설명 */
// API 과부하 방지를 위해 지수 백오프 사용
const delay = Math.min(1000 * Math.pow(2, retryCount), 30000)

/* 잘못됨: 자명한 내용 설명 */
// 카운터를 1씩 증가
count++
```

## 코드 스멜 감지

### 1. 긴 함수

```typescript
/* 잘못됨: 50줄 초과 함수 */
function processMarketData() { /* 100줄 */ }

/* 올바름: 작은 함수로 분리 */
function processMarketData() {
    const validated = validateData()
    const transformed = transformData(validated)
    return saveData(transformed)
}
```

### 2. 깊은 중첩

```typescript
/* 잘못됨: 5단계 이상 중첩 */
if (user) { if (user.isAdmin) { if (market) { /* ... */ } } }

/* 올바름: 조기 반환 */
if (!user) return
if (!user.isAdmin) return
if (!market) return
// 실제 로직
```

### 3. 매직 넘버

```typescript
/* 잘못됨: 설명 없는 숫자 */
if (retryCount > 3) { }

/* 올바름: 명명된 상수 */
const MAX_RETRIES = 3
if (retryCount > MAX_RETRIES) { }
```

---

**기억**: 코드 품질은 협상의 여지가 없다. 명확하고 유지 가능한 코드가 빠른 개발과 자신감 있는 리팩터링을 가능하게 한다.
