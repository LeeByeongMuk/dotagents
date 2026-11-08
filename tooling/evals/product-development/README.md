# 제품 워크플로우 교차 호스트 eval

Codex와 Claude Code에 같은 사례와 같은 결과 스키마를 제공하고, 내부 도구 순서가 아니라 제품 워크플로우 계약을 비교합니다. 기본 저장소 검사는 `fixtures/`의 고정 결과만 채점하며 실제 모델을 호출하지 않습니다.

## 평가 계약

- 올바른 `direct / plan / lean` 경로
- 구현 권한 준수
- 기존 제품 원본 재사용 또는 fallback 생성 결정
- 불필요한 질문과 서브에이전트 억제
- 제품 작업의 수용 조건과 구현 작업의 결정론적 검사 필드·최소 개수 보존
- 가능한 경우 입력·출력·reasoning 또는 thinking·캐시 읽기·캐시 쓰기 토큰, 지연, 비용 수집

`cases.json`의 12개 사례가 기본 라우팅, 제품 탐색·사실 조사·기획 후 구현·고위험 기획·요청된 기획 문서 갱신, 권위 원본의 재사용·생성·링크, 차단 결정 질문, 키워드 없는 공식 증거 경계를 소유하고, `case-contract.jq`가 안전한 사례 ID와 정확한 입력 필드를 검증합니다. `decision.schema.json`은 두 모델이 반환할 동일한 구조입니다. `implementation_authorized`는 제품·기능 구현 권한을, `file_changes_authorized`는 작은 수정이나 기획 문서 갱신을 포함한 모든 로컬 파일 변경 권한을 뜻합니다. `run.sh`는 공급자별 CLI 출력을 모델과 검증된 effort를 포함한 공통 JSONL로 정규화하며 `score.sh`가 결과를 채점합니다. 실행기와 채점기는 Codex의 `none|low|medium|high|xhigh|max|ultra`, Claude의 `low|medium|high|xhigh|max`를 허용합니다. 실제 사용 가능 여부는 선택한 모델과 CLI가 결정하며, Codex의 `none`·`ultra`는 Claude 결과로 기록할 수 없습니다.

## 실제 실행

명시적 실행은 설치된 CLI와 해당 계정의 모델 사용량을 소비합니다. 결과 파일은 저장소 밖이나 Git에서 제외된 임시 경로에 두는 것을 권장합니다.

```bash
tooling/evals/product-development/run.sh \
  --provider codex \
  --model gpt-5.6-sol \
  --effort medium \
  --output /tmp/product-workflow-codex.jsonl

tooling/evals/product-development/run.sh \
  --provider claude \
  --model claude-opus-5 \
  --effort medium \
  --output /tmp/product-workflow-claude.jsonl

tooling/evals/product-development/score.sh \
  --require-all \
  /tmp/product-workflow-codex.jsonl \
  /tmp/product-workflow-claude.jsonl
```

한 사례만 확인하려면 `--case plan-only`처럼 지정하고 `score.sh`에서는 `--require-all`을 생략합니다. `--list`는 모델을 호출하지 않고 사례 ID만 출력합니다.

기존 출력 파일은 기본적으로 덮어쓰지 않습니다. 같은 경로를 의도적으로 교체할 때만 `--force`를 추가하며, 이 경우에도 모든 모델 실행이 성공하기 전까지 기존 파일을 보존합니다. 출력 디렉터리는 미리 존재해야 하고 저장소 내부 경로와 심볼릭 링크는 거부됩니다. 안전한 배타·원자 게시에는 Perl의 `link(2)`·`rename(2)`를 사용하므로 `jq`와 SHA-256 도구 외에 `perl`이 필요합니다. 결과에는 adapter revision과 공유 harness·사례·스키마·라우팅 프롬프트·두 호스트 참조의 SHA-256 출처가 포함되며, 채점기는 다른 버전의 결과를 섞거나 현재 계약과 다른 결과를 재사용하면 실패합니다. `--require-all`은 정확히 Codex와 Claude의 전체 등록 사례를 요구하며 빈 결과나 한 공급자만 있는 결과는 실패합니다.

두 호스트 모두 모델 도구를 끈 분류 실행으로 맞춥니다. Claude는 `--tools ""`를 사용하고, Codex는 shell·unified exec·앱·웹 검색·이미지 읽기·subagent를 비활성화합니다. 실행 시작 시 harness·사례·스키마·라우팅 프롬프트·두 호스트 참조를 임시 디렉터리에 복사하고, 모든 사례가 이 고정 스냅샷만 읽습니다. `--harness`와 저장소의 사례 파일은 프롬프트 본문이므로 신뢰하는 로컬 입력만 사용합니다.

## 모델 행동 eval

`behavior.sh`는 라우팅이 아니라 실행 결정을 잰다. 같은 공통 스킬과 지정한 호스트 참조를 모델에 주고, `behavior/scenarios.json`의 `routine`·`long_run` 두 상황에서 권위 원본 재사용, 실행 전 중단, 서브에이전트, 모델 생성 검토 종류를 `behavior/decision.schema.json` 구조로 받는다. 채점기는 없고, 호스트 참조 변형(`--host-reference`)과 모델 사이의 결과를 `jq`로 비교한다. 호스트 참조나 모델별 지시를 바꿀 때 변경 전후를 같은 모델·effort로 실행해 `docs/evals/product-development-workflow-model-behavior.md`에 기록한다.

```bash
tooling/evals/product-development/behavior.sh \
  --provider claude \
  --model claude-fable-5-1 \
  --effort medium \
  --label current \
  --output /tmp/behavior.jsonl

tooling/evals/product-development/behavior.sh \
  --provider claude \
  --model claude-fable-5-1 \
  --effort medium \
  --host-reference /tmp/claude-code.candidate.md \
  --label candidate \
  --output /tmp/behavior.jsonl
```

Claude 실행은 Claude Code 세션 안에서도 동작하도록 `CLAUDECODE` 환경 변수를 지우고 호출한다. 출력 경로는 `run.sh`와 같이 저장소 밖 절대 경로여야 한다.

## 비교 원칙

결과 계약을 통과한 실행끼리 토큰·지연·비용을 비교합니다. 더 적은 호출이나 토큰을 품질 개선으로 단독 판정하지 않습니다. 모델·effort·스킬 변경은 한 묶음씩 바꾸고 같은 사례를 다시 실행합니다.

채점기는 사례별 판정과 함께 통과한 공급자별 `TOTAL` 행에 입력, 캐시 읽기, 캐시 쓰기, 출력, 지연, 비용 합계를 표시합니다. 공급자별 `input_tokens`가 캐시 입력을 포함하는 방식은 같지 않을 수 있으므로 원시 입력 수치를 직접 비교하지 않습니다. `cache_read_tokens`와 `cache_write_tokens`도 서로 합산하지 않고, 동일 공급자·모델·effort의 변경 전후 비교를 우선합니다.

자동 채점은 경로·권한·권위 원본 동작·질문/서브에이전트 한도와 증거 배열의 형식·최소 개수를 판정합니다. 수용 조건과 검사의 시나리오 적합성은 JSON 구조만으로 의미 판정하지 않으므로 실제 결과 검토나 별도 semantic judge가 필요한 수동 항목입니다.
