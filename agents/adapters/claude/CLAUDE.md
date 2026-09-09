# Personal defaults for Claude Code

프로젝트의 `CLAUDE.md`, `AGENTS.md`, 로컬 규칙이 이 개인 기본값보다 우선한다.

공통 규칙 원본은 전역 설치 시 `~/.agents/rules/`, 프로젝트 설치 시 `.agents/rules/`에 있고 재사용 스킬 원본은 같은 기준의 `skills/`에 있다. 호스트가 이 파일 밖의 문서를 자동으로 읽지 않으므로, 작업 종류에 맞는 규칙 문서를 직접 읽어야 적용된다. 커밋 메시지 기본 규칙은 `rules/git.md`이며 Claude Code에서는 훅이 같은 규칙을 검사한다.

Claude 전용 설정은 `settings.json`에서 관리한다. 이 파일은 전역 설치 시 저장소의 `adapters/claude/settings.json`으로 링크되어 변경 이력이 저장소에 남으므로 비밀 값을 넣지 않는다. 이 파일에는 공통 규칙 본문을 복제하지 않는다.
