# 커밋 메시지 훅

[문서 목록](../../docs/README.md) · [설치 안내](../../docs/install.md)

[공통 Git 규칙](../rules/git.md)의 커밋 메시지 형식·문체를 검사합니다. 훅 등록 정보는 [hooks.toml](../registry/hooks.toml)이 소유합니다. Git 작업 전반의 안전성 검사는 이 훅의 범위가 아닙니다.

## 진입점과 설치

| 진입점 | 역할 | 연결 방식 |
| --- | --- | --- |
| [pre-tool-use.sh](commit-message/pre-tool-use.sh) | Claude Code·Codex의 셸 도구 실행 전 `git commit` 메시지 검사 | 전역 설치에서 등록 |
| [commit-msg](commit-message/commit-msg) | Git이 전달한 최종 메시지 파일 검사 | 프로젝트 Git 훅에 선택적으로 연결 |
| [check.sh](commit-message/check.sh) | 두 진입점의 공용 검사기. 파일 또는 표준 입력 검사 | `check.sh <메시지 파일>`로 단독 사용 가능 |

legacy 전역 설치는 Claude `settings.json`과 Codex `hooks.json`을 링크합니다. managed는 기존 일반 설정을 보존하고 파일이 없을 때만 최소 훅 설정을 만듭니다. 기존 설정에 등록이 빠졌으면 doctor 안내에 따라 수동 통합합니다. [설정 소유권과 등록 계약](../../docs/designs/install-layouts.md#사용자-설정과-hook-등록)

Codex는 새 훅이나 바뀐 훅을 `/hooks`에서 검토하고 신뢰해야 실행합니다. Gemini에는 도구 실행 전 훅을 연결하지 않습니다. Gemini나 사람의 커밋도 검사하려면 프로젝트가 사용하는 `commit-msg` 훅에 래퍼를 연결합니다. 기존 훅과 `core.hooksPath`를 먼저 확인합니다.

```sh
# 대상 프로젝트에서 실행. 기존 훅 파일이 있으면 덮어쓰지 말고 통합 방식을 검토
hook_path="$(git rev-parse --git-path hooks/commit-msg)"
ln -s "$HOME/.agents/hooks/commit-message/commit-msg" "$hook_path"
```

래퍼를 복사해 설치할 때는 같은 디렉터리에 `check.sh`도 복사합니다.

## 프로젝트 규칙 우선

다음 중 하나면 공통 문체 검사를 건너뜁니다.

- `git config dotagents.commitCheck false` 설정
- 저장소 루트에 commitlint 설정 또는 `.gitlint` 존재
- Git이 사용하는 훅 디렉터리 또는 `.husky/`에 프로젝트의 `commit-msg` 존재. Git은 `core.hooksPath`와 연결된 worktree의 공용 Git 디렉터리를 반영해 훅 경로를 정합니다. Husky 9의 자동 생성 파일은 실제 프로젝트 훅이 있을 때 프로젝트 규칙을 적용합니다. 공통 래퍼는 링크하거나 복사해 설치해도 공통 문체를 검사합니다.

도구 실행 전 훅은 문체 검사에 앞서 메시지와 경로를 확인하므로, 위 조건에 해당해도 실행 전에 읽을 수 있는 메시지를 요구할 수 있습니다.

## 검사 범위와 한계

공용 검사기는 헤더 형식·길이·마침표·명령형, 둘째 줄 공백, 서술형·과장 표현, 불릿·굵은 글씨를 검사합니다.

`pre-tool-use.sh`는 `jq`로 호스트의 `tool_input.command`와 `cwd`를 읽고, `git commit`의 `-m`, `--message`, 히어독, `-F` 파일에서 메시지를 찾습니다. `-m "메시지"`와 `-m"메시지"`를 모두 처리합니다. 두 호스트 모두 위반 시 종료 코드 2로 차단합니다. 커밋 인자의 `--no-edit`, `-c`, `-C`, `--fixup`, `--squash`는 건너뛰며 Git 전역 옵션이나 뒤따르는 다른 명령의 플래그는 이 판단에 쓰지 않습니다.

따옴표로 감싼 경로와 연속된 `git -C`를 해석하여 해당 저장소의 규칙과 상대 메시지 파일을 사용합니다. 변수·명령 치환으로 디렉터리를 확정할 수 없으면 직접 적도록 안내하고 차단합니다. 히어독 본문은 데이터로 취급하며, 셸 명령을 평가하거나 실행하지 않습니다.

`cd` 래퍼·별칭·복잡한 셸 식까지 해석하는 셸 파서는 아닙니다. 모든 Git 실행 경로의 최종 메시지를 검사하려면 선택형 `commit-msg` 훅을 사용합니다.
