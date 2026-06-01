# MCP 서버 설정 템플릿

이 디렉토리에는 Claude Code에 추가 MCP 서버를 연결할 때 사용하는 설정 템플릿이 있습니다.

> 공식 플러그인(github, chrome-devtools, figma 등)은 `settings.template.json`의  
> `enabledPlugins`로 관리합니다. 여기서는 커스텀·커뮤니티 MCP를 다룹니다.

---

## 적용 방법

### 1. 글로벌 설정에 추가 (`~/.claude/settings.json`)

```bash
claude mcp add <name> -- <command> [args...]
```

또는 `settings.json`의 `mcpServers` 키에 직접 병합:

```json
{
  "mcpServers": {
    ...여기에 추가...
  }
}
```

### 2. 프로젝트별 설정 (`.claude/settings.json`)

프로젝트 루트의 `.claude/settings.json`에 동일 형식으로 추가하면  
해당 프로젝트에서만 활성화됩니다.

---

## 템플릿 목록

### `github.json`

`@modelcontextprotocol/server-github` 커스텀 설치용.  
공식 플러그인이 아닌 자체 GitHub PAT로 연결할 때 사용.

**플레이스홀더:**
- `__GITHUB_TOKEN__` → GitHub Personal Access Token

```bash
# 적용 예시
claude mcp add github -- npx -y @modelcontextprotocol/server-github
# 환경변수로 토큰 전달
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."
```

### `filesystem.json`

로컬 파일시스템 접근 MCP.  
Claude가 지정된 디렉토리의 파일을 직접 읽고 쓸 수 있게 합니다.

**플레이스홀더:**
- `__HOME__` → 실제 홈 디렉토리 경로 (install.sh가 자동 치환)
- 허용 경로 목록은 필요에 따라 추가/제거

```bash
# 적용 예시
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem ~/projects
```

---

## 새 템플릿 추가 방법

1. `mcp-configs/<name>.json` 파일 생성
2. `__HOME__` 플레이스홀더 사용 (install.sh가 치환)
3. 이 README에 항목 추가
