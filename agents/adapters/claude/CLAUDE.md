# Personal defaults for Claude Code

프로젝트의 `CLAUDE.md`, `AGENTS.md`, 로컬 규칙이 이 개인 기본값보다 우선한다.

공통 규칙 본문은 이 파일 아래에 함께 실려 있으므로 따로 읽지 않아도 적용된다. 원본은 전역 설치 시 `~/.agents/rules/`, 프로젝트 설치 시 `.agents/rules/`에 있고 규칙을 고칠 때는 그 원본을 고친다. 재사용 스킬 원본은 같은 기준의 `skills/`에 있으며 호스트가 자동으로 읽지 않으므로 필요할 때 직접 읽는다. 커밋 메시지 기본 규칙은 `rules/git.md`이며 Claude Code에서는 훅이 같은 규칙을 검사한다.

Claude 전용 설정은 `settings.json`에서 관리한다. 이 파일은 전역 설치 시 저장소의 `adapters/claude/settings.json`으로 링크되어 변경 이력이 저장소에 남으므로 비밀 값을 넣지 않는다. 이 파일에는 공통 규칙 본문을 복제하지 않는다.
