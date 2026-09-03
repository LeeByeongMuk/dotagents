# Hooks

세션 시작, 도구 실행 전후, 커밋 전, 출하 전, 컨텍스트 복구 훅을 보관합니다. 훅은 실행 조건, 지원 호스트, 부작용과 실패 정책을 문서화하고 `../registry/hooks.toml`에 등록합니다.

## commit-message

`../rules/git.md`의 커밋 메시지 기본 규칙을 강제합니다. 프로젝트가 자체 규칙을 쓰면 검사를 건너뜁니다. 건너뛰는 조건은 `git config dotagents.commitCheck false`가 설정되어 있거나, 저장소 루트에 commitlint 설정, `.gitlint`, `.husky/commit-msg`, `.git/hooks/commit-msg`가 있는 경우입니다.

- `check.sh` 메시지 파일 또는 표준 입력을 검사하는 공용 스크립트입니다. 헤더 형식, 길이, 마침표, 명령형, 둘째 줄 공백, 서술형·과장 표현, 불릿·굵은 글씨를 검사합니다.
- `claude-pre-tool-use.sh` Claude Code `PreToolUse` 훅입니다. Bash 명령이 `git commit`이면 `-m`, `--message`, 히어독, `-F` 파일에서 메시지를 뽑아 검사하고 위반 시 종료 코드 2로 차단합니다. `--amend --no-edit`, `-C`, `--fixup`, `--squash`는 검사하지 않습니다. `jq`가 필요합니다.
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

## search-guard

Claude Code의 Bash 재귀 검색을 막고 Grep 도구를 쓰게 합니다. Claude Code 2.1.259부터 `rg`, `ag`, `ack`, `grep -r` 처럼 디렉터리를 훑는 명령은 그 트리에 `Read` deny 룰 대상 파일(`.env`, `*.pem`, `*.key` 등)이 있으면 bypassPermissions 모드에서도 승인 프롬프트를 띄웁니다. `cd ~/…` 뒤에 상대 경로를 재귀 검색하는 복합 명령도 대상 디렉터리를 확정할 수 없다는 이유로 같은 프롬프트가 뜹니다. deny 룰은 유지해야 하므로 명령 쪽을 막습니다. Grep 도구는 같은 조건에서 프롬프트 없이 동작합니다.

- `claude-pre-tool-use.sh` Claude Code `PreToolUse` 훅입니다. Bash 명령을 셸 연산자 단위로 나눠 `rg`, `ag`, `ack`, 그리고 `-r`, `-R`, `--recursive`, `-d recurse` 가 붙은 `grep`, `egrep`, `fgrep` 를 찾으면 종료 코드 2로 차단하고 대신 Grep·Glob 도구를 쓰라는 메시지를 돌려줍니다. 따옴표 안의 검색 패턴은 검사에서 제외하고, `xargs`, `sudo`, `env`, 환경변수 대입 뒤의 명령도 봅니다. `git grep`, 파일을 지정한 `grep`, `find` 는 막지 않습니다. `jq`가 필요합니다.

참고로 `.claude/settings.json` 이나 `.claude/settings.local.json` 의 `defaultMode: "bypassPermissions"` 는 Claude Code 2.1.257부터 무시됩니다. bypass 는 유저 설정 `~/.claude/settings.json`, managed 설정, `--permission-mode` 플래그로만 켤 수 있습니다.

등록 예시는 commit-message 와 같은 `Bash` matcher 아래에 나란히 둡니다. `../adapters/claude/settings.example.json` 을 참고합니다.
