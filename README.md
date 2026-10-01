# dotagents

Claude Code, Codex, Gemini에서 함께 쓰는 개인 AI 개발 운영체계의 단일 원본입니다. 공통 규칙, 워크플로우, 직접 만든 스킬, 훅, 외부 연동 규격과 도구별 어댑터를 한 저장소에서 관리하고 여러 프로젝트에 재사용합니다.

현재는 구조와 설치 기반뿐 아니라 기획 전용 `Plan`과 구현용 `Brief → Execute → Verify`를 구분하는 제품 개발 워크플로우를 제공합니다. 구현 경로에서 여러 모델을 실행할 수 있으면 Brief 이후 Claude·Codex 후보의 Model Fit을 판단하고, 두 호스트는 같은 제품 결과 계약을 공유하면서 각자의 검증 참조만 읽습니다. 기존 10단계 계약은 감사·고위험 작업의 선택 경로로 보존합니다. 실제 훅·MCP 설정 생성, 외부 스킬 자동 동기화와 프로필 합성은 후속 범위입니다.

## 원칙과 우선순위

적용 우선순위는 **프로젝트 고유 규칙 → 도구 전용 설정 → 개인 공통 기본 규칙**입니다. 공통 설정은 프로젝트가 선택한 프레임워크, 패키지 매니저, 테스트 도구, 브랜치 정책을 바꾸지 않습니다.

- `agents/`는 사람이 편집하는 모든 AI 자산의 단일 원본(SSOT)입니다.
- `tooling/`은 설치, 생성, 갱신, 진단, 검증을 담당합니다.
- `docs/`는 구조를 넘어서는 긴 설명과 설계 결정을 보관합니다.
- `dist/`는 원본에서 생성한 도구별 최종본을 위한 출력 영역입니다.
- 행동과 설명은 Markdown으로, 목록·버전·프로필 같은 기계 판독 정보는 TOML로 관리합니다.
- 비밀 값과 로컬 세션 상태는 저장소에 넣지 않습니다.

## 저장소 구조

루트는 원본, 관리 도구, 문서, 생성 결과만 드러내도록 작게 유지합니다.

```text
.
├── AGENTS.md
├── README.md
├── dotagents.toml                 # 저장소 레이아웃 메타데이터
├── agents/                        # 모든 공통 AI 자산의 원본
│   ├── rules/                     # 행동·코딩·Git·보안 규칙
│   ├── workflows/                 # 여러 스킬을 조합한 개발 절차와 실행 계약
│   ├── skills/
│   │   └── owned/                 # 직접 만든 스킬(제품 개발 오케스트레이터 포함)
│   ├── hooks/                     # 세션·도구·출하 수명주기 훅 규격
│   ├── profiles/                  # 프로젝트 유형별 구성 조합
│   ├── integrations/              # 외부 스킬·MCP·플러그인·도구 연동 규격
│   ├── adapters/
│   │   ├── claude/                # Claude Code 진입 파일과 설정 예제
│   │   ├── codex/                 # Codex 진입 파일과 설정 예제
│   │   └── gemini/                # Gemini CLI 진입 파일
│   ├── registry/                  # 외부 자산 목록과 버전 잠금
│   └── templates/                 # 범용·스택별 프로젝트 템플릿
├── tooling/
│   ├── scripts/                   # 설치·제거·검증 명령
│   └── tests/                     # 격리 설치·구조·회귀 테스트
├── docs/
│   └── decisions/                 # 장기 설계 결정 기록
└── dist/                          # 생성된 Claude/Codex/Gemini 최종본
```

빈 자리표시자 디렉터리는 두지 않습니다. 레지스트리 스키마나 프로필 조합처럼 소비자가 아직 없는 영역은 첫 소비자와 함께 디렉터리를 만들고, 그전까지는 규격만 문서에 적습니다. 라우팅 규격의 원본은 `agents/skills/owned/product-development-workflow/SKILL.md`의 description과 라우팅 절입니다.

