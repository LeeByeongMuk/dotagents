# dotagents repository guide

이 저장소의 공통 규칙 원본은 `agents/rules/`이며 재사용 가능한 스킬의 원본은 `agents/skills/`다.

작업 시 다음 우선순위를 지킨다.

1. 사용자의 현재 요청과 이 저장소의 프로젝트 규칙
2. 도구별 어댑터 규칙
3. `agents/rules/`의 개인 공통 규칙

홈 디렉터리의 전역 설정은 이 저장소의 주 체크아웃(`~/.agents`가 가리키는 곳)으로 링크되어 있다. 주 체크아웃에서 `agents/`의 스킬, 훅, Claude `settings.json`을 고치면 즉시 전역에 적용되고, 규칙과 어댑터는 `make build`로 `dist/`를 다시 만들어야 적용된다. 참고 저장소나 홈 설정은 명시적으로 요청받지 않는 한 수정하지 않는다.

주 체크아웃은 main에 둔다. 브랜치 작업은 `git worktree add`로 만든 별도 worktree에서 한다. 주 체크아웃에서 브랜치를 바꾸면 그동안 모든 세션의 전역 설정이 그 브랜치 내용으로 바뀐다.

변경 후 `make check`를 실행한다. `tooling/tests/`의 모든 테스트가 여기에 포함된다.
