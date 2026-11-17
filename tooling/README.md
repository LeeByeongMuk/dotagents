# Tooling

프로젝트 로컬 지침·컨텍스트·검증 근거는 `scripts/project.sh inspect|doctor <project>`로 읽기 전용 점검합니다. `scripts/project.sh init <project>`는 템플릿 추가를 미리 보고, `--apply`를 붙일 때만 기존 파일을 보존하며 로컬 파일을 추가합니다. 사용법과 점검의 한계는 [프로젝트 준비 안내](../docs/project-readiness.md)를 참고하세요.

dotagents의 설치·제거(`scripts/install.sh`, `scripts/uninstall.sh`), 호스트 진입점 생성(`scripts/build.sh`), 진단(`scripts/doctor.sh`)과 검증(`scripts/check.sh`, `tests/`) 코드를 보관합니다. 기획 전용 `Plan`과 구현용 `Brief → Execute → Verify`는 별도 상태 엔진을 사용하지 않습니다. `evals/product-development/`는 Claude Code와 Codex의 공통 결과 계약·effort·사용량을 비교하고, `evals/commit-message/`는 생성된 진입점을 받은 모델이 쓴 커밋 메시지를 채점합니다. 외부 소스 검사는 `scripts/check-sources.sh`에 있습니다.
