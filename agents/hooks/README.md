# Hooks

현재 커밋 메시지 검사 훅을 제공합니다. 훅은 실행 조건, 지원 호스트, 부작용과 실패 정책을 문서화하고 `../registry/hooks.toml`에 등록합니다.

## commit-message

`../rules/git.md`의 커밋 메시지 기본 규칙을 강제합니다. 프로젝트가 자체 규칙을 쓰면 공통 커밋 문체 검사를 건너뜁니다. 건너뛰는 조건은 `git config dotagents.commitCheck false`가 설정되어 있거나, 저장소 루트에 commitlint 설정, `.gitlint`, `.husky/commit-msg`, 이 래퍼가 아닌 `.git/hooks/commit-msg`가 있는 경우입니다. `pre-tool-use.sh`의 메시지·경로 확인은 문체 검사보다 먼저 실행되므로, 이 조건에 해당해도 실행 전에 읽을 수 있는 메시지를 요구할 수 있습니다.

- `check.sh` 메시지 파일 또는 표준 입력을 검사하는 공용 스크립트입니다. 헤더 형식, 길이, 마침표, 명령형, 둘째 줄 공백, 서술형·과장 표현, 불릿·굵은 글씨를 검사합니다.
- `pre-tool-use.sh` Claude Code와 Codex의 `PreToolUse` 훅입니다. 두 호스트 모두 표준 입력으로 `tool_input.command`와 `cwd`를 주고 종료 코드 2를 차단으로 처리하므로 같은 스크립트를 씁니다. Bash 명령이 `git commit`이면 `-m`, `--message`, 히어독, `-F` 파일에서 메시지를 뽑아 검사하고 위반 시 종료 코드 2로 차단합니다. 커밋 명령 자신의 인자에 `--no-edit`, `-c`, `-C`, `--fixup`, `--squash`가 있으면 검사하지 않고, `git -c`·`git -C` 같은 git 전역 옵션이나 뒤따르는 다른 명령의 플래그는 이 판단에 쓰지 않습니다. `jq`가 필요합니다. 메시지를 찾을 때 히어독 본문은 명령이 아니라 데이터로 다루므로, 히어독으로 파일을 쓴 뒤 같은 명령에서 커밋해도 그 본문을 메시지로 오인하지 않고 본문 안에 적힌 `git commit`도 실행 대상으로 보지 않습니다.
- `commit-msg` git 훅 래퍼입니다. Gemini나 사람의 커밋까지 막으려면 프로젝트의 `.git/hooks/commit-msg`로 링크합니다.

`pre-tool-use.sh`는 따옴표로 감싼 경로와 연속된 `git -C`를 포함해 명령에 직접 적힌 디렉터리를 해석하고, 해당 저장소의 정책과 상대 `-F` 경로를 사용합니다. 디렉터리에 변수나 명령 치환이 있어 실행 전에 확정할 수 없으면 경로를 직접 적도록 안내하고 차단합니다. 셸 명령을 평가하거나 실행하지 않으며, `cd` 래퍼·별칭·복잡한 셸 식까지 해석하는 셸 파서는 아닙니다. 최종 메시지를 모든 Git 실행 경로에서 검사하려면 선택형 `commit-msg` 훅을 사용하세요.

전역 설치는 `../adapters/claude/settings.json`을 `~/.claude/settings.json`으로, `../adapters/codex/hooks.json`을 `~/.codex/hooks.json`으로 링크해 두 호스트에 `pre-tool-use.sh`를 등록합니다. Codex는 새 훅이나 바뀐 훅을 신뢰하기 전에는 실행하지 않으므로, 설치하거나 훅 정의가 바뀐 뒤 Codex에서 `/hooks`로 검토하고 신뢰합니다.

프로젝트 git 훅으로 쓰려면 저장소 루트에서 다음을 실행합니다.

```sh
ln -s "$HOME/.agents/hooks/commit-message/commit-msg" .git/hooks/commit-msg
```
