# dotagents

Claude Code, Codex, Gemini에서 함께 쓰는 개인 AI 개발 운영체계의 단일 원본입니다. 공통 규칙, 워크플로우, 직접 만든 스킬, 프롬프트, 훅, 외부 연동 규격과 도구별 어댑터를 한 저장소에서 관리하고 여러 프로젝트에 재사용합니다.

현재는 구조와 설치 기반뿐 아니라 기획 하네스를 필수로 두는 `Brief → Execute → Verify` 제품 개발 워크플로우를 제공합니다. 기존 10단계 계약은 감사·고위험 작업의 선택 경로로 보존합니다. 실제 훅·MCP 설정 생성, 외부 스킬 자동 동기화와 프로필 합성은 후속 범위입니다.

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
│   ├── routing/                   # 요청을 워크플로우와 스킬로 연결하는 규격
│   ├── workflows/                 # 여러 스킬을 조합한 개발 절차와 실행 계약
│   ├── skills/
│   │   ├── owned/                 # 직접 만든 스킬(제품 개발 오케스트레이터 포함)
│   │   └── wrappers/              # 외부 스킬의 로컬 보정 계층
│   ├── prompts/                   # 재사용 프롬프트
│   ├── hooks/                     # 세션·도구·출하 수명주기 훅 규격
│   ├── profiles/                  # 프로젝트 유형별 구성 조합
│   ├── integrations/
│   │   ├── skills/                # gstack, Superpowers 등 외부 스킬 연동
│   │   ├── mcp/                   # 외부 MCP 연동
│   │   ├── plugins/               # 외부 플러그인 연동
│   │   └── tools/                 # 브라우저·CLI 등 외부 도구 연동
│   ├── adapters/
│   │   ├── claude/                # Claude Code 진입 파일과 설정 예제
│   │   ├── codex/                 # Codex 진입 파일과 설정 예제
│   │   └── gemini/                # Gemini CLI 진입 파일
│   ├── registry/                  # 외부 자산 목록과 버전 잠금
│   └── templates/                 # 범용·스택별 프로젝트 템플릿
├── tooling/
│   ├── scripts/                   # 설치·제거·검증 명령
│   ├── schemas/                   # 향후 TOML/JSON 스키마
│   └── tests/                     # 격리 설치·구조·회귀 테스트
├── docs/
│   └── decisions/                 # 장기 설계 결정 기록
└── dist/                          # 생성된 Claude/Codex/Gemini 최종본
```

`tooling/schemas/`는 첫 기계 판독 설정 소비자와 함께 추가합니다. 소비자 없이 스키마만 미리 고정하지 않습니다.

## 영역별 규격

### Rules, routing, workflows

- 범용 규칙은 `agents/rules/<topic>.md`에 작고 독립적인 문서로 둡니다.
- 라우팅은 요청의 종류, 제품 결정의 필요성, 위험과 증거 요구에 따라 워크플로우 또는 단일 스킬을 선택합니다.
- 워크플로우는 `agents/workflows/<name>/` 아래에 사람용 `WORKFLOW.md`와 기계 판독용 `workflow.toml`을 함께 둘 수 있습니다.
- 워크플로우는 진입 조건, 단계, 입력·출력 산출물, 사용자 승인 지점, 실패·복구 방법, 선택 단계를 명시합니다.

간단한 수정에 전체 프로세스를 강제하지 않습니다. 예를 들어 오타 수정은 구현과 검증만, 버그는 조사와 회귀 테스트를, 큰 기능은 문제 정의부터 계획·구현·QA·회고까지 실행할 수 있어야 합니다.

### Skills and prompts

- 직접 만든 스킬은 `agents/skills/owned/<name>/SKILL.md`에 둡니다.
- 외부 스킬을 수정하지 않고 보정할 때는 `agents/skills/wrappers/<name>/SKILL.md`를 사용합니다.
- 외부 원본 자체는 복사하지 않고 `agents/registry/skills.toml`과 `sources.lock`에 출처와 고정 버전을 기록합니다.
- 프롬프트는 목적, 입력, 출력, 사용 조건, 안전 제한을 문서화합니다.

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

어댑터는 공통 원본을 Claude Code, Codex, Gemini의 진입 형식으로 연결합니다. 현재 설치기는 `agents/adapters/`의 얇은 어댑터를 직접 링크합니다. 향후 생성기가 도입되면 `profile + project override + adapter`를 조합한 검토 완료 최종본을 `dist/`에 만듭니다.

```text
agents/ 원본
  + profile
  + project override
  + host adapter
        |
        +--> dist/claude
        +--> dist/codex
        +--> dist/gemini
