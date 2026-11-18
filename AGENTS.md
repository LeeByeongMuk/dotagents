# dotagents repository guide

이 저장소의 공통 규칙 원본은 `agents/rules/`이며 재사용 가능한 스킬의 원본은 `agents/skills/`다.

작업 시 다음 우선순위를 지킨다.

1. 사용자의 현재 요청과 이 저장소의 프로젝트 규칙
2. 도구별 어댑터 규칙
3. `agents/rules/`의 개인 공통 규칙

전역 설치는 이 저장소의 주 체크아웃을 라이브 원본으로 사용한다. 링크된 `agents/`의 스킬과 훅은 원본 변경이 즉시 적용된다. 규칙·어댑터 변경을 호스트 진입점에 반영하려면 `make build`로 `dist/`를 다시 만든다. 참고 저장소나 홈 설정은 명시적으로 요청받지 않는 한 수정하지 않는다. [전역 설치 레이아웃과 소유권](docs/designs/install-layouts.md)

주 체크아웃은 main에 둔다. 브랜치 작업은 `git worktree add`로 만든 별도 worktree에서 한다. 주 체크아웃에서 브랜치를 바꾸면 그동안 모든 세션의 전역 설정이 그 브랜치 내용으로 바뀐다.

변경 후 `make check`를 실행한다. `tooling/tests/`의 모든 테스트가 여기에 포함된다.
