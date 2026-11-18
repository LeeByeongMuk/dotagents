# 문서 목록

[dotagents 소개와 빠른 시작](../README.md)

## 사용 안내

| 목적 | 문서 |
| --- | --- |
| 전역 설치·갱신·제거·복원 | [설치 안내](install.md) |
| 프로젝트 점검과 로컬 지침 초기화 | [프로젝트 준비](project-readiness.md) |
| 직접 만든 스킬 선택과 요청 예시 | [스킬 목록](../agents/skills/owned/README.md) |
| 제품 기획과 구현 진행 | [제품 개발 워크플로우](../agents/workflows/product-development/WORKFLOW.md) |
| 커밋 메시지 검사 | [훅 안내](../agents/hooks/README.md) |
| 외부 스킬 설치·갱신·제거 | [외부 스킬 관리](external-skills.md) |
| 셸·Git 설정 조각 적용 | [개발 환경 프로필](../environment/README.md) |
| Codex 모델·권한·프로필 설정 | [Codex 설정](../agents/adapters/codex/README.md) |

## 유지보수

- [저장소 구조와 원본의 역할](../agents/README.md)
- [관리 명령과 변경 검증](../tooling/README.md)
- [스킬 추가·제거 절차](../agents/skills/README.md)
- [레지스트리와 소스 잠금](../agents/registry/README.md)
- [외부 연동 범위](../agents/integrations/README.md)
- [프로젝트 컨텍스트 문서 템플릿](../agents/templates/context-docs/README.md)

## 설계와 결정

- [전역 설치 레이아웃과 소유권](designs/install-layouts.md): legacy·managed의 경로, 설정, 기록과 이행 계약
- [제품 개발 워크플로우 설계](designs/product-development-workflow.md)
- [선택 환경 프로필 설계와 배포 비교](designs/environment-profile.md)
- [설계 결정 목록](decisions/README.md)

## 평가와 작업 기록

평가 결과는 문서에 적힌 시점과 조건의 관찰입니다. 재실행 방법은 각 [평가 도구 안내](../tooling/README.md#평가)에 있습니다.

- [커밋 규칙 압축 평가](evals/commit-message-rule-compression.md)
- [제품 워크플로우 모델 행동 평가](evals/product-development-workflow-model-behavior.md)
- [제품 워크플로우 Model Fit 평가](evals/product-development-workflow-model-fit.md)
- [프로젝트·환경 인터페이스 의사결정 평가](evals/renewal-interface-decisions.md)

작업별 범위·수용 조건·검증·재개 지점은 채택한 PRD·이슈·스펙에서 관리하며, 별도 원본이 없을 때 `workflows/<run-id>/brief.md`를 사용합니다.

- [dotagents 개편 작업](workflows/dotagents-renewal/brief.md)
- [Brief 중심 제품 개발 워크플로우](workflows/lean-product-workflow/brief.md)
- [Model Fit 라우팅](workflows/model-fit-routing/brief.md)

사용법은 해당 안내 문서, 실행 계약은 스킬과 코드, 설계 근거는 `designs/`·`decisions/`가 소유합니다. 다른 문서에서는 원본으로 링크합니다.