```

`dist/` 파일은 직접 편집하지 않고 원본을 수정한 뒤 다시 생성합니다.

## 현재 제공 기능과 후속 작업

현재 저장소가 제공하는 것은 다음과 같습니다.

- 공통 규칙과 도구별 얇은 어댑터
- 범용 및 Next.js 프로젝트 템플릿
- 전역·프로젝트 심볼릭 링크 설치와 안전한 제거
- 충돌 감지, 강제 설치 전 백업, 제거 시 복구
- 저장소 이동과 내부 경로 변경 후 재설치 복구
- 구조, 비밀 패턴, 셸 문법과 설치 시나리오 검증
- 하나의 살아 있는 제품 Brief와 자율 실행, 결정론적 검증을 잇는 기본 제품 개발 워크플로우
- 감사·고위험 작업을 위한 단계별 한국어 산출물, 명시적 승인, 중단 후 재개의 10단계 호환 경로
- Claude Code, Codex, Gemini의 공통 스킬 발견과 전역·프로젝트 워크플로우 CLI
- owned/external 스킬 목록과 검토한 외부 소스 커밋 잠금

다음 항목은 구조만 예약되어 있거나 아직 자동 실행 기능이 아닙니다.

- 외부 스킬·플러그인 다운로드와 버전 갱신
- MCP 설정 생성과 health check
- 호스트별 훅 설치와 실행
- 프로필 합성 및 `dist/` 생성
- 스킬 라우팅 및 행동 eval

## 설치

먼저 저장소를 원하는 위치에 clone한 뒤 반드시 dry-run을 확인합니다.

```bash
cd /path/to/dotagents
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global
```

전역 모드는 다음 링크를 만듭니다.

- `~/.agents` → 이 저장소의 `agents/`
- `~/.claude/CLAUDE.md` → `agents/adapters/claude/CLAUDE.md`
- `~/.claude/skills/product-development-workflow` → owned 워크플로우 스킬
- `~/.codex/AGENTS.md` → `agents/adapters/codex/AGENTS.md`
- `~/.gemini/GEMINI.md` → `agents/adapters/gemini/GEMINI.md`
- `~/.local/bin/dotagents-workflow` → 워크플로우 상태 명령

Codex와 Gemini는 `~/.agents/skills/product-development-workflow` 별칭에서 같은 owned 스킬을 발견합니다. `~/.local/bin`이 `PATH`에 없으면 설치기가 경고하며 전체 경로로 실행할 수 있습니다.

기존 대상이 있으면 기본 동작은 충돌을 표시하고 아무것도 변경하지 않는 것입니다. `--force`는 기존 항목을 타임스탬프가 붙은 형제 경로로 백업한 뒤 설치합니다. 실제 설정을 먼저 검토하지 않은 상태에서는 `--force`를 사용하지 마세요.

```bash
./tooling/scripts/install.sh --dry-run --global --force
```

### 프로젝트에 적용

```bash
./tooling/scripts/install.sh --dry-run --project /path/to/project
./tooling/scripts/install.sh --project /path/to/project
```

프로젝트 모드는 `.agents`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude/skills/product-development-workflow`, `.dotagents/bin/dotagents-workflow` 링크를 설치합니다. Codex와 Gemini는 프로젝트의 `.agents/skills` 별칭을 사용합니다. 기존 프로젝트 파일이 있으면 중단하므로 그 파일을 유지하면서 공통 규칙 경로만 직접 참고하거나, 내용을 검토한 뒤 명시적으로 `--force`를 사용해야 합니다.

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