## 영역별 규격

### Rules and workflows

- 범용 규칙은 `agents/rules/<topic>.md`에 작고 독립적인 문서로 둡니다.
- 규칙에는 모델이 스스로 알 수 없는 정보만 적습니다. 판정 기준은 `docs/decisions/0002-rule-authoring-criterion.md`에 있습니다.
- 호스트 진입점은 `tooling/scripts/build.sh`가 어댑터와 규칙을 합쳐 `dist/`에 생성하고 설치는 그 결과를 링크합니다. 규칙을 고치면 `make build`를 실행합니다.
- 라우팅 규격은 별도 디렉터리가 아니라 스킬의 description과 라우팅 절이 원본입니다. 요청의 종류, 제품 결정의 필요성, 위험과 증거 요구에 따라 워크플로우 또는 단일 스킬을 선택합니다.
- 워크플로우는 `agents/workflows/<name>/` 아래에 사람용 `WORKFLOW.md`와 기계 판독용 `workflow.toml`을 함께 둘 수 있습니다.
- 워크플로우는 진입 조건, 단계, 입력·출력 산출물, 사용자 승인 지점, 실패·복구 방법, 선택 단계를 명시합니다.

간단한 수정에 전체 프로세스를 강제하지 않습니다. 예를 들어 오타 수정은 구현과 검증만, 버그는 조사와 회귀 테스트를, 큰 기능은 문제 정의부터 계획·구현·QA·회고까지 실행할 수 있어야 합니다.

### Skills

- 직접 만든 스킬은 `agents/skills/owned/<name>/SKILL.md`에 둡니다.
- 외부 스킬을 수정하지 않고 보정해야 하면 그때 `agents/skills/wrappers/<name>/SKILL.md`를 만듭니다.
- 외부 원본 자체는 복사하지 않고 `agents/registry/skills.toml`과 `sources.lock`에 출처와 고정 버전을 기록합니다.

### Hooks

훅은 세션 시작, 도구 실행 전후, 커밋 전, 출하 전, 컨텍스트 복구 같은 수명주기 작업을 담당합니다. 각 훅은 실행 조건, 지원 호스트, 부작용, 실패 정책을 명시하고 `agents/registry/hooks.toml`에 등록합니다.

훅은 로컬 명령을 실행할 수 있는 신뢰 경계입니다. 검토되지 않은 외부 훅을 자동 활성화하지 않습니다.

### Integrations and registry

`agents/integrations/`에는 외부 자산의 전체 복사본이 아니라 설치 방법, 설정 템플릿, health check, 호스트별 차이와 로컬 wrapper를 둡니다.

- `skills.toml`: 내부·외부 스킬 ID, 출처, 지원 호스트, 적용 프로필
- `mcp.toml`: MCP 용도, transport, 필요한 환경 변수 이름, 권한과 health check
- `hooks.toml`: 훅 이벤트, 실행 항목, 지원 호스트, 기본 활성화 정책
- `plugins.toml`: 외부 플러그인 출처, 버전, 설치 대상
- `sources.lock`: 실제로 검토한 태그나 커밋을 고정하는 잠금 파일

API 키, 토큰, 쿠키, 실제 endpoint 인증값은 레지스트리에 넣지 않습니다. `GITHUB_TOKEN`처럼 필요한 환경 변수의 이름만 기록합니다.

### Profiles, adapters, dist

프로필은 `minimal`, `default`, `full`, `nextjs`처럼 규칙·스킬·훅·연동 묶음을 선택하는 단위입니다. 프로젝트는 프로필을 선택한 뒤 로컬 규칙으로 필요한 차이만 덮어씁니다.

어댑터는 공통 원본을 Claude Code, Codex, Gemini의 진입 형식으로 연결합니다. `tooling/scripts/build.sh`가 얇은 어댑터와 `agents/rules/`의 공통 규칙을 합쳐 `dist/<호스트>/`에 최종본을 만들고, 설치기는 그 최종본을 호스트 진입점에 링크합니다. 호스트가 규칙 문서를 따로 읽지 않아도 규칙이 적용되도록 하기 위해서입니다. 프로필과 프로젝트 override 합성은 아직 생성기에 들어 있지 않습니다.

