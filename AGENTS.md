# dotagents repository guide

이 저장소의 공통 규칙 원본은 `agents/rules/`이며 재사용 가능한 스킬의 원본은 `agents/skills/`다.

작업 시 다음 우선순위를 지킨다.

1. 사용자의 현재 요청과 이 저장소의 프로젝트 규칙
2. 도구별 어댑터 규칙
3. `agents/rules/`의 개인 공통 규칙

`agents/`는 홈 디렉터리에 심볼릭 링크로 연결되어 있어 main에서의 편집이 즉시 전역에 적용된다. 참고 저장소나 홈 설정은 명시적으로 요청받지 않는 한 수정하지 않는다. 변경 후 `./tooling/scripts/check.sh`와 `make test`를 실행한다.
