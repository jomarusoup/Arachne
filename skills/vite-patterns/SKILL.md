---
name: vite-patterns
description: Vite 설정·운영 패턴 — 개발 프록시(REST·WebSocket ws:true), 환경변수 노출 규칙(VITE_ 접두사는 공개 값만), 모드별 env 파일, 빌드 설정(청크 분할·소스맵·base), Electron 렌더러 빌드(상대 base·main/preload 분리), 번들 분석. 대상 경로 — **/vite.config.*, **/.env*, **/electron.vite.config.*. 키워드 — Vite, 프록시, import.meta.env, VITE_, 번들, Electron 렌더러.
---

# Vite 패턴

웹 클라이언트와 Electron 렌더러를 Vite로 개발·빌드할 때의 설정 기준이다.

## 언제 사용하나

- `vite.config.ts`를 새로 만들거나 프록시·빌드 옵션을 바꿀 때
- 환경변수를 추가하거나 클라이언트에 값을 노출할지 판단할 때
- Electron 렌더러를 Vite로 빌드하거나 `file://` 로드 문제를 고칠 때
- 번들 크기 예산(`rules/web/performance.md`)을 넘었을 때

### 언제 사용하지 않나

- Next.js 프로젝트 → Next 자체 빌드를 쓴다 (`NEXT_PUBLIC_` 규칙은 아래 env 절과 같다)
- Electron 보안 설정(contextIsolation·IPC) → `rules/electron/` (도입 예정)

## 어떻게

### 1. 개발 프록시

개발 서버에서 API를 같은 출처로 프록시하면 CORS 설정 없이 개발할 수 있다.
프록시는 개발 서버에서만 동작한다. 운영 경로 라우팅은 리버스 프록시나 서버가 맡는다.

```typescript
// vite.config.ts
export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd(), "");   // 설정 파일 안에서만 쓰는 비공개 값

    return {
        server: {
            port:       5173,
            strictPort: true,
            proxy: {
                "/api": {
                    target:       env.API_ORIGIN ?? "http://localhost:8080",
                    changeOrigin: true,
                },
                "/stream": {
                    target:       env.STREAM_ORIGIN ?? "ws://localhost:8081",
                    ws:           true,       // WebSocket 업그레이드 전달
                    changeOrigin: true,
                },
            },
        },
    };
});
```

- WebSocket 경로에는 `ws: true`를 반드시 지정한다. 없으면 업그레이드 요청이 실패한다.
- 경로를 바꿔야 하면 `rewrite: (p) => p.replace(/^\/api/, "")`를 쓴다.
- 프록시 대상 주소는 `loadEnv`로 읽은 비공개 값이다. 클라이언트 번들에 들어가지 않는다.
- Vite 개발 서버의 HMR 소켓과 앱 WebSocket 경로가 겹치지 않게 한다.

### 2. 환경변수 노출 규칙

`import.meta.env`로 클라이언트에 노출되는 값은 **`VITE_` 접두사가 붙은 것뿐**이다.
노출된 값은 번들 문자열로 박혀 누구나 볼 수 있다.

| 값 | 접두사 | 예 |
|---|---|---|
| 공개해도 되는 값 | `VITE_` | `VITE_API_BASE=/api`, `VITE_APP_VERSION` |
| 비밀값 (토큰·키·DB 주소) | 접두사 없음, 클라이언트 금지 | `API_SECRET`, `DB_URL` |
| 설정 파일에서만 쓰는 값 | 접두사 없음 + `loadEnv` | `API_ORIGIN` |

- `envPrefix`를 `""`나 넓은 접두사로 바꾸지 않는다. 모든 변수가 번들에 노출된다.
- `define`으로 `process.env` 전체를 주입하지 않는다.
- 비밀이 필요한 호출은 서버(또는 Electron main 프로세스)가 대신 수행한다.
- 타입은 `src/vite-env.d.ts`에 선언해 오타를 컴파일 단계에서 잡는다.

```typescript
// src/vite-env.d.ts
interface ImportMetaEnv {
    readonly VITE_API_BASE:    string;
    readonly VITE_APP_VERSION: string;
}
interface ImportMeta {
    readonly env: ImportMetaEnv;
}
```

