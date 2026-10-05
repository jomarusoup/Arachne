---
paths:
  - "**/main/**"
  - "**/preload/**"
  - "**/electron*.ts"
  - "**/electron*.js"
  - "**/electron.vite.config.*"
---
# Electron 보안

> [javascript/security.md](../javascript/security.md)와 [web/security.md](../web/security.md)를
> Electron 프로세스 경계로 확장한다. renderer는 웹 페이지와 같은 신뢰 수준으로 본다.

## 창 기본값 — 셋 다 명시한다

renderer가 뚫려도 OS에 닿지 못하게 막는 것이 목표다. 기본값에 기대지 않고 매번 적는다.

```typescript
const win = new BrowserWindow({
    webPreferences: {
        contextIsolation: true,    // preload와 페이지의 JS 세계를 분리한다
        sandbox:          true,    // renderer·preload를 OS 샌드박스에 가둔다
        nodeIntegration:  false,   // 페이지에서 require·process를 쓰지 못한다
        webSecurity:      true,    // 동일 출처 정책을 끄지 않는다
        preload:          path.join(__dirname, "preload.js"),
    },
});
```

- `nodeIntegrationInWorker`·`nodeIntegrationInSubFrames`·`allowRunningInsecureContent`·`experimentalFeatures`는 켜지 않는다.
- `<webview>`는 쓰지 않는다. 꼭 필요하면 `will-attach-webview`에서 설정을 강제로 덮어쓴다.

## preload — 기능 단위 최소 API

- `contextBridge.exposeInMainWorld`로 **동작 하나에 함수 하나**만 노출한다.
- `ipcRenderer` 자체나 `send(channel, ...)`처럼 채널을 인자로 받는 범용 함수를 노출하지 않는다.
- 노출 함수는 인자를 그대로 넘기지 않는다. 타입과 범위를 검사한 값만 보낸다.

```typescript
// BAD: renderer가 아무 채널이나 부를 수 있다
contextBridge.exposeInMainWorld("api", { send: ipcRenderer.send });

// GOOD: 동작마다 고정 채널
contextBridge.exposeInMainWorld("api", {
    SubmitAction: (req: ActionRequest) => ipcRenderer.invoke("action:submit", req),
});
```

## IPC — 채널 허용 목록과 보낸 쪽 검증

- main은 허용 목록에 있는 채널만 `ipcMain.handle`로 등록한다. 목록은 코드 한 곳에 둔다.
- 핸들러 첫 줄에서 `event.senderFrame`의 출처(origin)를 확인한다. 앱 자신의 출처가 아니면 거부한다.
- 인자는 스키마(zod 등)로 검증한다. renderer가 보낸 값은 외부 입력이다.
- 파일 경로·명령 문자열을 renderer에서 받지 않는다. 받아야 하면 허용 목록이나 ID로 바꾼다.

```typescript
function IsTrustedSender(frame: WebFrameMain | null): boolean {
    return frame !== null && new URL(frame.url).protocol === "app:";   // 앱 전용 프로토콜 기준
}
ipcMain.handle("action:submit", (event, raw: unknown) => {
    if (!IsTrustedSender(event.senderFrame)) throw new Error("허용되지 않은 보낸 쪽");
    return SubmitAction(ActionRequestSchema.parse(raw));
});
```

## renderer CSP

- renderer HTML에 `default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'none'`을 둔다.
- `'unsafe-eval'`·`'unsafe-inline'`은 쓰지 않는다. 개발 서버의 HMR 예외는 개발 빌드에만 둔다.
- 앱 콘텐츠는 `file://` 대신 `protocol.handle`로 등록한 앱 전용 프로토콜로 내보내는 편이 출처 검증이 쉽다.

## 네비게이션과 새 창 차단

```typescript
app.on("web-contents-created", (_e, contents) => {
    contents.on("will-navigate", (event) => event.preventDefault());
    contents.setWindowOpenHandler(({ url }) => {
        if (IsAllowedExternal(url)) shell.openExternal(url);   // https와 허용 호스트만
        return { action: "deny" };
    });
});
```

- `shell.openExternal`에는 검증한 `https:` URL만 넘긴다. `file:`·사용자 지정 스킴은 명령 실행 경로가 된다.
- 권한 요청(`session.setPermissionRequestHandler`)은 기본 거부로 두고 필요한 권한만 허용한다.

## 원격 콘텐츠

- 권한 있는 창(preload가 붙은 창)에는 원격 URL을 로드하지 않는다. 앱 번들의 로컬 콘텐츠만 로드한다.
- 외부 페이지를 보여야 하면 preload 없는 별도 창 또는 시스템 브라우저로 연다.
- 서버 데이터는 IPC·소켓으로 받은 값으로만 화면에 넣는다. HTML로 렌더하지 않는다.

## 퓨즈·업데이트·비밀값

- 패키징 시 `@electron/fuses`로 `RunAsNode`·`EnableNodeOptionsEnvironmentVariable`·`EnableNodeCliInspectArguments`를 끈다.
  `EnableEmbeddedAsarIntegrityValidation`·`OnlyLoadAppFromAsar`는 켠다.
- 자동 업데이트는 HTTPS와 코드 서명 검증을 거친 패키지만 적용한다. 서명 검증을 끄는 옵션은 쓰지 않는다.
- 토큰·비밀번호는 `safeStorage`로 암호화해 앱 데이터 경로에 둔다. 암호화가 불가하면 저장을 거부한다
  (기준: `skills/sensitive-data-handling/SKILL.md`). renderer `localStorage`에는 두지 않는다.
- Electron은 지원 중인 최신 주 버전을 유지한다. Chromium 보안 패치가 버전 업데이트로만 들어온다.
