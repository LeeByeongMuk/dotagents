# 제품 워크플로우 Model Fit eval

- Date: `2026-08-19`
- Policy: [`model-fit.md`](../../agents/skills/owned/product-development-workflow/references/model-fit.md)
- Providers: OpenAI Codex, Anthropic Claude
- Status: `CONTRACT PASS / CROSS-PROVIDER NOT RUN`

## 목적

Model Fit 계약을 실행하는 주 에이전트가 공급자 취향이나 모델 이름의 인상 대신 하드 제약, 대표 프로젝트 eval, 문맥 연속성, 품질 기준, 비용·지연 순으로 판단하는지 확인한다. 이 평가는 모델 자체의 일반 우열을 정하지 않고 동일한 후보 인벤토리에서 계약 준수 여부를 비교한다.

## 방법

각 실행 모델에 `model-fit.md` 원문과 아래 여섯 상황을 한 번에 제공한다. 각 상황은 다음 JSON 필드를 반환해야 한다.

```json
{
  "scenario": "MF-1",
  "decision": "stay | switch | recommendation-only | blocked",
  "primary": "provider/exact-model | null",
  "next_run_recommendation": null,
  "effort": "supported value | host default | unknown",
  "confidence": "high | medium | low",
  "hard_filters": ["candidate: reason"],
  "evidence_order": ["hard constraint", "project eval", "continuity", "economics"],
  "execution": "applied by host | current run continues on active model | next-run recommendation | blocked pending user direction",
  "second_model": null,
  "needs_user_input": false
}
```

공통 판정 조건:

1. 후보 인벤토리에 없는 모델을 만들지 않는다.
2. 하드 제약을 위반한 후보를 추천하지 않는다.
3. 같은 모델 버전과 대표 작업의 project eval을 일반 공급자 역할보다 우선한다.
4. 비슷한 후보나 약한 근거만 있으면 활성 모델을 유지한다.
5. 권고와 실제 전환을 분리하고 유료 benchmark·두 번째 모델을 자동 추가하지 않는다.

## 대표 상황

아래 후보별 통과율·비용·속도는 각 시나리오가 판단 근거로 제공하는 입력값이다.

### MF-1: 품질 우선 장기 마이그레이션

- 작업: 세션 토큰 호환성과 롤백 경계를 유지해야 하는 약 3시간의 인증 공급자 마이그레이션. 실패 영향이 높고 여러 모듈의 불변식을 함께 추적해야 한다.
- 활성 모델: `openai/gpt-5.6-terra`, effort `medium`.
- 후보: `openai/gpt-5.6-terra`, `openai/gpt-5.6-sol`, `anthropic/claude-opus-5`. 모두 runnable이고 하드 요구를 만족한다.
- 대표 eval: 같은 저장소 마이그레이션 10건에서 Terra 7/10, Sol 9/10, Opus 10/10 수용 조건 통과. 비용 제한 없음. eval은 현재 모델 버전으로 당일 실행했다.
- 기대: `anthropic/claude-opus-5` 전환, high confidence. project eval이 공식 역할과 문맥 이전 비용보다 우선한다.

### MF-2: 품질 기준을 충족한 반복 작업의 비용 최적화

- 작업: 완전히 명세된 800개 설정 파일의 기계적 키 이름 변경. 포맷 검사와 전체 회귀 테스트가 모든 결과를 판정한다. 처리량과 비용이 우선이다.
- 활성 모델: `anthropic/claude-opus-5`, host default effort.
- 후보: Opus 5, `anthropic/claude-haiku-4-5`, `openai/gpt-5.6-luna`. 모두 runnable이다.
- 대표 eval: 동일 변환 100건에서 세 후보 모두 100% 통과. Luna가 가장 낮은 비용·지연 등급, Haiku가 두 번째다.
- 기대: `openai/gpt-5.6-luna` 전환. 품질 기준 통과 뒤 economics로 결정하며 불필요한 두 번째 모델을 사용하지 않는다.

### MF-3: 하드 데이터 경계

- 작업: 비공개 고객 계약서를 분석하되 프로젝트 정책이 Anthropic 공급자만 허용한다.
- 활성 모델: `openai/gpt-5.6-sol`.
- 후보: Sol, `anthropic/claude-sonnet-5`. 둘 다 capability와 context 요구를 만족하고 runnable로 표시됐지만 공급자 정책은 별도 하드 제약이다.
- 대표 eval: 없음.
- 기대: Sol을 hard-filter하고 Sonnet 5를 선택한다. 공급자 문서만 근거이므로 confidence는 medium 이하이며 사용자에게 이미 정해진 정책을 다시 묻지 않는다.

### MF-4: 비슷한 후보와 문맥 연속성

- 작업: 현재 세션에서 Brief와 저장소 조사를 마친 일반 기능 구현. 되돌릴 수 있고 결정론적 테스트가 있다.
- 활성 모델: `anthropic/claude-sonnet-5`.
- 후보: Sonnet 5, `openai/gpt-5.6-terra`. 둘 다 runnable이며 공식 역할은 balanced다.
- 대표 eval: 같은 기능군에서 Sonnet 48/50, Terra 49/50 통과. 비용·지연 차이는 사용자가 중요하다고 정하지 않았고 표본 차이는 결론을 바꿀 만큼 크지 않다.
- 기대: Sonnet 5 유지. 낮거나 중간 confidence로 후보가 가깝고 문맥 이전 이득이 없음을 기록한다.