env 파일 우선순위 (뒤가 이긴다): `.env` → `.env.local` → `.env.[mode]` → `.env.[mode].local`.
`*.local` 파일은 커밋하지 않는다. 저장소에는 값이 빈 `.env.example`만 둔다.

### 3. 빌드 설정

```typescript
export default defineConfig({
    build: {
        target:          "es2022",
        sourcemap:       "hidden",     // 오류 추적용 생성, 번들에서 참조하지 않음
        chunkSizeWarningLimit: 500,
        rollupOptions: {
            output: {
                manualChunks: {
                    react:  ["react", "react-dom"],
                    charts: ["lightweight-charts"],
                },
            },
        },
    },
});
```

- 공개 웹에 `sourcemap: true`를 배포하지 않는다. 원본 소스가 노출된다. `hidden`으로 만들어 오류 수집 서비스에만 올린다.
- 무거운 화면은 `import()` 동적 임포트로 분리한다. `manualChunks`는 자주 바뀌지 않는 라이브러리 묶음에만 쓴다.
- 하위 경로에 배포하면 `base: "/app/"`를 지정한다.
- Web Worker는 `new Worker(new URL("./decoder.worker.ts", import.meta.url), { type: "module" })` 형태로 만든다. Vite가 별도 청크로 빌드한다.

### 4. Electron 렌더러 빌드

Electron은 main·preload·renderer 세 진입점을 각각 빌드한다.
`electron-vite` 같은 통합 도구를 쓰거나, renderer만 Vite로 빌드하고 main·preload는 별도 설정을 둔다.

| 진입점 | 빌드 대상 | 주의 |
|---|---|---|
| main | Node (CJS 또는 ESM) | `electron`·Node 내장 모듈은 external |
| preload | Node + 샌드박스 제약 | 최소 API만 `contextBridge`로 노출 |
| renderer | 브라우저 | Node API 직접 사용 금지 |

renderer 설정 포인트:

```typescript
// renderer용 vite.config.ts
export default defineConfig({
    base: "./",                         // file:// 로드 시 자산 경로를 상대로
    build: {
        outDir:      "dist/renderer",
        emptyOutDir: true,
        target:      "chrome120",       // 탑재된 Electron의 Chromium 버전에 맞춘다
    },
});
```

- `base: "./"`가 없으면 패키징 후 `file://`에서 자산을 찾지 못해 흰 화면이 된다.
- 개발 중에는 main이 `VITE_DEV_SERVER_URL`을 로드하고, 패키징 후에는 `loadFile`로 빌드 산출물을 로드한다.
- renderer 번들에 `fs`·`child_process`가 들어가면 설계 오류다. 그 기능은 main으로 옮기고 IPC로 호출한다.
- 바이너리 스트림 수신·디코딩은 main 또는 Worker에서 한다. renderer 메인 스레드에서 하지 않는다.

### 5. 번들 분석

```bash
npx vite build --mode production
npx vite-bundle-visualizer             # 청크 구성 트리맵
```

예산 초과 시 순서: 중복 의존성 제거 → 배럴 임포트 정리 → 동적 임포트 분리 → 의존성 교체.

## 예시 — 개발·운영 경로를 같은 코드로

```typescript
// src/api/base.ts
export const API_BASE: string = import.meta.env.VITE_API_BASE;   // 개발·운영 모두 "/api"

// 개발: Vite 프록시가 /api → http://localhost:8080
// 운영: 리버스 프록시가 /api → 백엔드
// 코드는 출처를 몰라도 된다.
```

## 흔한 문제

| 증상 | 원인 | 해결 |
|---|---|---|
| `import.meta.env.X`가 `undefined` | `VITE_` 접두사 없음 | 공개 값이면 접두사 추가, 비밀이면 서버로 이동 |
| WebSocket 연결 실패(개발) | 프록시에 `ws: true` 없음 | 해당 경로에 `ws: true` 추가 |
| Electron 패키징 후 흰 화면 | 절대 경로 자산 | renderer `base: "./"` |
| `Buffer is not defined` | Node 전용 패키지를 renderer에서 임포트 | `DataView`·`TextDecoder` 같은 웹 API로 대체 |
| 운영 빌드만 실패 | 개발 서버는 타입 검사를 하지 않음 | 빌드 전 `tsc --noEmit` 실행 |
