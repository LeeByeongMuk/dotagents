# 제품 개발 워크플로우

[문서 목록](../../../docs/README.md) · [스킬 목록](../../skills/owned/README.md)

`product-development-workflow` 스킬의 사람용 사용 안내입니다. 경로 선택, Brief·Execute·Verify, Model Fit, 호스트별 검증의 원본은 스킬의 [`SKILL.md`](../../skills/owned/product-development-workflow/SKILL.md)와 `references/`이며, 이 문서는 그 내용을 다시 적지 않습니다.

## 경로

| 경로 | 언제 | 결과 |
|---|---|---|
| `direct` | 작은 수정, 단일 버그, 설명, 제품 결정을 만들지 않는 사실 조사 | 이 워크플로우 없이 프로젝트 일반 절차 |
| `plan` | 기획·설계만 요청하고 구현 권한이 없을 때 | 기획 결과를 내고 파일이나 구현을 바꾸지 않음 |
| `lean` | 구현을 요청했을 때 | Brief → Execute → Verify |

규제, 민감한 보안 경계, 비가역 데이터 변경처럼 공식 증거가 필요한 작업도 `lean`으로 진행하고, 필요한 승인과 증거를 Brief의 수용 조건으로 둡니다.

## 사용

```text
$product-development-workflow 로 인증 기능을 조사하고 기획안만 만들어줘. 구현은 하지 마.
$product-development-workflow 로 이 프로젝트에 인증 기능을 추가해줘. Brief부터 구현 검증까지 진행해줘.
```

## 기록과 재개

- 현재 PRD·이슈·스펙이 제품 결정을 소유하면 그것을 Brief로 쓰고, 없을 때만 `docs/workflows/<run-id>/brief.md`를 만듭니다.
- 새 Brief나 로컬 실행 기록은 사용자가 지정한 언어로 씁니다. 지정이 없으면 프로젝트 문서의 언어를 따르고, 정해진 문서 언어가 없으면 대화 언어를 따릅니다.
- 중단되면 채택한 제품 원본, 로컬 Brief, Git 상태, diff, 최근 커밋에서 이어갑니다. 별도 상태 명령은 없습니다.
- 실행 모델 권고(Model Fit)는 모델을 골라 달라고 요청할 때만 합니다.
- gstack, Superpowers 같은 외부 스킬은 현재 작업에 필요한 능력만 개별로 사용합니다.
- 배포, 푸시, PR 생성은 요청이 있을 때만 수행합니다.
- 사용자가 자기 dotagents에 재사용할 관례를 찾아 달라고 요청하면 후보와 반영할 위치를 제안합니다. 해당 관례를 반영해 달라는 요청이 있을 때만 `dotagents-promote`를 사용합니다.
