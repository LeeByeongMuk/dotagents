# Registry

기계가 읽을 수 있는 내부·외부 자산 목록과 잠금 정보를 TOML로 관리합니다. `skills.toml`과 `sources.lock`에는 제품 개발 워크플로우와 선택 공급자의 검토 출처가 등록되어 있습니다. `skills.toml`의 `workflows` 필드는 워크플로우 자체를 가리키는 `product-development`와 lean 검증 후보를 뜻하는 `product-development:verify` 토큰을 사용하며, 워크플로우에 연결되지 않은 외부 스킬은 빈 목록입니다. `tooling/scripts/check-sources.sh`는 GitHub API로 각 잠금 커밋의 소스 상대 경로를 검증합니다. 현재 설치기는 [스킬 안내](../skills/README.md)의 owned 디렉터리 규칙으로 대상을 선택하며 이 레지스트리를 설치 입력으로 사용하거나 외부 자산을 자동 다운로드하지 않습니다. `optional`·`enabled_by_default`·`profiles`도 owned 설치 선택 정책이 아닙니다. owned 항목의 ID·원본 경로는 모든 실제 원본 디렉터리와 일치해야 하며 `make check`가 누락·중복·불일치를 검사합니다. 실제 설치·백업 내역은 별도의 설치 매니페스트가 소유합니다.

향후 항목은 공통적으로 안정적인 ID, 출처, 버전 또는 커밋, 라이선스, 지원 호스트, 적용 프로필, 기본 활성화 여부를 명시합니다. 비밀 값 대신 필요한 환경 변수 이름만 기록합니다.

## 선택적 외부 스킬 관리

`tooling/scripts/external-skills.sh`는 외부 항목 하나·호스트 하나·명시한 목적지에 한정해 잠금 커밋을 연결합니다. 기본은 fetch·쓰기 없는 미리보기이며 `--apply`에서만 변경합니다. 설치 기록과 파일 해시는 명시한 별도 상태 디렉터리가 소유하며 이 TOML 목록과 구분합니다. 기존 전역·프로젝트 설치기는 외부 항목을 다운로드하지 않습니다. 요구 도구와 사용법, legacy `.agents` 링크의 제한, 보조 자산·플러그인 경계는 [외부 스킬 관리 안내](../../docs/external-skills.md)를 참고하세요.