```text
agents/rules/ 공통 규칙
  + host adapter
        |
        +--> dist/claude/CLAUDE.md
        +--> dist/codex/AGENTS.md
        +--> dist/gemini/GEMINI.md
```

`dist/` 파일은 직접 편집하지 않고 원본을 수정한 뒤 다시 생성합니다.

## 현재 제공 기능과 후속 작업

현재 저장소가 제공하는 것은 다음과 같습니다.

- 공통 규칙과 도구별 얇은 어댑터
- 어댑터와 공통 규칙을 합쳐 호스트 진입점을 만드는 `dist/` 생성기와 최신 여부 검사
- 범용 및 Next.js 프로젝트 템플릿
- 모듈의 현재 상태를 기술하는 살아있는 컨텍스트 문서 규약과 템플릿(`agents/templates/context-docs/`)
- 전역·프로젝트 심볼릭 링크 설치와 안전한 제거
- 충돌 감지, 강제 설치 전 백업, 제거 시 복구
- 저장소 이동과 내부 경로 변경 후 재설치 복구
- 구조, 비밀 패턴, 셸 문법과 설치 시나리오 검증
- 하나의 살아 있는 제품 Brief와 자율 실행, 결정론적 검증을 잇는 기본 제품 개발 워크플로우
- 호스트가 제공하는 Claude·Codex 후보를 하드 제약, 프로젝트 eval, 문맥 연속성, 비용·지연 순으로 비교하는 조건부 Model Fit 권고
- 감사·고위험 작업을 위한 단계별 한국어 산출물, 명시적 승인, 중단 후 재개의 10단계 호환 경로
- Claude Code, Codex, Gemini의 공통 스킬 발견과 전역·프로젝트 워크플로우 CLI
- 세션에서 발견한 공통 관례를 격리 브랜치로 승격 제안·반영하는 `dotagents-promote` 스킬
- owned/external 스킬 목록과 검토한 외부 소스 커밋 잠금

다음 항목은 구조만 예약되어 있거나 아직 자동 실행 기능이 아닙니다.

- 외부 스킬·플러그인 다운로드와 버전 갱신
- MCP 설정 생성과 health check
- Codex·Gemini 커밋 메시지 훅 연결
- 프로필과 프로젝트 override 합성

## 설치

### 필수 도구

이 저장소의 스크립트는 `git`, `bash`, `jq`, `ripgrep`(`rg`)을 사용합니다. `gh`는 소스 검증과 PR 작업에만 필요합니다. `rg`가 없으면 `check.sh`의 비밀 값 검사가 동작하지 않으므로 검사기가 바로 실패합니다.

```bash
make deps     # macOS Homebrew로 설치
make doctor   # 설치 상태 진단
```

`make help`로 나머지 타깃(`build`, `check`, `test`, `install`, `uninstall`)을 볼 수 있습니다. 규칙이나 어댑터를 고친 뒤에는 `make build`로 `dist/`를 다시 만듭니다. 잊으면 `make check`가 잡습니다.

### 전역 설치

먼저 저장소를 원하는 위치에 clone한 뒤 반드시 dry-run을 확인합니다.

```bash
cd /path/to/dotagents
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global
```

전역 모드는 다음 링크를 만듭니다.

- `~/.agents` → 이 저장소의 `agents/`
- `~/.claude/CLAUDE.md` → `dist/claude/CLAUDE.md`
- `~/.claude/settings.json` → `agents/adapters/claude/settings.json`
- `~/.claude/skills/product-development-workflow` → owned 워크플로우 스킬
- `~/.claude/skills/dotagents-promote` → owned 승격 스킬
- `~/.codex/AGENTS.md` → `dist/codex/AGENTS.md`
- `~/.gemini/GEMINI.md` → `dist/gemini/GEMINI.md`
- `~/.local/bin/dotagents-workflow` → 워크플로우 상태 명령

