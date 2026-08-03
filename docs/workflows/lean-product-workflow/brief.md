# 제품 Brief: Brief 중심 제품 개발 워크플로우

- Run ID: `lean-product-workflow`
- Status: `COMPLETE`
- Updated: `2026-08-04`

## 문제

dotagents를 사용하는 개발자가 일반 제품 기능을 만들 때, 기존 10단계 워크플로우가 모든 작업을 단계별 문서·승인·검토·멀티에이전트로 나누어 모델의 현재 실행 능력을 제한하고, 실제 제품 개발보다 하네스 운영에 더 많은 시간과 문맥을 쓸 수 있다.

## 원하는 결과와 성공 신호

- 결과: 사용자는 무엇을 왜 만드는지와 판단 기준은 명확히 통제하면서, 실행 순서와 도구 선택은 모델에 맡길 수 있다.
- 성공 신호: 제품 워크플로우의 기본 경로가 `Brief → Execute → Verify`로 설명·실행되고, 기존 10단계 상태 계약은 audited 선택 경로에서 계속 검증된다.

## 판단 원칙

- 실행 단계 고정보다 모델 자율성을 선택한다. 왜냐하면 최신 모델은 전체 문맥에서 계획·도구·순서를 판단할 수 있기 때문이다.
- 여러 승인 문서보다 하나의 살아 있는 Brief를 선택한다. 왜냐하면 현재 진실과 결정 이유를 한곳에서 읽어야 재개와 판단이 정확하기 때문이다.
- 모호한 자체 검토보다 결정론적 검증을 선택한다. 왜냐하면 테스트·빌드·스키마·수용 조건은 통과 여부와 종료 조건이 분명하기 때문이다.
- 기본 경로의 단순함보다 형식적 증거가 중요한 위험에서는 audited 경로를 선택한다. 왜냐하면 규제·비가역 변경·공식 인수인계는 단계별 증거 자체가 제품 요구이기 때문이다.

## 절대 제약과 비목표

- 제약: 기획 하네스는 모든 이 스킬의 제품 작업에서 필수다.
- 제약: 공통 원본은 `agents/`에 두고 Claude Code, Codex, Gemini가 공유한다.
- 제약: 기존 audited CLI 상태 버전과 회귀 테스트를 깨지 않는다.
- 제약: 변경 후 `./tooling/scripts/check.sh`와 관련 테스트를 통과하고 PR을 생성해 `LeeByeongMuk`에게 할당한다.
- 비목표: 멀티에이전트, 외부 스킬, RAG, 기억, 검토 기능 자체를 삭제하지 않는다.
- 비목표: 사용자 요청 없이 PR을 병합하거나 배포하지 않는다.

## 수용 조건

- [x] 스킬의 기본 경로가 `Brief → Execute → Verify`이고 audited는 명시적·고위험 선택 경로다.
- [x] Brief가 문제, 결과, 판단 원칙, 제약, 수용 조건, 결정 기록과 검증 증거를 필수로 담는다.
- [x] 고정 프롬프트 체인, 역할형 멀티에이전트, 모호한 자체 검토, 무조건 RAG·기억·도구 규칙을 기본 경로에서 배제한다.
- [x] 기존 10단계 계약과 상태 CLI가 audited 호환 경로로 계속 동작한다.
- [x] README, 사용서, 라우팅, 레지스트리, UI 메타데이터가 같은 기본 경로를 설명한다.
- [x] skill validator, 저장소 전체 검사와 관련 회귀 테스트가 통과한다.
- [x] 변경 사항이 기능 브랜치에 커밋·푸시되고 PR이 생성되어 `LeeByeongMuk`에게 할당된다.

## 결정 기록

| 날짜 | 결정 | 버린 대안 | 이유 | 결정자 |
|---|---|---|---|---|
| 2026-08-04 | 기본 경로를 `Brief → Execute → Verify`로 변경 | 기존 10단계를 기본으로 유지 | 실행 하네스 비용을 줄이되 기획과 검증은 보존 | 사용자 |
| 2026-08-04 | 기존 10단계를 audited 호환 경로로 보존 | 즉시 삭제 | 실제 사용 비교 전 호환성과 고위험 증거 경로를 잃지 않기 위해 | 사용자·Codex |
| 2026-08-04 | 하나의 living Brief를 기획 단일 원본으로 사용 | 인터뷰·도메인·설계·스펙을 별도 불변 문서로 유지 | 문맥 손실과 상충하는 현재 진실을 줄이기 위해 | 사용자·Codex |

## 열린 제품 결정

- `None`

## 실행 체크포인트

- 현재 상태: 구현·검증·커버리지 감사·푸시·PR 생성과 담당자 할당을 모두 완료했다.
- 다음 행동: 사용자가 PR #4의 최종 변경을 검토한다.
- 변경 파일: `agents/skills/owned/product-development-workflow/`, `agents/workflows/product-development/`, `docs/designs/product-development-workflow.md`, `README.md`, 관련 레지스트리·테스트

## 검증 증거

| 수용 조건/위험 | 검증 방법 | 결과 |
|---|---|---|
| 기본 lean 라우팅 | `tooling/tests/structure_test.sh`, 핵심 원칙 `rg` 검색 | 통과 |
| audited 호환성 | `tooling/tests/workflow_test.sh` 14개 시나리오 | 통과 |
| 전체 저장소 규칙 | `./tooling/scripts/check.sh` | 통과 |
| 스킬 형식 | `skill-creator/scripts/quick_validate.py` | 통과 (`Skill is valid!`) |
| 위험 기반 라우팅 | 민감한 팀 데이터 내보내기 포워드 테스트 | `audited`와 단일 기획 Brief 선택, 누락 정보만 질문 |
| 일반 제품 기능 라우팅 | 개인용 저장 필터 기능 포워드 테스트 | `lean`과 단일 living Brief 선택, provider·서브에이전트·RAG 미사용 |
| 회귀 방지 범위 | 사전 랜딩 커버리지 감사 후 구조 테스트 보강 | lean/audited 라우팅, Brief 전체 스키마, 레지스트리 매핑, CLI·UI 프롬프트 의미 검증 통과 |
| PR과 담당자 | `gh pr view 4 --json url,state,assignees,headRefName,baseRefName` | PR #4 OPEN, `feat/lean-product-workflow → main`, `LeeByeongMuk` 할당 확인 |

## 남은 위험

- 실제 여러 제품 작업에서 lean과 audited의 시간·토큰·결함 차이는 아직 측정되지 않았다.
