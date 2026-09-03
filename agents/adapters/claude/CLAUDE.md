# Personal defaults for Claude Code

프로젝트의 `CLAUDE.md`, `AGENTS.md`, 로컬 규칙이 이 개인 기본값보다 우선한다.

공통 규칙 원본은 전역 설치 시 `~/.agents/rules/`, 프로젝트 설치 시 `.agents/rules/`에 있다. 작업 전에 해당 디렉터리의 관련 문서를 읽는다. 재사용 스킬 원본은 같은 기준의 `skills/`에 있다.

커밋 메시지는 프로젝트에 커밋 규칙이 있으면 그것을 따르고, 없으면 같은 기준의 `rules/git.md`에 있는 기본 규칙을 따른다. 커밋 전에 이 문서를 읽는다.

Claude 전용 설정은 `settings.json`에서 관리한다. 이 파일은 전역 설치 시 저장소의 `adapters/claude/settings.json`으로 링크되어 변경 이력이 저장소에 남으므로 비밀 값을 넣지 않는다. 이 파일에는 공통 규칙 본문을 복제하지 않는다.