에이전트에게 다음처럼 요청합니다.

```text
$product-development-workflow 로 이 Next.js 스타터 킷에 인증 기능을 추가해줘. Brief부터 구현 검증까지 진행해줘.
```

스킬은 프로젝트 안에 `docs/workflows/<run-id>/brief.md` 하나를 만들고 문제, 목적, 판단 원칙, 제약, 수용 조건과 결정 기록을 계속 갱신합니다. 이미 전역 설치했다면 설치 명령은 다시 실행할 필요가 없습니다. 대상 프로젝트의 `AGENTS.md` 같은 고유 규칙이 공통 규칙보다 우선합니다.

워크플로우는 작은 수정에는 적용하지 않고, 일반 제품 개발에는 다음 기본 경로를 실행합니다.

```text
Brief → Execute → Verify
```

주 에이전트가 전체 문맥에서 계획과 도구를 자율적으로 선택하고, 외부 스킬·멀티에이전트·RAG는 실제 필요가 있을 때만 사용합니다. 검증은 수용 조건과 프로젝트 테스트·정적 검사·빌드처럼 판정 가능한 증거를 우선합니다.

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
bash -n tooling/scripts/install.sh
bash -n tooling/scripts/uninstall.sh
bash -n tooling/scripts/check.sh
bash -n tooling/scripts/workflow.sh
./tooling/scripts/install.sh --dry-run
./tooling/scripts/uninstall.sh --dry-run
./tooling/scripts/check.sh
./tooling/scripts/check-sources.sh
./tooling/tests/install_test.sh
./tooling/tests/structure_test.sh
./tooling/tests/workflow_test.sh
./tooling/tests/sources_test.sh
```

`check.sh`는 필수 구조, 스킬 규격, 깨진 링크, 셸 문법, 저장소 경로 하드코딩, 의심되는 비밀 패턴·파일명, 어댑터의 공통 규칙 중복, 레지스트리 기본 형식, 워크플로우 계약과 설치 dry-run을 검사합니다. `check-sources.sh`는 별도의 네트워크 검사이며 GitHub CLI 인증이 필요합니다. 탐지 시 비밀 값은 출력하지 않습니다.

## 자산 추가

- 공통 규칙: `agents/rules/<topic>.md`
- 워크플로우: `agents/workflows/<name>/WORKFLOW.md`, `workflow.toml`
- 직접 만든 스킬: `agents/skills/owned/<name>/SKILL.md`
- 외부 스킬 wrapper: `agents/skills/wrappers/<name>/SKILL.md`
- 프롬프트: `agents/prompts/<name>.md`
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

- 도구가 Markdown의 다른 파일을 자동 include하는 방식이 서로 달라 얇은 어댑터가 규칙 경로를 안내합니다. 에이전트가 링크된 규칙을 읽지 않는 경우 명시적으로 읽도록 요청해야 할 수 있습니다.
- 기존 설정 파일과 구조적으로 병합하지 않습니다. 충돌을 중단하거나 `--force` 백업으로 처리합니다.
- Windows는 지원하지 않습니다.
- 설정 예제는 자동 설치하지 않습니다. 실제 설정과 비밀을 안전하게 병합하는 작업은 사용자 책임입니다.
- 스킬 레지스트리는 검토 목록과 잠금 기록이며 외부 자산 자동 설치에는 아직 사용하지 않습니다. 프로필, 훅, MCP와 `dist/`도 아직 설치기에서 합성하지 않습니다.

## 라이선스

MIT License. 자세한 내용은 `LICENSE`를 참고하세요.
