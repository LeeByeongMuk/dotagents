# Tooling

dotagents의 설치, 제거, 생성, 갱신, 진단과 검증 코드를 보관합니다. 기획 전용 `Plan`과 구현용 `Brief → Execute → Verify`는 별도 상태 엔진을 사용하지 않습니다. `scripts/workflow.sh`는 audited 10단계 실행의 상태·승인·복구를, `evals/product-development/`는 Claude Code와 Codex의 공통 결과 계약·effort·사용량 비교를 담당합니다. 회귀 테스트와 외부 소스 검사는 `tests/`와 `scripts/check-sources.sh`에 있습니다.
