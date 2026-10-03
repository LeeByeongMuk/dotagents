# Tooling

dotagents의 설치·제거(`scripts/install.sh`, `scripts/uninstall.sh`), 호스트 진입점 생성(`scripts/build.sh`), 진단(`scripts/doctor.sh`)과 검증(`scripts/check.sh`, `tests/`) 코드를 보관합니다. 기획 전용 `Plan`과 구현용 `Brief → Execute → Verify`는 별도 상태 엔진을 사용하지 않습니다. `scripts/workflow.sh`는 audited 10단계 실행의 상태·승인·복구를 담당합니다. `evals/product-development/`는 Claude Code와 Codex의 공통 결과 계약·effort·사용량을 비교하고, `evals/commit-message/`는 생성된 진입점을 받은 모델이 쓴 커밋 메시지를 채점합니다. 외부 소스 검사는 `scripts/check-sources.sh`에 있습니다.
