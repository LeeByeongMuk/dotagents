# Tooling

dotagents의 설치, 제거, 생성, 갱신, 진단과 검증 코드를 보관합니다. 기본 `Brief → Execute → Verify` 경로는 별도 상태 엔진을 사용하지 않습니다. `scripts/workflow.sh`는 audited 10단계 실행의 상태·승인·복구를 관리하고 `tests/workflow_test.sh`가 그 호환 경계를 검증합니다. `scripts/check-sources.sh`는 네트워크를 사용해 잠긴 외부 스킬 경로가 해당 커밋에 실제로 있는지 확인합니다. 사용자용 명령과 전체 구조는 루트 `README.md`를 따릅니다.