Codex와 Gemini는 `~/.agents/skills/` 별칭에서 같은 owned 스킬을 발견합니다. `~/.local/bin`이 `PATH`에 없으면 설치기가 경고하며 전체 경로로 실행할 수 있습니다.

기존 대상이 있으면 기본 동작은 충돌을 표시하고 아무것도 변경하지 않는 것입니다. `--force`는 기존 항목을 타임스탬프가 붙은 형제 경로로 백업한 뒤 설치합니다. 실제 설정을 먼저 검토하지 않은 상태에서는 `--force`를 사용하지 마세요.

```bash
./tooling/scripts/install.sh --dry-run --global --force
```

### 프로젝트에 적용

```bash
./tooling/scripts/install.sh --dry-run --project /path/to/project
./tooling/scripts/install.sh --project /path/to/project
```

프로젝트 모드는 `.agents`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude/skills/product-development-workflow`, `.claude/skills/dotagents-promote`, `.dotagents/bin/dotagents-workflow` 링크를 설치합니다. Codex와 Gemini는 프로젝트의 `.agents/skills` 별칭을 사용합니다. 기존 프로젝트 파일이 있으면 중단하므로 그 파일을 유지하면서 공통 규칙 경로만 직접 참고하거나, 내용을 검토한 뒤 명시적으로 `--force`를 사용해야 합니다.

프로젝트 고유 규칙을 새로 작성할 때는 템플릿을 복사해 실제 상황에 맞게 수정하세요.

```bash
cp agents/templates/generic/AGENTS.md /path/to/project/AGENTS.md
# 또는
cp agents/templates/nextjs/AGENTS.md /path/to/project/AGENTS.md
```

Next.js 템플릿은 기술 선택을 자동으로 가정하지 않습니다. FSD를 실제로 채택한 프로젝트만 `agents/templates/nextjs/fsd-optional.md`를 참고하세요.

## 제품 개발 워크플로우 사용

지원 호스트에서 다음처럼 요청합니다.

```text
$product-development-workflow 로 이 아이디어를 Brief부터 구현 검증까지 진행해줘.
```

### Next.js 스타터 킷에서 사용하기

여러 프로젝트에 반복 사용할 예정이라면 dotagents를 한 번 전역 설치한 뒤 대상 프로젝트에서 에이전트를 실행하는 방식이 가장 간단합니다.

```bash
cd /path/to/dotagents
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global

