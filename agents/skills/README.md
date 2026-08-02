# Skills

직접 만든 스킬은 `owned/<name>/SKILL.md`, 외부 스킬을 보정하는 로컬 wrapper는 `wrappers/<name>/SKILL.md`에 둡니다.

각 스킬은 입력, 출력, 실행 조건, 실패 조건과 부작용을 명시합니다. 특정 프로젝트 경로, 비밀, 조직 내부 정보나 불필요하게 고정된 도구 버전을 포함하지 않습니다. 외부 원본과 버전은 `../registry/skills.toml`과 `../registry/sources.lock`에서 관리합니다.
