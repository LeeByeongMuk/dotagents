# 제품 Brief: Brief 중심 제품 개발 워크플로우

- Run ID: `lean-product-workflow`
- Status: `COMPLETE`
- Updated: `2026-08-20`

## 문제

dotagents를 사용하는 개발자가 Codex와 Claude Code에서 제품을 기획하거나 구현할 때, 기획 전용 요청과 구현 요청이 같은 경로로 처리되거나 두 호스트의 검증 성향을 하나의 규칙으로 평탄화하면 작업 범위를 넘기고 불필요한 지침을 읽게 된다. 반대로 호스트마다 전체 워크플로우를 복제하면 같은 제품 결정 계약이 서로 달라진다.

## 원하는 결과와 성공 신호

- 결과: 사용자는 Codex와 Claude Code에서 동일한 기획 결과 계약을 얻고, 기획 요청은 구현 없이 끝내며, 구현 요청만 Brief에서 실행과 검증으로 이어갈 수 있다.
- 성공 신호: 공통 스킬이 `direct / plan / lean / audited`를 구분하고, Brief 템플릿과 호스트별 검증 지침은 필요한 경우에만 읽히며, 동일 eval 사례가 두 호스트의 결과 계약과 비용을 비교할 수 있다.

## 판단 원칙

- 실행 단계 고정보다 모델 자율성을 선택한다. 왜냐하면 최신 모델은 전체 문맥에서 계획·도구·순서를 판단할 수 있기 때문이다.
- 새 워크플로우 문서보다 현재 PRD·이슈·스펙을 우선한다. 왜냐하면 같은 제품 사실의 원본이 둘이면 재개와 판단이 오염되기 때문이다.
- 모호한 자체 검토보다 결정론적 검증을 선택한다. 왜냐하면 테스트·빌드·스키마·수용 조건은 통과 여부와 종료 조건이 분명하기 때문이다.
- 공통 자기검토 규칙보다 모델별 검증 정책을 선택한다. 왜냐하면 Opus 5의 과잉 검증 회피와 Fable 5의 장기 실행 검증 권고가 서로 다르기 때문이다.
- 호스트별 워크플로우 복제보다 공통 결과 계약과 얇은 호스트 참조를 선택한다. 왜냐하면 제품 판단은 같아야 하지만 내부 추론과 도구 사용까지 같을 필요는 없기 때문이다.
- 항상 읽는 상세 템플릿보다 조건부 참조를 선택한다. 왜냐하면 현재 제품 원본을 재사용하는 실행에는 fallback 문서 형식이 필요하지 않기 때문이다.
- 기본 경로의 단순함보다 형식적 증거가 중요한 위험에서는 audited 경로를 선택한다. 왜냐하면 규제·비가역 변경·공식 인수인계는 단계별 증거 자체가 제품 요구이기 때문이다.

## 절대 제약과 비목표

- 제약: 기획 하네스는 이 스킬로 수행하는 모든 제품 작업에서 필수다.
- 제약: 공통 원본은 `agents/`에 두고 Claude Code, Codex, Gemini가 공유하며, 이번 고도화의 교차 호스트 검증은 Claude Code와 Codex를 우선한다.
- 제약: 기존 audited CLI 상태 버전과 회귀 테스트를 깨지 않는다.
- 제약: 변경 후 `./tooling/scripts/check.sh`와 관련 테스트를 통과한다.
- 제약: 커밋·푸시·PR 생성은 이번 사용자 요청의 범위가 아니다.
- 비목표: 멀티에이전트, 외부 스킬, RAG, 기억, 검토 기능 자체를 삭제하지 않는다.
- 비목표: 사용자 요청 없이 PR을 병합하거나 배포하지 않는다.

## 수용 조건

