# Tooling

dotagents의 설치·제거(`scripts/install.sh`, `scripts/uninstall.sh`), 호스트 진입점 생성(`scripts/build.sh`), 진단(`scripts/doctor.sh`)과 검증(`scripts/check.sh`, `tests/`) 코드를 보관합니다. 기획 전용 `Plan`과 구현용 `Brief → Execute → Verify`는 별도 상태 엔진을 사용하지 않습니다. `evals/product-development/`는 Claude Code와 Codex의 공통 결과 계약·effort·사용량을 비교하고, `evals/commit-message/`는 생성된 진입점을 받은 모델이 쓴 커밋 메시지를 채점합니다. 외부 소스 검사는 `scripts/check-sources.sh`에 있습니다.

owned 스킬의 설치 대상은 `scripts/lib/owned-skills.sh`의 디렉터리 열거를 전역·프로젝트 설치기와 진단기가 공유합니다. `scripts/check-owned-skills.sh`는 별칭·registry 일관성을 검사하는 빌드 시점 검사이며 설치 런타임에 TOML 파서를 요구하지 않습니다. 추가·제거 절차와 세 원본의 역할은 [스킬 안내](../agents/skills/README.md)를 따릅니다. `tests/owned_skills_test.sh`는 임시 소스·홈·프로젝트에서 동적 추가·제거, 무변경 실패 가드, 설치된 checkout 기준 진단을 검증합니다.

고정 설치 항목은 `scripts/lib/install-layout.sh`에서 설치기와 doctor가 공유합니다. 기본 legacy 모드는 유지하며 전역 `--layout managed`는 공유 namespace와 사용자 설정 소유권을 분리합니다. metadata·seed·이행·복구 계약은 [설치 layout 안내](../docs/designs/install-layouts.md), 임시 경로의 회귀 검증은 `tests/managed_install_test.sh`가 소유합니다.
