# 저장소 구조와 원본

[문서 목록](../docs/README.md) · [유지보수 안내](../tooling/README.md)

`agents/`는 여러 프로젝트에서 재사용하는 AI 자산의 원본입니다. 적용 우선순위는 프로젝트 고유 규칙, 도구 전용 설정, 개인 공통 규칙 순입니다.

## 저장소 구성

```text
dotagents/
├── AGENTS.md        # 이 저장소의 작업 규칙
├── dotagents.toml   # 원본·도구·출력 경로 메타데이터
├── agents/         # 규칙·스킬·훅·어댑터·템플릿 원본
├── tooling/        # scripts, tests, evals
├── environment/    # 선택 셸·Git 설정 프로필과 패키지 목록
├── docs/           # 사용 안내, designs, decisions, evals, workflows
└── dist/           # 호스트별 생성 지침
```

## AI 자산의 위치

| 위치 | 역할과 원본 |
| --- | --- |
| `rules/<topic>.md` | 행동·코딩·Git·문서·보안의 공통 규칙 |
| `adapters/<host>/` | Claude Code·Codex·Gemini의 진입 형식과 설정 |
| [skills/](skills/README.md) | 직접 만든 스킬의 원본, 발견용 별칭과 추가·제거 절차 |
| [workflows/](workflows/README.md) | 사람용 워크플로우 사용 안내. 실행 계약은 해당 스킬이 소유 |
| [hooks/](hooks/README.md) | 커밋 메시지 검사기와 호스트·Git 진입점 |
| [registry/](registry/README.md) | 자산 ID·출처·지원 정보와 외부 소스 잠금 |
| [integrations/](integrations/README.md) | 외부 스킬·MCP·플러그인·도구의 연동 범위 |
| [profiles/](profiles/README.md) | AI 자산 조합의 규격. 실제 프로필과 합성 기능은 미제공 |
| `templates/` | [범용](templates/generic/AGENTS.md)·[Next.js](templates/nextjs/AGENTS.md) 지침과 [컨텍스트 문서](templates/context-docs/README.md) 템플릿 |

작업 라우팅은 해당 `SKILL.md`의 description과 라우팅 절이 원본입니다. 별도 라우팅 문서로 복제하지 않습니다. 외부 스킬을 보정할 wrapper나 종류별 연동 디렉터리는 실제 소비자가 생길 때 추가합니다. [빈 자리표시자를 두지 않는 이유](../docs/decisions/0004-test-scope-and-placeholders.md)

## 새 자산의 위치 정하기

| 새로 추가할 내용 | 둘 곳과 판단 기준 |
| --- | --- |
| 기술 스택과 관계없이 적용할 개인 기준 | `agents/rules/`의 해당 주제. 도구별 진입 형식과 설정은 `agents/adapters/<host>/`에 둡니다. [규칙 작성 기준](../docs/decisions/0002-rule-authoring-criterion.md) |
| 여러 프로젝트에서 선택해 쓸 작업 절차 | `agents/skills/owned/`에 실행 조건과 지원 환경을 명시합니다. 스택 전용 스킬도 조건이 맞는 여러 프로젝트에서 재사용할 수 있습니다. 외부 스킬의 원본은 공급자가 관리하며, 레지스트리에 출처와 검토한 커밋을 기록하고 필요한 사용법은 연동 안내에 둡니다. [스킬 추가](skills/README.md#추가) · [레지스트리와 잠금](registry/README.md) · [외부 연동](integrations/README.md) |
| 한 프로젝트의 스택·버전, 빌드·검증 명령, 도메인 관례·전용 스킬 | 해당 프로젝트의 로컬 지침·컨텍스트·스킬에 둡니다. 여러 프로젝트에서 재사용할 근거가 생긴 관례는 별도 요청으로 반영합니다. [프로젝트 준비](../docs/project-readiness.md) · [공통 관례 반영](skills/owned/dotagents-promote/SKILL.md) |
| 프로젝트를 위한 에이전트 지침·컨텍스트 초안 | 현재 `agents/templates/`의 유지 중인 템플릿에서 시작합니다. 신규 프로젝트마다 같은 지침·PR 양식·골격을 준비하는 작업이 반복되면 선택형 `base`를 검토합니다. [초기화 지원](../docs/project-readiness.md#미리보기와-명시적-초기화) |
| 개인 셸·Git·앱 설정과 기기별 패키지 구성 | 기기 설정의 범위로 두고, 향후 `dotfiles` 저장소가 마련되면 이관 대상을 검토합니다. 현재 dotagents의 `environment/`는 명시적으로 적용하는 공용 예제를 제공합니다. [선택 개발 환경 프로필](../environment/README.md) · [전환 절차와 후속 TODO](../docs/workflows/dotagents-scope/brief.md#후속-todo) |

## 원본에서 설치까지

```text
agents/rules/ + agents/adapters/<host>/의 지침
    → make build
    → dist/{claude/CLAUDE.md,codex/AGENTS.md,gemini/GEMINI.md}
    → 설치된 호스트 진입점 링크
```

호스트가 다른 Markdown을 따로 읽지 않아도 공통 규칙이 적용되도록 본문을 합칩니다. `dist/`의 생성 파일은 직접 편집하지 않고 원본 수정 후 다시 만듭니다. [생성 방식의 결정 근거](../docs/decisions/0003-generated-host-entry-points.md)

스킬과 훅은 원본을 직접 링크하므로 기존 내용 수정이 즉시 적용됩니다. 설치 대상과 사용자 설정 소유권은 [설치 레이아웃](../docs/designs/install-layouts.md)이 정합니다. 셸·Git 설정을 복사해 적용하는 [개발 환경 프로필](../environment/README.md)은 별도 기능입니다.

## 작성 기준

규칙에는 모델이 스스로 알 수 없는 프로젝트·사용자 정보를 적습니다. [규칙 작성 기준](../docs/decisions/0002-rule-authoring-criterion.md)을 따르고, 행동·설명은 Markdown, 목록·잠금 정보는 TOML로 관리합니다.

사람용 안내는 한국어 단일본으로 유지합니다. `SKILL.md`, `AGENTS.md`와 기계 판독 계약도 각각 단일 원본으로 유지하고 다른 문서에서 참조합니다. 변경 절차와 검사, 비밀 정보 취급은 [유지보수 안내](../tooling/README.md)를 따릅니다.