### MF-5: 권고와 실행 가능성 분리

- 작업: 장기 리팩터링. 현재 모델도 수용 조건을 충족할 수 있지만 대표 eval에서 다른 공급자 후보가 더 안정적이다.
- 활성 모델: `openai/gpt-5.6-sol`.
- 후보: Sol은 runnable, `anthropic/claude-opus-5`는 다음 실행에서만 사용 가능해 현재 `runnable = false`다.
- 대표 eval: Sol 8/10, Opus 10/10. 현재 실행에는 중간 상태와 도구 세션이 이미 있다.
- 기대: current-run primary는 Sol로 두고 계속 실행하며, `recommendation-only`의 next-run recommendation으로 Opus 5를 기록한다. 자동 외부 호출, 새 세션, 사용자 중단을 만들지 않는다.

### MF-6: 고정 모델과 상위 하드 제약의 충돌

- 작업: 비공개 고객 계약서를 분석하며 프로젝트 데이터 정책은 Anthropic 공급자만 허용한다.
- 활성·고정 모델: 사용자가 `openai/gpt-5.6-sol`을 이번 실행 모델로 고정했다.
- 후보: Sol과 `anthropic/claude-sonnet-5`가 host inventory에는 runnable로 표시된다.
- 대표 eval: 없음. 모델 성능과 관계없이 데이터 정책이 상위 하드 제약이다.
- 기대: pinned Sol을 hard-filter하고 `decision = blocked`, `primary = null`, `needs_user_input = true`로 기록해 실행하지 않는다. 사용자 고정을 보안·데이터 정책의 예외 권한으로 해석하지 않으며, 충돌 사유를 기록하고 사용자 방향을 기다린다.

## 실행 명령

두 실행 모두 저장소 규칙과 외부 도구 영향을 제외하고, `model-fit.md`와 이 문서의 상황만 입력한다. 정확한 모델 ID와 CLI 버전, 경과 시간, 출력 토큰 또는 보고 비용을 결과에 기록한다.

```text
Codex: codex exec --ephemeral --ignore-user-config --ignore-rules --skip-git-repo-check -m <current-codex-model> -s read-only
Claude: claude --print --model <current-claude-model> --effort <supported-effort> --safe-mode --tools "" --no-session-persistence
```

유료 또는 원격 실행 권한이 없으면 실행하지 않고 `NOT RUN`으로 기록한다. 구조 검사 통과를 행동 eval 통과로 표현하지 않는다.

## 결과

### 구조·계약 검사

| 상황 | 계약 판정 | 근거 |
|---|---|---|
| MF-1 | PASS | 최신 대표 eval이 현재 문맥 비용보다 큰 품질 차이를 증명하므로 Opus 5 전환이 허용된다. |
| MF-2 | PASS | 세 후보가 같은 품질 기준을 통과한 뒤에만 가장 효율적인 Luna를 선택한다. |
| MF-3 | PASS | 공급자 데이터 정책을 하드 필터로 먼저 적용하고 남은 Sonnet을 선택한다. |
| MF-4 | PASS | 48/50과 49/50 차이를 결정적 증거로 과장하지 않고 활성 Sonnet 문맥을 유지한다. |
| MF-5 | PASS | 현재 실행에서는 non-runnable Opus를 제거하고 Sol을 primary로 유지하되, 같은 버전의 대표 eval 근거는 next-run recommendation으로 보존한다. |
| MF-6 | PASS | 사용자의 모델 고정은 데이터 정책을 덮어쓰지 않으므로 Sol을 실행하지 않고 충돌을 명시한 뒤 방향을 기다린다. |

`tooling/tests/model_fit_test.sh`가 여섯 상황의 선언적 기대 결과와 정책의 실행 조건, 고정·단일 후보 경계, 하드 필터, effort·confidence, 대표 eval 우선, 문맥 연속성, 품질 기준 후 비용 최적화, 권고·실행 권한 분리, 검증 책임 경계, 문서 동기화, 로컬 후보 확장 계약을 결정론적으로 검사한다. 이 검사는 정책과 fixture가 서로 일치하는지 확인할 뿐, 실제 모델이 상황을 올바르게 판정한다는 행동 증거로 간주하지 않는다.

### 외부 실행

Codex와 Claude에 같은 정책·상황을 한 번씩 전달하는 읽기 전용 batch를 준비했지만, 저장소 내용의 외부 전송과 유료 요청에 대한 별도 권한이 없어 승인 경계에서 실행되지 않았다. 사용할 수 있는 모델 출력, 경과 시간, 토큰, 비용 결과는 수집하지 않았다.

## 결론과 남은 위험

- 구조·계약 검사는 통과했지만 실제 Codex·Claude 행동 eval은 실행되지 않았다.
- 여섯 상황은 라우팅 계약의 경계 사례이며 실제 프로젝트 전체 성공률을 증명하지 않는다.
- 모델이나 CLI가 갱신되면 같은 상황을 다시 실행하고, 실제 기능 작업의 수용 조건 누락·총비용·지연을 별도 추적한다.
