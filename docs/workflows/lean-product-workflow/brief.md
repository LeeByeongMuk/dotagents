# 제품 Brief: Brief 중심 제품 개발 워크플로우

- Run ID: `lean-product-workflow`
- Status: `COMPLETE`
- Updated: `2026-08-10`

## 문제

dotagents를 사용하는 개발자가 최신 GPT-5.6 Sol, Claude Opus 5, Claude Fable 5로 제품 기능을 만들 때, 이미 모델이 수행하는 계획·자기수정·도구 선택을 공통 하네스가 중복하거나 모델마다 다른 검증 성향을 하나의 규칙으로 평탄화하면 실제 제품 개발보다 하네스 운영에 더 많은 시간과 문맥을 쓰게 된다.

## 원하는 결과와 성공 신호

- 결과: 사용자는 무엇을 왜 만드는지와 판단 기준은 명확히 통제하면서, 기존 제품 원본을 중복하지 않고 실행 순서·도구·검토 방식을 활성 모델과 작업 형태에 맡길 수 있다.
- 성공 신호: 기본 경로가 기존 권위 원본을 Brief로 재사용하고, 사전 elicitation과 모델 생성 검토는 조건부이며, 결정론적 검증과 기존 audited 상태 계약은 계속 검증된다.

## 판단 원칙

- 실행 단계 고정보다 모델 자율성을 선택한다. 왜냐하면 최신 모델은 전체 문맥에서 계획·도구·순서를 판단할 수 있기 때문이다.
- 새 워크플로우 문서보다 현재 PRD·이슈·스펙을 우선한다. 왜냐하면 같은 제품 사실의 원본이 둘이면 재개와 판단이 오염되기 때문이다.
- 모호한 자체 검토보다 결정론적 검증을 선택한다. 왜냐하면 테스트·빌드·스키마·수용 조건은 통과 여부와 종료 조건이 분명하기 때문이다.
- 공통 자기검토 규칙보다 모델별 검증 정책을 선택한다. 왜냐하면 Opus 5의 과잉 검증 회피와 Fable 5의 장기 실행 검증 권고가 서로 다르기 때문이다.
- 기본 경로의 단순함보다 형식적 증거가 중요한 위험에서는 audited 경로를 선택한다. 왜냐하면 규제·비가역 변경·공식 인수인계는 단계별 증거 자체가 제품 요구이기 때문이다.

## 절대 제약과 비목표

- 제약: 기획 하네스는 이 스킬로 수행하는 모든 제품 작업에서 필수다.
- 제약: 공통 원본은 `agents/`에 두고 Claude Code, Codex, Gemini가 공유한다.
- 제약: 기존 audited CLI 상태 버전과 회귀 테스트를 깨지 않는다.
- 제약: 변경 후 `./tooling/scripts/check.sh`와 관련 테스트를 통과한다.
- 제약: 변경 사항을 기능 브랜치에 커밋·푸시하고 `main` 대상 PR을 생성한다.
- 비목표: 멀티에이전트, 외부 스킬, RAG, 기억, 검토 기능 자체를 삭제하지 않는다.
- 비목표: 사용자 요청 없이 PR을 병합하거나 배포하지 않는다.

## 수용 조건

- [x] 스킬의 기본 경로가 `Brief → Execute → Verify`이고 audited는 명시적·고위험 선택 경로다.
- [x] 현재 PRD·이슈·스펙을 Brief로 우선 재사용하고, 필요할 때만 로컬 fallback을 만든다.
- [x] 중요한 가정·대안·사용자 소유 결정이 결과를 바꿀 때만 실행 전 elicitation을 한다.
- [x] 고정 프롬프트 체인, 역할형 멀티에이전트, 모호한 자체 검토, 무조건 RAG·기억·도구 규칙을 기본 경로에서 배제한다.
- [x] GPT-5.6 Sol, Claude Opus 5, Claude Fable 5의 모델 생성 검증 정책을 분리하면서 결정론적 검사는 공통으로 유지한다.
- [x] 기존 10단계 계약과 상태 CLI가 audited 호환 경로로 계속 동작한다.
- [x] audited 구현 단계가 서브에이전트를 이름과 절차로 강제하지 않는다.
- [x] 구조 테스트가 전체 프롬프트 문장보다 의미 계약을 검사한다.
- [x] README, 사용서, 설계, 스킬과 참조 문서가 같은 기본 경로를 설명한다.
- [x] skill validator, 저장소 전체 검사와 관련 회귀 테스트가 통과한다.
- [x] 변경 전·후 하네스를 같은 두 상황으로 GPT-5.6 Sol, Claude Opus 5, Claude Fable 5에서 비교하고 행동·비용 신호와 한계를 기록한다.
- [x] 변경 사항이 기능 브랜치에 커밋·푸시되고 `main` 대상 PR이 생성된다.

