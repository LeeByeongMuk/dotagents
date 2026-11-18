# 프로젝트 로컬 준비와 점검

`tooling/scripts/project.sh`는 선택한 프로젝트의 로컬 지침·컨텍스트·검증 근거를 살피고, 없을 때 유지 중인 템플릿으로 시작할 수 있게 한다. 전역 dotagents 설치와 독립적으로 동작한다. Bash와 기본 파일 도구를 사용하고, `package.json`이 있을 때 점검에는 `jq`가 필요하다.

## 읽기 전용 점검

dotagents 저장소에서 기존 프로젝트 디렉터리를 명시한다.

```bash
./tooling/scripts/project.sh inspect /path/to/project
./tooling/scripts/project.sh doctor /path/to/project
```

두 명령은 같은 근거를 출력한다. `inspect`는 누락이 있어도 종료 코드 0, `doctor`는 아래 근거가 빠지면 1이다. 잘못된 인자·없는 프로젝트 경로·필요한 `jq`의 누락은 두 명령 모두 실패한다.

- 루트의 일반 파일 `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` 중 하나
- `.ai-context`, `docs/context`, `docs/architecture` 중 디렉터리 하나
- 지침 파일의 Verification·Validation·검증 제목, 또는 `package.json`의 `build`, `check`, `lint`, `test`, `typecheck` 및 `lint:ci` 같은 하위 이름

`package.json`에서는 해당 스크립트 이름만 출력한다. 명령 본문·임의 메타데이터는 출력하거나 실행하지 않는다. 알려진 lockfile의 존재도 패키지 매니저 근거로 표시하되, 도구나 의존성을 설치하지 않는다.

종료 코드 0은 위 근거의 존재를 뜻한다. 도메인 설명의 완성도, 지침의 최신성, 스크립트의 안전성·성공, 호스트의 실제 지침 로딩은 검사하지 않는다. 다른 컨텍스트 위치나 모듈별 지침을 사용하는 프로젝트는 그 프로젝트의 참조를 직접 확인한다. 루트의 지침·메타데이터 파일과 컨텍스트 경로가 링크이면 대상을 읽지 않는다. `.agents`의 내용도 순회하지 않는다.

## 미리보기와 명시적 초기화

초기화 대상은 이미 존재하는 프로젝트 디렉터리다. 기본 동작은 출력만 하는 미리보기다.

```bash
./tooling/scripts/project.sh init /path/to/project
./tooling/scripts/project.sh init /path/to/project --template nextjs --dry-run
./tooling/scripts/project.sh init /path/to/project --template generic --apply
```

지원하는 템플릿은 `generic`, `nextjs`다. 지정한 유형을 자동 판정하거나 스택·패키지 매니저·의존성을 선택하지 않는다. 적용하면 빠진 파일만 추가한다.

| 로컬 파일 | 원본과 역할 |
|---|---|
| `AGENTS.md` | [generic](../agents/templates/generic/AGENTS.md) 또는 [Next.js](../agents/templates/nextjs/AGENTS.md) 템플릿과 출처·로컬 검증 안내 |
| `.ai-context/README.md` | [프로젝트 컨텍스트 준비 안내](../agents/templates/context-docs/project-readme.md). 지침의 자리표시자 정리, 검증 근거, 필요한 시점의 도메인 문서 작성 안내 |

기존 `AGENTS.md`, `CLAUDE.md`, 문서, 설정과 링크는 바꾸거나 병합하지 않는다. 재실행해도 이미 있는 파일은 보존한다. `.agents`·호스트 진입점·설정 링크와 설치 기록을 만들지 않는다. 소스 체크아웃을 삭제하거나 전역 링크가 없어도 생성된 로컬 파일을 읽을 수 있다. 단, 점검 CLI를 다시 쓰려면 dotagents 체크아웃이 필요하다.

생성된 지침은 실제 관례나 도메인 사실이 확인됐다는 의미가 아니다. 기존 유지 템플릿을 시작점으로만 제공하고 출처를 남긴다. 새 프로젝트 관례는 사용자의 최신 실사용 저장소에서 관련 지침·패키지 메타데이터를 확인한 뒤 출처를 기록한다. 프로젝트가 다른 컨텍스트 위치를 쓰면 그 원본을 유지하고 새 안내를 조정하거나 삭제한다. 도메인 개요·인터페이스 계약·연동 문서는 확인한 내용이 필요해질 때 작성한다.

빈 프로젝트의 출력 예시는 다음과 같다. 적용 전후 어느 명령도 프로젝트의 스크립트를 실행하지 않는다.

```text
$ project.sh doctor /path/to/project
gap: no regular project-local instruction file
gap: no context directory at .ai-context, docs/context, or docs/architecture; inspect project-specific references manually
gap: no verification heading or recognized package script; record actual project checks
# exit 1

$ project.sh init /path/to/project --apply
create: AGENTS.md (source: agents/templates/generic/AGENTS.md)
create: .ai-context/README.md (source: agents/templates/context-docs/project-readme.md)
applied: local starters added; review placeholders and run actual project checks

$ project.sh doctor /path/to/project
local: AGENTS.md
context location: .ai-context (content and completeness not validated)
verification: guidance or script names found; no commands executed and no passing checks established
# exit 0: 템플릿에 검증 제목이 생겼다는 근거이며 검사 성공을 뜻하지 않는다.
```

## 경로 보호와 실패 처리

초기화는 선택 경로와 그 상위에 심볼릭 링크가 있으면 거부한다. 운영체제의 `/tmp` 같은 별칭도 해당하므로 물리 경로를 선택한다. `.ai-context`가 링크이거나 디렉터리가 아닌 경우에도 파일 추가 전에 실패한다. 기존 `AGENTS.md` 자체가 링크인 경우에는 그 항목을 보존하고 대상에 쓰지 않는다. 홈·파일시스템 루트·dotagents 원본과 그 상위 디렉터리, 원본의 하위 디렉터리, 알려진 도구 설정 디렉터리는 대상으로 받지 않는다. Git을 사용할 수 있으면 공통 Git 디렉터리를 비교하여 같은 저장소의 주 체크아웃과 다른 linked worktree 및 그 하위 경로도 거부한다.

모든 원본과 충돌을 먼저 확인하고, 프로젝트 안의 임시 디렉터리에 파일을 준비한 뒤 덮어쓰기 없는 하드 링크로 추가한다. 명령 실패나 INT·TERM 시 이번 실행에서 추가한 파일을 되돌리고 임시 파일을 정리한다. SIGKILL·전원 차단이나 적용 중 프로젝트 디렉터리를 다른 프로세스가 이동·교체하는 경우의 복구는 보장하지 않는다. 그런 경우 `.dotagents-project.*`와 새 파일을 직접 확인한다. 검토한 경로를 다른 프로세스가 동시에 교체하지 않는 로컬 작업용 도구다.

## 검증

```bash
./tooling/tests/project_test.sh
make check
git diff --check
```

회귀 검사는 전역 설치가 없는 임시 홈과 임시 프로젝트에서 미리보기·점검의 무변경, 두 템플릿 초기화, 기존 파일·링크 보존, 링크 경로·보호 경로 차단, 잘못된 템플릿과 충돌의 무변경 실패, 재실행, 두 번째 파일 추가 실패 시 복구, 스크립트 이름만 보고하고 실행하지 않는 동작을 확인한다.
