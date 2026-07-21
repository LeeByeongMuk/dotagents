# dotagents

Claude Code, Codex, Gemini에서 함께 쓰는 개인 AI 규칙·스킬·프롬프트 저장소입니다. 공통 원본은 `agents/` 한 곳에만 두고, 도구별 파일은 원본 위치와 도구별 차이만 설명하는 얇은 어댑터입니다.

## 원칙과 우선순위

적용 우선순위는 **프로젝트 고유 규칙 → 도구 전용 설정 → 개인 공통 기본 규칙**입니다. 공통 규칙은 프로젝트가 선택한 프레임워크, 패키지 매니저, 테스트 도구, 브랜치 정책을 바꾸지 않습니다.

`agents/rules/`와 `agents/skills/`가 단일 원본(SSOT)입니다. 전역 설치에서는 `~/.agents`가 이 원본을 가리키고, 프로젝트 설치에서는 `<project>/.agents`가 가리킵니다. Claude·Codex·Gemini 진입 파일은 규칙 본문을 복제하지 않습니다.

## 구조

```text
.
├── AGENTS.md                 # 이 저장소 자체의 작업 규칙
├── agents/
│   ├── rules/                # 공통 규칙 SSOT
│   ├── skills/README.md      # 재사용 스킬 추가 규약
│   └── prompts/README.md     # 재사용 프롬프트 추가 규약
├── claude/                   # Claude 어댑터와 안전한 설정 예제
├── codex/                    # Codex 어댑터와 안전한 설정 예제
├── gemini/                   # Gemini 어댑터
├── templates/generic/        # 일반 프로젝트 템플릿
├── templates/nextjs/         # 범용 Next.js 템플릿과 선택형 FSD 규칙
├── scripts/                  # 설치·제거·검증
└── tests/                    # 격리된 설치 시나리오 테스트
```

지원 대상은 macOS의 zsh/bash 환경과 Claude Code, Codex, Gemini CLI입니다. 스크립트는 POSIX 경로와 `bash`를 사용합니다.

## 설치

먼저 저장소를 원하는 위치에 clone한 뒤 반드시 dry-run을 확인합니다.

```bash
cd /path/to/dotagents
./scripts/install.sh --dry-run --global
./scripts/install.sh --global
```

전역 모드는 다음 링크를 만듭니다.

- `~/.agents` → 이 저장소의 `agents/`
- `~/.claude/CLAUDE.md` → `claude/CLAUDE.md`
- `~/.codex/AGENTS.md` → `codex/AGENTS.md`
- `~/.gemini/GEMINI.md` → `gemini/GEMINI.md`

기존 대상이 있으면 기본 동작은 충돌을 표시하고 아무것도 변경하지 않는 것입니다. `--force`는 기존 항목을 타임스탬프가 붙은 형제 경로로 백업한 뒤 설치합니다. 실제 설정을 먼저 검토하지 않은 상태에서는 `--force`를 사용하지 마세요.

```bash
./scripts/install.sh --dry-run --global --force
```

### 프로젝트에 적용

```bash
./scripts/install.sh --dry-run --project /path/to/project
./scripts/install.sh --project /path/to/project
```

프로젝트 모드는 `.agents`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` 링크를 설치합니다. 기존 프로젝트 파일이 있으면 중단하므로 그 파일을 유지하면서 공통 규칙 경로만 직접 참고하거나, 내용을 검토한 뒤 명시적으로 `--force`를 사용해야 합니다. 프로젝트 고유 규칙을 새로 작성할 때는 다음 템플릿을 복사해 프로젝트 상황에 맞게 수정하세요.

```bash
cp templates/generic/AGENTS.md /path/to/project/AGENTS.md
# 또는
cp templates/nextjs/AGENTS.md /path/to/project/AGENTS.md
```

Next.js 템플릿은 기술 선택을 자동으로 가정하지 않습니다. FSD를 실제로 채택한 프로젝트만 `templates/nextjs/fsd-optional.md`를 참고하세요.

## 제거

설치 매니페스트에 기록되고 현재도 같은 원본을 가리키는 링크만 제거합니다. `--force` 설치 때 만든 백업은 대상 경로가 비어 있을 때 복원합니다. 사용자가 링크를 다른 대상으로 바꿨다면 건너뜁니다.

```bash
./scripts/uninstall.sh --dry-run --global
./scripts/uninstall.sh --global

