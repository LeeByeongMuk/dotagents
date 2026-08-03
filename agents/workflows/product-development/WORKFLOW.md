# 제품 개발 워크플로우

인터뷰에서 시작해 도메인, 설계, 스펙, 계획, 구현, 검수와 아키텍처 평가까지 이어지는 10단계 공통 절차입니다. 각 단계는 한국어 산출물과 사용자 승인을 남기므로 Claude Code, Codex, Gemini 또는 다음 세션에서 같은 지점부터 재개할 수 있습니다.

## 언제 사용하나

다음 작업에 사용합니다.

- 새 제품이나 기능을 아이디어부터 구현까지 진행할 때
- 사용자·도메인·범위 결정이 아직 남은 `standard` 작업
- 여러 화면·서비스·경계와 아키텍처 결정이 포함된 `substantial` 작업

요구가 확정된 작은 수정, 단일 버그, 설명이나 조사만 필요한 요청에는 사용하지 않습니다.

## 10단계

| 단계 | 결과 |
|---|---|
| 1. 그릴미 인터뷰 | 사용자, 문제, 현재 방식, 증거, 성공 기준 |
| 2. 도메인 파일 | 용어, 액터, 불변조건, 경계, 비목표 |
| 3. gstack office hours | 전제 검토, 대안 비교, 승인된 설계 |
| 4. 라이트 스펙 | 사용자 이야기, 동작, 수용 조건, 제약 |
| 5. 플랜 | 정확한 파일·작업·테스트·검증 명령 |
| 6. 플랜 리뷰 | 범위·아키텍처·테스트·성능 검수 결과 |
| 7. 서브에이전트 코드 | 구현 작업, 변경 파일, 커밋과 검사 증거 |
| 8. 코드·테스트 리뷰 | diff 리뷰, 테스트, 빌드, QA 결과 |
| 9. 아키텍처 평가·개선 | 평가, 승인된 개선, 전체 재검증 |
| 10. 스킬 리팩터링 후보 | 반복 절차와 스킬 후보 보고서(선택) |

단계의 기계 계약은 [workflow.toml](workflow.toml), 에이전트 실행 규칙은 [SKILL.md](../../skills/owned/product-development-workflow/SKILL.md)에 있습니다.

## 설치

저장소 루트에서 먼저 dry-run을 확인합니다.

```bash
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global
```

특정 프로젝트에만 적용하려면 다음을 실행합니다.

```bash
./tooling/scripts/install.sh --dry-run --project /path/to/project
./tooling/scripts/install.sh --project /path/to/project
```

전역 설치는 `~/.local/bin/dotagents-workflow`, 프로젝트 설치는 `<project>/.dotagents/bin/dotagents-workflow`를 제공합니다. `~/.local/bin`이 `PATH`에 없으면 설치기가 경고하며 전체 경로로 실행할 수 있습니다.

## 사용

가장 쉬운 방법은 지원 호스트에서 스킬을 요청하는 것입니다.

```text
$product-development-workflow 로 이 제품 아이디어를 인터뷰부터 구현 검수까지 진행해줘.
```

스킬이 범위를 판정하고 실행을 시작합니다. 상태 도구를 직접 사용할 수도 있습니다.

```bash
dotagents-workflow start \
  --project /path/to/project \
  --run checkout-redesign \
  --scope substantial

dotagents-workflow status \
  --project /path/to/project \
  --run checkout-redesign
```

산출물은 `<project>/docs/workflows/checkout-redesign/`에 다음처럼 생깁니다.

```text
01-interview.md
02-domain.md
...
```

에이전트는 산출물을 보여주고 명시적 승인을 받은 뒤에만 다음 명령을 호출합니다.

```bash
dotagents-workflow approve \
  --project /path/to/project \
  --run checkout-redesign \
  --stage 1 \
  --user-approved
```

`--user-approved`는 파일 존재만으로 대신할 수 없는 사람의 결정입니다. 일반적인 진행 요청이나 침묵을 승인으로 해석하면 안 됩니다. 승인 명령은 파일의 SHA-256을 상태에 기록하므로 이후 파일이 바뀌면 `status`, 다음 승인과 `verify`가 실패합니다. 승인된 산출물은 수정하지 않고, 정정은 다음 단계의 새 결정으로 남기거나 새 실행으로 교체합니다.

### 기존 스펙이나 플랜에서 시작

기존 문서를 해당 실행의 정규 파일명으로 복사하고 필요한 앞 단계 내용을 보완합니다. 사용자가 전체 묶음을 검토해 승인한 뒤 가져옵니다.

```bash
dotagents-workflow adopt \
  --project /path/to/project \
  --run existing-plan \
  --scope standard \
  --through 5 \
  --user-approved
```

빈 자리표시자와 심볼릭 링크는 허용하지 않습니다.

### 완료 확인

10단계를 사용하면 10단계 승인 후, `--skip-skill-refactor`로 시작했으면 9단계 승인 후 완료됩니다.

```bash
dotagents-workflow verify \
  --project /path/to/project \
  --run checkout-redesign
```

이 명령은 단계 순서, 안전한 산출물, 승인 기록과 완료 상태를 검증합니다. 코드가 올바른지 자체적으로 증명하는 명령은 아니며 실제 테스트·QA 증거는 7~9단계 문서에 남깁니다.

## 외부 스킬

외부 스킬은 선택 사항입니다.

- 인터뷰: Matt Pocock의 `grilling` (`grill-me` 호환 진입점)
- 설계·플랜 검수·코드 검수: gstack
- 구현 계획: Superpowers `writing-plans`

설치되어 있고 현재 단계와 호환되면 사용합니다. 없거나 실패하면 동일한 산출물 계약을 지키는 내장 절차로 한 번 계속합니다. 워크플로우가 외부 스킬을 자동 설치하거나 수정하지는 않습니다. 검토한 출처와 커밋은 `agents/registry/skills.toml`과 `agents/registry/sources.lock`에 기록됩니다.

## 복구와 안전

- `status`로 중단 지점과 다음 산출물을 확인합니다.
- 상태 파일을 잃고 산출물과 빈 실행 상태 디렉터리만 남아도 검토 후 `adopt`로 복구합니다.
- 같은 실행의 동시 상태 변경은 잠금으로 차단하고 오래된 잠금은 안전 기준에 따라 회수합니다.
- 서로 다른 실행 ID도 같은 작업 트리의 코드를 동시에 바꿀 수 있으므로 병렬 구현은 별도 branch/worktree를 사용합니다.
- 9단계에서 코드를 변경하면 8단계의 관련 검사를 전부 다시 실행해야 합니다.
- 10단계는 후보 보고서까지만 기본 범위입니다. 실제 스킬 생성은 별도 승인이 필요합니다.
