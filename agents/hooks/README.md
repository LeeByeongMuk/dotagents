# Hooks

세션 시작, 도구 실행 전후, 커밋 전, 출하 전, 컨텍스트 복구 훅을 보관합니다. 훅은 실행 조건, 지원 호스트, 부작용과 실패 정책을 문서화하고 `../registry/hooks.toml`에 등록합니다.

## commit-message

`../rules/git.md`의 커밋 메시지 기본 규칙을 강제합니다. 프로젝트가 자체 규칙을 쓰면 검사를 건너뜁니다. 건너뛰는 조건은 `git config dotagents.commitCheck false`가 설정되어 있거나, 저장소 루트에 commitlint 설정, `.gitlint`, `.husky/commit-msg`, 이 래퍼가 아닌 `.git/hooks/commit-msg`가 있는 경우입니다.

- `check.sh` 메시지 파일 또는 표준 입력을 검사하는 공용 스크립트입니다. 헤더 형식, 길이, 마침표, 명령형, 둘째 줄 공백, 서술형·과장 표현, 불릿·굵은 글씨를 검사합니다.
- `claude-pre-tool-use.sh` Claude Code `PreToolUse` 훅입니다. Bash 명령이 `git commit`이면 `-m`, `--message`, 히어독, `-F` 파일에서 메시지를 뽑아 검사하고 위반 시 종료 코드 2로 차단합니다. 커밋 명령 자신의 인자에 `--no-edit`, `-c`, `-C`, `--fixup`, `--squash`가 있으면 검사하지 않고, `git -c`·`git -C` 같은 git 전역 옵션이나 뒤따르는 다른 명령의 플래그는 이 판단에 쓰지 않습니다. `jq`가 필요합니다. 메시지를 찾을 때 히어독 본문은 명령이 아니라 데이터로 다루므로, 히어독으로 파일을 쓴 뒤 같은 명령에서 커밋해도 그 본문을 메시지로 오인하지 않고 본문 안에 적힌 `git commit`도 실행 대상으로 보지 않습니다.
- `commit-msg` git 훅 래퍼입니다. Codex, Gemini, 사람 커밋까지 막으려면 프로젝트의 `.git/hooks/commit-msg`로 링크합니다.

Claude Code 등록 예시는 `../adapters/claude/settings.example.json`에 있습니다. 전역 설치 경로 기준으로 다음과 같이 씁니다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "\"$HOME\"/.agents/hooks/commit-message/claude-pre-tool-use.sh" }
        ]
      }
    ]
  }
}
```

프로젝트 git 훅으로 쓰려면 저장소 루트에서 다음을 실행합니다.

```sh
ln -s "$HOME/.agents/hooks/commit-message/commit-msg" .git/hooks/commit-msg
```
