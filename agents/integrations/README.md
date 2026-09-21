# Integrations

외부 스킬, MCP, 플러그인과 도구의 설치 정보, 설정 템플릿, health check, 호스트별 차이를 보관합니다. 외부 원본 전체나 실제 인증값은 저장하지 않습니다. 종류별 하위 디렉터리는 실제 연동을 추가할 때 함께 만듭니다.

- 외부 스킬: 설치·호환성·wrapper 연결 정보를 둡니다. 기본 제품 개발 경로는 외부 스킬 체인을 강제하지 않으며, 현재 작업에 특화된 능력이 필요할 때만 gstack, Superpowers와 Matt Pocock skills를 개별 사용합니다. 외부 스킬은 자동으로 다운로드하거나 수정하지 않습니다.
- MCP: 서버의 설치 방법, transport, 필요한 환경 변수 이름, 권한, health check 템플릿을 둡니다.
- 플러그인: Claude, Codex, Gemini 등에서 설치할 외부 플러그인의 출처와 호스트별 연결 정보를 둡니다.
- 도구: 브라우저, CLI와 기타 외부 개발 도구의 설치·검증 정보를 둡니다.

출처와 고정 버전의 원본은 `../registry/skills.toml`과 `../registry/sources.lock`입니다.
