# Personal defaults for Claude Code

프로젝트의 `CLAUDE.md`, `AGENTS.md`, 로컬 규칙이 이 개인 기본값보다 우선한다.

공통 규칙 본문은 이 파일 아래에 함께 실려 있으므로 따로 읽지 않아도 적용된다. 원본은 전역 설치 시 `~/.agents/rules/`, 프로젝트 설치 시 `.agents/rules/`에 있고 규칙을 고칠 때는 그 원본을 고친다. 커밋 메시지 기본 규칙은 `rules/git.md`이며 Claude Code에서는 훅이 같은 규칙을 검사한다.

Claude 사용자 설정 경로는 `~/.claude/settings.json`이다. `legacy` 전역 설치는 이 경로를 저장소의 `agents/adapters/claude/settings.json`에 링크한다. `managed` 전역 설치는 기존 일반 파일을 보존하고, 파일이 없을 때만 최소 커밋 메시지 훅 설정을 사용자 소유 일반 파일로 만든다. 저장소에서 추적하는 설정에는 비밀 값을 넣지 않는다.
