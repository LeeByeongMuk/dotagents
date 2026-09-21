# ADR 0004: 검사 범위와 자리표시자 디렉터리

- 날짜: 2026-09-17
- 상태: ACCEPTED

## 맥락

- `tooling/tests/structure_test.sh`는 `grep -F` 67개로 구조를 검사했고 그중 49개가 `SKILL.md`와 참조 문서의 정확한 영어 문장을 고정했다. 문장을 다듬기만 해도 테스트가 깨져, ADR 0002가 요구하는 규칙·스킬 정리를 사실상 막았다.
- 같은 검사가 회귀는 잡지 못했다. 고정된 문장을 그대로 둔 채 의미를 뒤집는 문장을 추가해도 통과한다.
- 라우팅, 구현 승인, 권위 원본 처리, 질문 수, 서브에이전트 수, 수용 조건과 결정론적 검사 개수는 `tooling/evals/product-development/cases.json`의 13개 사례가 이미 측정한다.
- Model Fit 정책과 대표 시나리오는 `tooling/tests/model_fit_test.sh`가 40개 이상의 절로 검사하는데, `structure_test.sh`가 같은 파일의 같은 문자열 일부를 다시 검사했다.
- `agents/routing/`, `prompts/`, `skills/wrappers/`, `integrations/`의 하위 네 디렉터리는 README 한 개씩만 있고 자산이 없었다. `structure_test.sh`가 이를 필수로 강제해 빈 구조가 고정됐다. `agents/routing/README.md`는 스킬의 라우팅 규격을 한국어로 재진술해 `documentation.md`의 단일 원본 규칙도 어겼다.

## 결정

1. 행동은 eval이, 구조와 결정은 테스트가 소유한다. eval 사례가 측정하는 속성은 테스트에서 문자열로 고정하지 않는다.
2. 테스트에 남기는 `grep`은 문구가 아니라 eval이 관측하지 않는 결정을 고정한다. 한 계약은 한 테스트만 검사하고 다른 테스트는 중복하지 않는다.
3. 빈 자리표시자 디렉터리는 두지 않는다. 자산이 생길 때 디렉터리를 함께 만들고, 그전까지는 규격만 문서에 적는다.

## 버린 대안

- 산문 고정을 전부 제거: 메모리 자동 주입 금지, 호스트 참조 상호배타처럼 eval 스키마가 관측하지 않는 결정까지 잃는다.
- 스킬 문장을 테스트에 맞춰 고정 유지: 문맥 비용을 줄이려는 모든 후속 작업이 테스트 수정을 동반하게 된다.

## 결과

- `structure_test.sh`의 `grep -F`가 67개에서 46개로 줄었다. 문구만 바꾼 변경은 통과하고, 결정을 뒤집는 변경은 계속 실패한다.
- `agents/routing/`, `agents/prompts/`, `agents/skills/wrappers/`, `agents/integrations/{skills,mcp,plugins,tools}`를 제거했다. 연동 규격은 `agents/integrations/README.md` 한 곳으로 합쳤고, 라우팅 규격의 원본은 스킬의 description과 라우팅 절이다.
- `tooling/schemas/`도 같은 이유로 제거했다. 소비자 없이 형식을 고정하지 않는다는 원칙은 `README.md`가 유지한다.
- `agents/profiles/`는 ADR 0003이 생성기의 확장 지점으로 명시해 유지한다. `agents/registry/skills.toml`의 `profiles` 필드가 이를 참조한다.
- 스킬과 규칙의 중복 문장은 이번 범위에서 손대지 않는다. eval 하네스가 `--ignore-rules`로 스킬만 단독 급여하므로 중복이 계약의 일부일 수 있고, ADR 0002 3항에 따라 측정 후에만 바꾼다.