./scripts/uninstall.sh --dry-run --project /path/to/project
./scripts/uninstall.sh --project /path/to/project
```

전역 매니페스트는 `${XDG_STATE_HOME:-$HOME/.local/state}/dotagents/install.tsv`, 프로젝트 매니페스트는 `<project>/.dotagents-install.tsv`입니다.

## 검증

```bash
bash -n scripts/install.sh
bash -n scripts/uninstall.sh
bash -n scripts/check.sh
./scripts/install.sh --dry-run
./scripts/uninstall.sh --dry-run
./scripts/check.sh
./tests/install_test.sh
```

`check.sh`는 필수 파일, 깨진 링크, 셸 문법, 저장소 경로 하드코딩, 의심되는 비밀 패턴·파일명, 어댑터의 공통 규칙 중복, 설치 dry-run을 검사합니다. 탐지 시 비밀 값은 출력하지 않습니다.

## 규칙·스킬·프롬프트 추가

- 범용 규칙은 `agents/rules/<topic>.md`에 작고 독립적인 문서로 추가합니다.
- 재사용 스킬은 `agents/skills/<skill-name>/SKILL.md`에 추가합니다.
- 프롬프트는 `agents/prompts/`에 추가하고 입력·출력·사용 조건을 문서화합니다.
- 특정 도구에서만 필요한 동작은 해당 도구 디렉터리의 어댑터에 최소한으로 적습니다.
- 특정 프로젝트의 기술·아키텍처·검증 명령은 그 프로젝트의 로컬 규칙에 둡니다.

## 비밀 정보

API 키, 토큰, 쿠키, 세션, 개인 키, 실제 MCP 인증 정보, 비공개 조직 정보는 커밋하지 않습니다. `.env.example` 같은 예제에는 `OPENAI_API_KEY=<your-api-key>`처럼 자리표시자만 사용하세요. `.gitignore`와 `check.sh`는 실수를 줄이는 보조 장치일 뿐이므로 커밋 전 diff를 직접 검토해야 합니다.

## 새 컴퓨터에서 복원

```bash
git clone <your-dotagents-repository-url> ~/Documents/GitHub/dotagents
cd ~/Documents/GitHub/dotagents
./scripts/check.sh
./scripts/install.sh --dry-run --global
./scripts/install.sh --global
```

clone 위치를 바꾸면 기존 절대 심볼릭 링크는 이전 위치를 가리킵니다. 새 위치에서 같은 설치 명령을 다시 실행하면 dotagents가 소유한 링크를 새 원본으로 갱신합니다. 다른 기존 파일은 자동 변경하지 않습니다.

## 알려진 제한 사항

- 도구가 Markdown의 다른 파일을 자동 include하는 방식이 서로 달라 얇은 어댑터가 규칙 경로를 안내합니다. 에이전트가 링크된 규칙을 읽지 않는 경우 명시적으로 읽도록 요청해야 할 수 있습니다.
- 기존 설정 파일과 구조적으로 병합하지 않습니다. 충돌을 중단하거나 `--force` 백업으로 처리합니다.
- Windows는 지원하지 않습니다.
- 설정 예제는 자동 설치하지 않습니다. 실제 설정과 비밀을 안전하게 병합하는 작업은 사용자 책임입니다.
- 저장소 이동은 파일시스템이 추적할 수 없으므로 새 위치에서 설치 스크립트를 다시 실행해야 합니다.

## 라이선스

MIT License. 자세한 내용은 `LICENSE`를 참고하세요.
