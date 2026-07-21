# dotagents repository guide

이 저장소의 공통 규칙 원본은 `agents/rules/`이며 재사용 가능한 스킬과 프롬프트의 원본은 각각 `agents/skills/`, `agents/prompts/`다.

작업 시 다음 우선순위를 지킨다.

1. 사용자의 현재 요청과 이 저장소의 프로젝트 규칙
2. 도구별 어댑터 규칙
3. `agents/rules/`의 개인 공통 규칙

참고 저장소나 홈 설정은 명시적으로 요청받지 않는 한 수정하지 않는다. 비밀 값은 읽거나 출력하거나 복사하지 않는다. 변경 후 `./scripts/check.sh`와 관련 테스트를 실행한다.