- [x] `AC-01` 스킬의 기본 구현 경로가 `Brief → Execute → Verify`이고 audited는 명시적·고위험 선택 경로다.
- [x] `AC-02` 현재 PRD·이슈·스펙을 Brief로 우선 재사용하고, 필요할 때만 로컬 fallback을 만든다.
- [x] `AC-03` 중요한 가정·대안·사용자 소유 결정이 결과를 바꿀 때만 실행 전 elicitation을 한다.
- [x] `AC-04` 고정 프롬프트 체인, 역할형 멀티에이전트, 모호한 자체 검토, 무조건 RAG·기억·도구 규칙을 기본 경로에서 배제한다.
- [x] `AC-05` GPT-5.6 Sol, Claude Opus 5, Claude Fable 5의 모델 생성 검증 정책을 분리하면서 결정론적 검사는 공통으로 유지한다.
- [x] `AC-06` 기존 10단계 계약과 상태 CLI가 audited 호환 경로로 계속 동작한다.
- [x] `AC-07` audited 구현 단계가 서브에이전트를 이름과 절차로 강제하지 않는다.
- [x] `AC-08` 구조 테스트가 전체 프롬프트 문장보다 의미 계약을 검사한다.
- [x] `AC-09` README, 사용서, 설계, 스킬과 참조 문서가 같은 기본 경로를 설명한다.
- [x] `AC-10` skill validator, 저장소 전체 검사와 관련 회귀 테스트가 통과한다.
- [x] `AC-11` 변경 전·후 하네스를 같은 두 상황으로 GPT-5.6 Sol, Claude Opus 5, Claude Fable 5에서 비교하고 행동·비용 신호와 한계를 기록한다.
- [x] `AC-12` 이전 변경 사항이 기능 브랜치에 커밋·푸시되고 `main` 대상 PR이 생성됐다.
- [x] `AC-13` 기획 전용 요청은 공통 `plan` 경로에서 파일이나 구현을 암묵적으로 변경하지 않고 종료한다.
- [x] `AC-14` Claude Code와 Codex는 동일한 라우팅·Brief·수용 조건·검증 계약을 공유하고 호스트 전용 동작만 별도 참조에서 정의한다.
- [x] `AC-15` 기존 제품 원본이 충분한 lean 실행은 로컬 Brief 템플릿을 읽지 않고, fallback 생성 시에만 템플릿을 읽는다.
- [x] `AC-16` Codex는 Codex 검증 참조만, Claude Code는 Claude 검증 참조만 읽도록 명시하며 다른 호스트 지침을 불러오지 않는다.
- [x] `AC-17` 동일 사례와 결과 스키마로 Codex와 Claude Code를 실행하고 토큰·지연·행동 결과를 비교할 수 있는 eval 도구가 있다.
- [x] `AC-18` README, 사용서, 설계, 구조 검사와 전체 저장소 검사가 새 공통 계약을 검증한다.
- [x] `AC-19` 교차 호스트 채점기는 빈 결과, 알 수 없는 공급자, 중복·미등록 사례, 스키마가 잘못된 결정을 실패시키고 `--require-all`에서 Codex와 Claude의 모든 사례를 요구한다.
- [x] `AC-20` eval 실행기는 기존 출력 파일을 암묵적으로 덮어쓰지 않고, 명시적 강제 옵션과 전체 하네스·호스트 참조를 사용한다.
- [x] `AC-21` 제품 결정을 위한 탐색은 `plan`, 단순 사실 조사·설명은 `direct`로 구분하며 제품 구현 권한과 작은 수정·기획 문서 갱신을 포함한 파일 변경 권한을 별도로 판정한다.
- [x] `AC-22` 경계 사례가 공통 eval에 포함되고 Claude Code와 Codex의 실제 전 경로 결과가 같은 계약을 통과한다.
- [x] `AC-23` 부정 회귀 테스트, 사용자 문서, 설계, Brief와 전체 저장소 검사가 보강된 계약을 증명한다.

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
| 2026-08-20 | 공통 경로에 기획 전용 `plan`을 추가 | 기획 요청도 lean 실행 또는 direct 설명으로 처리 | 기획 결과는 보존하면서 구현 권한을 넘지 않기 위해 | 사용자·Codex |
| 2026-08-20 | 제품 계약은 공유하고 검증 참조만 Codex와 Claude Code로 분리 | 전체 스킬을 호스트별 복제 | 결과 드리프트 없이 각 호스트의 추론·검토 특성을 반영하기 위해 | 사용자·Codex |
| 2026-08-20 | Brief 템플릿과 호스트 지침을 조건부 로딩 | 모든 lean 실행에서 모든 참조 로딩 | 현재 제품 원본을 재사용하는 일반 경로의 고정 문맥을 줄이기 위해 | 사용자·Codex |
| 2026-08-20 | 같은 사례·결과 계약과 공급자별 실행 어댑터로 eval | 서로 다른 프롬프트와 수동 결과 비교 | 동작 차이는 허용하되 제품 결과와 비용을 같은 기준으로 비교하기 위해 | 사용자·Codex |
| 2026-08-20 | `--require-all`은 정확히 Codex와 Claude의 전체 사례를 요구 | 발견된 공급자 수만 기준으로 성공 | 한 공급자 또는 빈 결과가 교차 호스트 통과로 오인되는 것을 막기 위해 | Codex |
| 2026-08-20 | 제품 의사결정 탐색과 사실 조사를 라우팅 문구에서 분리 | `explore`와 `research-only`를 중첩된 의미로 유지 | 같은 요청이 `direct`와 `plan` 사이에서 흔들리지 않게 하기 위해 | Codex |
| 2026-08-20 | 제품 구현 권한과 모든 로컬 파일 변경 권한을 별도 판정 | direct 수정과 기획 문서 갱신을 제품 구현으로 간주 | 요청 범위를 넘지 않으면서 작은 승인된 변경을 표현하기 위해 | Codex |
| 2026-08-20 | eval 입력을 시작 시 고정하고 출처 해시와 adapter revision 기록 | 실행 중 원본 파일을 반복 읽고 결과 파일명만으로 비교 | 긴 실행의 계약 혼합과 오래된 결과 재사용을 막기 위해 | Codex |
| 2026-08-20 | 자동 채점은 증거 형식·최소 개수까지만 보장 | 구조화 JSON만으로 증거 문장의 의미 적합성까지 주장 | 의미 평가는 별도 judge나 수동 검토가 필요하다는 측정 경계를 명확히 하기 위해 | Codex |

