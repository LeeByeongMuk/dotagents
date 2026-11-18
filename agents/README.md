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