cd /path/to/nextjs-starter-kit
# 여기서 Codex, Claude Code 또는 Gemini를 실행
```

기획만 필요하면 다음처럼 요청합니다. 이 경로는 별도 요청 없이 파일이나 구현을 변경하지 않습니다.

```text
$product-development-workflow 로 인증 기능을 조사하고 기획안만 만들어줘. 구현은 하지 마.
```

기존 사실을 찾아 설명하는 조사는 제품 기획이 아니므로 `direct`로 처리합니다. 반대로 제품 문제·요구사항·대안을 결정하는 조사는 `plan`이며, 같은 요청에 구현까지 명시하면 `lean`으로 이어집니다.

구현까지 필요하면 다음처럼 요청합니다.

```text
$product-development-workflow 로 이 Next.js 스타터 킷에 인증 기능을 추가해줘. Brief부터 구현 검증까지 진행해줘.
```

스킬은 현재 PRD·이슈·스펙이 제품 결정의 권위 원본이면 그것을 Brief로 재사용하고 fallback 템플릿을 읽지 않습니다. 적합한 원본이 없을 때만 템플릿을 읽어 프로젝트 안에 `docs/workflows/<run-id>/brief.md`를 만들며, 외부·읽기 전용 원본은 링크하고 실행 체크포인트와 검증 증거만 로컬에 기록합니다. 이미 전역 설치했다면 설치 명령은 다시 실행할 필요가 없습니다. 대상 프로젝트의 `AGENTS.md` 같은 고유 규칙이 공통 규칙보다 우선합니다.

워크플로우는 작은 수정에는 적용하지 않고, 구현이 승인된 일반 제품 개발에는 다음 경로를 실행합니다.

```text
Brief → Execute → Verify
```

주 에이전트가 전체 문맥에서 계획과 도구를 자율적으로 선택하고, 외부 스킬·멀티에이전트·RAG는 실제 필요가 있을 때만 사용합니다. 실행 가능한 모델 후보가 둘 이상이면 Brief를 바탕으로 Model Fit을 한 번 판단합니다. 현재 모델을 기본값으로 두고, 하드 제약이나 대표 eval처럼 문맥 이전 비용을 상쇄할 근거가 있을 때만 정확한 모델·effort 전환을 권고합니다. 호스트가 전환을 지원하지 않으면 현재 실행을 계속하고 다음 실행 권고로 기록하며, 유료 benchmark나 다른 공급자 호출을 자동 시작하지 않습니다.

초기 Model Fit 정책은 Claude와 Codex/OpenAI 모델 계열을 지원합니다. 후보 형식은 공급자 중립이므로 로컬 LLM도 같은 가용성·도구·데이터 경계·비용·eval 필드를 제공하면 이후 추가할 수 있습니다. `AC-<번호>` 수용 조건은 구현과 검증 증거까지 연결하고, Codex는 Codex 검증 참조만, Claude Code는 Claude 검증 참조만 읽습니다. 검증은 프로젝트 테스트·정적 검사·빌드처럼 판정 가능한 증거를 우선하며, 모델이 생성하는 추가 검토는 실제 활성 모델과 작업 길이에 맞춰 조건부로 적용합니다.

규제, 민감한 보안 경계, 비가역 마이그레이션, 공식 팀 승인처럼 단계 증거가 필요하면 `audited` 경로를 명시적으로 요청합니다.

```text
$product-development-workflow 의 audited 경로로 이 마이그레이션을 진행해줘.
```

이때만 기존 상태 CLI를 사용합니다.

```bash
dotagents-workflow start --project /path/to/project --run feature-name --scope substantial
dotagents-workflow status --project /path/to/project --run feature-name
```

감사형 산출물은 `<project>/docs/workflows/<run-id>/`에 단계별 한국어 `.md`로 저장되며 사용자 승인 뒤 SHA-256으로 고정됩니다. 기본 living Brief에는 이 불변 정책을 적용하지 않습니다. 자세한 라우팅, 복구와 완료 검증은 [제품 개발 워크플로우 사용서](agents/workflows/product-development/WORKFLOW.md)를 참고하세요.

## 제거

설치 매니페스트에 기록되고 현재도 같은 원본을 가리키는 링크만 제거합니다. `--force` 설치 때 만든 백업은 대상 경로가 비어 있을 때 복원합니다. 사용자가 링크를 다른 대상으로 바꿨다면 건너뜁니다.

```bash
./tooling/scripts/uninstall.sh --dry-run --global
./tooling/scripts/uninstall.sh --global