## 열린 제품 결정

- `None`

## 실행 체크포인트

- 현재 상태: 공격적 감사에서 발견한 채점·출력·provenance·CLI 어댑터 결함을 회귀 테스트로 고정했고, 스냅샷된 최종 계약의 Codex·Claude 26개 실제 결과와 전체 저장소 검사가 모두 통과했다.
- 다음 행동: 없음. 사용자가 요청할 때 변경을 커밋·푸시하거나 실제 구현 작업 성공률을 측정하는 후속 eval을 별도 수행한다.
- 변경 파일: `agents/skills/owned/product-development-workflow/`, `agents/routing/`, `agents/workflows/product-development/`, `docs/`, `README.md`, `tooling/evals/`, `tooling/tests/`, `tooling/scripts/check.sh`

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
| `AC-13` 기획 비변경 계약 | fresh-context 전방 테스트: 팀별 API 사용량 예산 기획 | `plan`, 구현 미승인, 참조 추가 로딩 없음, 파일 변경 없음 |
| `AC-14`~`AC-16` 공통·호스트 분리 계약 | `tooling/tests/structure_test.sh`와 스킬 validator | 통과; 공통 스킬 하나와 활성 호스트 참조 하나만 사용 |
| `AC-17` 교차 호스트 판정 | `tooling/evals/product-development/score.sh --require-all tooling/evals/product-development/fixtures/{codex,claude}.jsonl` | 두 공급자 13개 fixture 결과 통과 |
| `AC-17` 실제 호스트 실행 | `score.sh /tmp/dotagents-codex-plan.jsonl /tmp/dotagents-claude-plan.jsonl` | GPT-5.6 Sol·Claude Opus 5의 `plan-only` 결과 모두 통과 |
| 조건부 참조 문맥 | 이전·현재 파일에 `wc -w` | 2,093단어에서 Codex 1,634단어·Claude 1,689단어로 약 22%·19% 감소; Model Fit 참조 1,449단어는 후보가 둘 이상이거나 모델 선택 요청이 있을 때만 추가 |
| `AC-18` 전체 회귀 | `./tooling/scripts/check.sh` | 필수 파일, 셸 문법, 구조, audited 15개 시나리오, 교차 호스트 eval, 설치 dry-run 등 모두 통과 |
| `AC-19` 채점기 공격 회귀 | `tooling/tests/eval_test.sh` | 빈·단일 공급자·중복·미등록·잘못된 스키마/effort/사용량/출처/증거를 모두 실패 처리 |
| `AC-20` 실행기 안전성 | 모의 Codex·Claude 정상/실패·경쟁 테스트 | CLI 옵션과 사용량 파싱 통과; 실패 시 기존 결과 보존; 변경된 입력은 스냅샷 고정; 대상 심볼릭 링크를 따라가지 않음 |
| `AC-21`~`AC-22` 경계·실제 호스트 | `score.sh --require-all /tmp/dotagents-live-pr11-merged-{codex,claude}-20260820.jsonl` | Model Fit 통합 후 13개×2=26개 통과; Codex 99초, Claude 146초·$0.907175 |
| 실제 증거 의미 표본 | 26개 결과의 첫 수용 조건·검사·질문을 사례 문맥과 수동 대조 | 제품/기능 명칭과 기대 동작이 사례에 대응했고, 차단 결정 사례만 두 호스트 모두 질문 1개 포함 |
| fresh-context 전방 테스트 | 사실 조사, 제품 탐색, 고위험 기획 전용 요청 | 각각 `direct`, `plan`, `plan`; 구현·파일 변경 없음 |
| `AC-23` 최종 검증 | metadata 생성기, skill validator, `./tooling/scripts/check.sh`, `tooling/tests/install_test.sh`, `git diff --check` | `Skill is valid!`; 전체 검사와 설치 9개 시나리오 통과; 패치 형식 통과 |

## 남은 위험

- 13개 합성 행동 eval은 정책 분기와 구조 계약을 확인하지만, 실제 구현 작업의 성공률·결함률 차이는 아직 측정하지 않았다.
- audited 경로의 외부 실사용 횟수와 실제로 필요한 승인 증거는 이 저장소만으로 확인할 수 없다.
- 자동 채점은 수용 조건과 검사의 형식·최소 개수만 확인하며 문장 의미의 시나리오 적합성은 수동 검토나 별도 semantic judge가 필요하다.
- 공급자별 입력·캐시 토큰 집계 의미가 달라 Codex와 Claude의 원시 합계를 직접 비용 비교할 수 없다.