## 결정 기록

| 날짜 | 결정 | 버린 대안 | 이유 | 결정자 |
|---|---|---|---|---|
| 2026-08-04 | 기본 경로를 `Brief → Execute → Verify`로 변경 | 기존 10단계를 기본으로 유지 | 실행 하네스 비용을 줄이되 기획과 검증은 보존 | 사용자 |
| 2026-08-04 | 기존 10단계를 audited 호환 경로로 보존 | 즉시 삭제 | 실제 사용 비교 전 호환성과 고위험 증거 경로를 잃지 않기 위해 | 사용자·Codex |
| 2026-08-04 | 하나의 living Brief를 기획 단일 원본으로 사용 | 인터뷰·도메인·설계·스펙을 별도 불변 문서로 유지 | 문맥 손실과 상충하는 현재 진실을 줄이기 위해 | 사용자·Codex |
| 2026-08-05 | 실행 전 Brief 초안 1회 제시와 가정·대안·질문 묶음 전달을 기본 경로에 추가 | 질문 최소화 규칙만 유지 | 사용자 피드백으로 추가 정보를 전달할 접점과 브레인스토밍 가시성이 부족했음 | 사용자 |
| 2026-08-10 | 현재 PRD·이슈·스펙을 Brief로 우선 채택 | 모든 실행에 새 `brief.md` 생성 | 제품 사실의 중복 원본을 만들지 않기 위해 | 사용자·Codex |
| 2026-08-10 | 사전 Brief 제시를 결과를 바꿀 정보가 있을 때만 수행 | 무조건 1회 제시 또는 완전 제거 | 정보 elicitation은 보존하되 의식적 중간 메시지를 없애기 위해 | 사용자·Codex |
| 2026-08-10 | 결정론적 검증은 공통으로 두고 모델 생성 검토는 Sol·Opus·Fable별로 구분 | Opus 5 지침을 모든 모델에 일반화 | 세 모델의 공식 검증 권고가 같지 않기 때문에 | 사용자·Codex |
| 2026-08-10 | audited 상태 버전과 10단계 수는 유지하고 구현의 서브에이전트 강제만 완화 | 사용 근거 없이 즉시 4단계로 축소 | 기존 상태 호환을 지키면서 확인된 과잉만 제거하기 위해 | Codex |
| 2026-08-10 | 두 대표 상황의 변경 전·후 행동 eval을 세 모델에서 실행 | 정책 문구와 구조 테스트만으로 완료 판정 | 실제 모델의 Brief·중단·검증 결정을 확인하기 위해 | 사용자·Codex |

## 열린 제품 결정

- `None`

## 실행 체크포인트

- 현재 상태: 스킬·문서·테스트 수정, 세 모델의 초기 A/B 행동 eval, 기능 브랜치 푸시와 PR #9 생성을 완료했다.
- 다음 행동: 사용자가 PR #9의 최종 변경을 검토한다.
- 변경 파일: `agents/skills/owned/product-development-workflow/`, `agents/workflows/product-development/`, `docs/designs/product-development-workflow.md`, `docs/evals/product-development-workflow-model-behavior.md`, `README.md`, `tooling/tests/structure_test.sh`, `tooling/scripts/check.sh`

## 검증 증거

| 수용 조건/위험 | 검증 방법 | 결과 |
|---|---|---|
| 기본 lean 계약 | `tooling/tests/structure_test.sh` | 통과 |
| audited 상태 호환성 | `tooling/tests/workflow_test.sh` | 15개 시나리오 통과 |
| 전체 저장소 규칙 | `./tooling/scripts/check.sh` | 통과 |
| 스킬 형식 | `uv run --with pyyaml python skill-creator/scripts/quick_validate.py agents/skills/owned/product-development-workflow` | `Skill is valid!` |
| 패치 형식 | `git diff --check` | 통과 |
| 세 모델 행동 분기 | 변경 전·후 동일 2개 상황을 각 모델에 실행 | 후보 3개 모두 계약 통과; 상세는 `docs/evals/product-development-workflow-model-behavior.md` |
| PR 전달 | `gh pr view 9 --json number,url,state,isDraft,headRefName,baseRefName,statusCheckRollup` | PR #9 OPEN, `feat/model-aware-workflow-harness → main`, non-draft, 등록된 상태 검사 없음 |

## 남은 위험

- 단일 합성 행동 eval은 정책 분기를 확인하지만, 여러 실제 구현 작업의 성공률·결함률·전체 비용 차이는 아직 측정하지 않았다.
- audited 경로의 외부 실사용 횟수와 실제로 필요한 승인 증거는 이 저장소만으로 확인할 수 없다.