./tooling/scripts/uninstall.sh --dry-run --project /path/to/project
./tooling/scripts/uninstall.sh --project /path/to/project
```

전역 매니페스트는 `${XDG_STATE_HOME:-$HOME/.local/state}/dotagents/install.tsv`, 프로젝트 매니페스트는 `<project>/.dotagents-install.tsv`입니다.

## 검증

```bash
make doctor
bash -n tooling/scripts/install.sh
bash -n tooling/scripts/uninstall.sh
bash -n tooling/scripts/check.sh
bash -n tooling/scripts/workflow.sh
./tooling/scripts/install.sh --dry-run
./tooling/scripts/uninstall.sh --dry-run
./tooling/scripts/check.sh
./tooling/scripts/check-sources.sh
./tooling/tests/install_test.sh
./tooling/tests/model_fit_test.sh
./tooling/tests/structure_test.sh
./tooling/tests/workflow_test.sh
./tooling/tests/sources_test.sh
./tooling/tests/hooks_test.sh
```

`check.sh`는 필수 구조, 스킬 규격, 깨진 링크, 셸 문법, 저장소 경로 하드코딩, 의심되는 비밀 패턴·파일명, 어댑터의 공통 규칙 중복, 레지스트리 기본 형식, 워크플로우 계약과 설치 dry-run을 검사합니다. `check-sources.sh`는 별도의 네트워크 검사이며 GitHub CLI 인증이 필요합니다. 탐지 시 비밀 값은 출력하지 않습니다.

## 자산 추가

- 공통 규칙: `agents/rules/<topic>.md`
- 워크플로우: `agents/workflows/<name>/WORKFLOW.md`, `workflow.toml`
- 직접 만든 스킬: `agents/skills/owned/<name>/SKILL.md`
- 외부 스킬 wrapper: `agents/skills/wrappers/<name>/SKILL.md`
- 훅: `agents/hooks/<name>/`
- 외부 연동: `agents/integrations/<kind>/<name>/`
- 도구별 동작: `agents/adapters/<host>/`
- 프로젝트 템플릿: `agents/templates/<profile>/`

사람이 읽는 문서는 한국어 단일본으로 관리합니다. `SKILL.md`, `AGENTS.md`, TOML처럼 에이전트나 기계가 직접 실행하는 계약도 단일 원본으로 유지합니다.

새 자산은 특정 프로젝트 경로, 비밀, 비공개 조직 정보, 불필요하게 고정된 도구 버전을 포함하지 않아야 합니다.

## 비밀 정보

API 키, 토큰, 쿠키, 세션, 개인 키, 실제 MCP 인증 정보, 비공개 조직 정보는 커밋하지 않습니다. `.env.example` 같은 예제에는 `OPENAI_API_KEY=<your-api-key>`처럼 자리표시자만 사용하세요. `.gitignore`와 `check.sh`는 실수를 줄이는 보조 장치일 뿐이므로 커밋 전 diff를 직접 검토해야 합니다.

## 새 컴퓨터에서 복원

```bash
git clone <your-dotagents-repository-url> ~/Documents/GitHub/dotagents
cd ~/Documents/GitHub/dotagents
./tooling/scripts/check.sh
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global
```

clone 위치나 저장소 내부 어댑터 경로가 바뀌면 기존 절대 심볼릭 링크는 이전 위치를 가리킬 수 있습니다. 새 위치에서 같은 설치 명령을 다시 실행하면 dotagents가 소유한 링크를 새 원본으로 갱신합니다. 다른 기존 파일은 자동 변경하지 않습니다.

## 알려진 제한 사항

- 도구가 Markdown의 다른 파일을 자동 include하는 방식이 서로 다릅니다. 그래서 규칙 본문을 호스트 진입점에 함께 넣어 생성합니다. 규칙을 고친 뒤 `make build`를 실행하지 않으면 설치된 진입점이 낡은 채로 남습니다.
- 기존 설정 파일과 구조적으로 병합하지 않습니다. 충돌을 중단하거나 `--force` 백업으로 처리합니다.
- Windows는 지원하지 않습니다.
- 전역 설치는 Claude `settings.json`을 링크하므로 `bypassPermissions` 기본 모드와 커밋 메시지 훅이 함께 켜집니다. Codex `config.toml`과 Gemini 설정은 설치하지 않으며 `settings.example.json` 같은 예제도 자동 설치하지 않습니다.
- 스킬 레지스트리는 검토 목록과 잠금 기록이며 외부 자산 자동 설치에는 아직 사용하지 않습니다. 프로필과 MCP는 아직 설치기에서 합성하지 않습니다.

## 라이선스

MIT License. 자세한 내용은 `LICENSE`를 참고하세요.
