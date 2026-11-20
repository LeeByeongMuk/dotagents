# Brief 중심 제품 워크플로우 도입 기록

2026-08-20 기준으로 Codex와 Claude Code가 같은 제품 요구사항과 수용 조건을 따르도록 공통 스킬을 정리했다. 제품 기획과 구현의 경계를 명시하고, 호스트별 검증 지침은 필요한 시점에 읽도록 했다. [제품 개발 워크플로우 사용 안내](../../../agents/workflows/product-development/WORKFLOW.md)

## 결정 기록

- 제품 결정을 요청한 경우 `plan`으로 기획 결과를 전달한다. 구현 요청은 `lean`에서 기존 PRD·이슈·스펙을 Brief로 삼아 실행하고 수용 조건별로 검증한다. 작은 수정과 사실 확인은 `direct`로 처리한다. [실행 계약](../../../agents/skills/owned/product-development-workflow/SKILL.md)
- 두 호스트는 라우팅·수용 조건·검증 결과 형식을 공유한다. 어떤 도구와 검토 방식을 사용할지는 해당 호스트의 지침을 따른다. [설계 근거](../../designs/product-development-workflow.md)
- 당시 함께 지원한 10단계 `audited` 경로는 이후 폐기했다. 형식적 승인 절차가 필요한 작업은 `lean`의 수용 조건에 승인과 검증 증거를 명시한다. [ADR 0005](../../decisions/0005-retire-audited-path.md)

## 검증 증거

도입 당시 두 호스트에 같은 13개 사례를 실행해 결과 26개가 라우팅과 실행 권한에 관한 계약을 통과했다. 형식화된 결과를 채점한 실험이며, 실제 프로젝트의 결함률이나 작업 성공률은 별도로 측정해야 한다. [평가 기록](../../evals/product-development-workflow-model-behavior.md)

현재 사례 집합은 `./tooling/tests/eval_test.sh`로 검사할 수 있다. 실제 모델 호출과 고정 fixture를 이용한 검증의 실행 방법은 [평가 도구 안내](../../../tooling/evals/product-development/README.md)에 있다.
