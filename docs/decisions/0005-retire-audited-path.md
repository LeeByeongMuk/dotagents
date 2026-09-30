# ADR 0005: audited 경로 제거와 Model Fit 발동 조건

- 날짜: 2026-09-30
- 상태: ACCEPTED

## 맥락

- 제품 개발 워크플로우는 2026-08-20 개편 뒤에도 `direct`, `plan`, `lean`과 함께 10단계 `audited` 호환 경로를 유지했다. 상태 CLI `tooling/scripts/workflow.sh`(715줄, `dotagents-workflow`로 설치), `references/stages.md`, `references/artifacts.md`, `agents/workflows/product-development/workflow.toml`과 245줄의 `workflow_test.sh`가 이를 지탱했고, 이 테스트가 `make test` 시간의 약 절반을 차지했다.
- 2026-09-30 전면 검토에서 사용자의 프로젝트들에서 audited 실행 흔적(`.dotagents/runs`, 단계 산출물)을 찾지 못했고, 사용자는 이 경로를 제거하기로 했다.
- Model Fit은 호스트가 실행 가능한 모델 후보를 둘 이상 노출하거나 사용자가 요청할 때 실행됐다. 호스트가 서브에이전트용 모델 선택지를 노출하는 것만으로 조건이 참으로 읽힐 수 있고, 주 에이전트는 스스로 모델을 바꿀 수 없어 결과는 대부분 `stay`다. 다른 프로젝트의 실제 Brief에는 호스트가 모델 ID도 노출하지 않은 상태에서 `stay`와 확신도 low만 기록된 사례가 있었다.

## 결정

1. 경로는 `direct`, `plan`, `lean`만 둔다. 규제, 민감한 보안 경계, 비가역 데이터 변경, 여러 팀의 공식 승인처럼 형식적 증거가 필요한 작업은 `lean`에서 필요한 승인과 증거를 Brief의 수용 조건으로 둔다.
2. audited 상태 CLI와 `dotagents-workflow` 설치 링크, `stages.md`, `artifacts.md`, `workflow.toml`, 10단계 테스트를 제거한다. 마지막 구현은 `10803da`에서 복원할 수 있다.
3. Model Fit은 사용자가 모델 선택이나 비교를 명시적으로 요청할 때만 실행한다. 참조 문서의 판단 순서와 결과 형식은 유지한다.

## 버린 대안

- audited 유지: 쓰이지 않는 계약이 테스트 시간과 문서·테스트 동반 수정 비용을 계속 만든다.
- Model Fit 참조 축소: 요청할 때만 읽히므로 평소 문맥 비용이 없다. 축소는 교차 공급자 측정 뒤로 미룬다.

## 결과

- 라우팅 eval 사례는 12개다. audited 경로를 이름으로 요청하던 `audited-migration`을 삭제했고, `formal-evidence-implementation`은 `lean`을 기대한다.
- 외부 공급자 스킬의 audited 단계 슬롯을 없앴다. 네 개는 워크플로우 연결 없이 검토 목록으로 남고, `gstack-review`와 `gstack-qa`는 lean 검증 후보로 남는다.
- 기존 설치의 `~/.local/bin/dotagents-workflow` 링크는 다음 전역 설치 때 설치 목록에서 빠진 항목으로 제거된다.
