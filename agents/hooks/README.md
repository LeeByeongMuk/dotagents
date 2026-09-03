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

Claude Code의 Bash 읽기 명령 중 bypassPermissions 모드에서도 승인 프롬프트를 만드는 두 형태를 막습니다. Claude Code 2.1.259부터 `Read` deny 룰(`.env`, `*.pem`, `*.key` 등)이 하나라도 있으면 다음 명령이 차단 대신 승인 요청이 됩니다. deny 룰은 유지해야 하므로 명령 쪽을 막습니다. Grep·Read 도구는 같은 조건에서 프롬프트 없이 동작하고 deny 룰도 지킵니다.

- 재귀 검색. `rg`, `ag`, `ack`, `grep -r` 처럼 디렉터리를 훑는 명령은 그 트리에 deny 대상 파일이 있으면 프롬프트가 뜹니다. `--include` 필터를 붙여도 같습니다.
- 디렉터리를 바꾸는 `cd` 뒤의 상대 경로 읽기. `cd <레포> && grep -n … apps/x/types.ts` 처럼 cd 가 실제로 다른 디렉터리로 옮긴 뒤 상대 경로를 읽으면, 검사기가 그 경로를 확정할 수 없다며 프롬프트를 띄웁니다. 재귀가 아니어도, 비밀 파일이 아니어도, cd 대상이 절대 경로여도 걸립니다. cd 대상이 현재 디렉터리이거나 그 하위 디렉터리면 통과하고, 파일을 절대 경로로 주면 통과합니다.

`claude-pre-tool-use.sh` 는 Claude Code `PreToolUse` 훅입니다. Bash 명령을 셸 연산자 단위로 나눠 순서대로 보면서 다음을 종료 코드 2로 차단하고 대신 Grep·Read 도구나 절대 경로를 쓰라는 메시지를 돌려줍니다. `jq`가 필요합니다.

- `rg`, `ag`, `ack`, 그리고 `-r`, `-R`, `--recursive`, `-d recurse` 가 붙은 `grep`, `egrep`, `fgrep`.
- 세션 cwd 밖으로 옮기는 `cd` 또는 `pushd` 뒤에 오는 읽기 명령(`grep` 계열, `cat`, `head`, `tail`, `sed`, `awk`, `wc`, `sort`, `uniq`, `cut`, `diff`, `stat`, `file`, `jq`, `less`, `more`, `tac`, `nl`, `od`, `xxd`, `strings`)이 절대 경로가 아닌 파일 인자를 받는 경우. 옵션과 옵션 값, `grep`·`sed`·`awk`·`jq` 의 패턴 인자는 파일로 세지 않습니다. cd 대상을 변수로 준 경우는 확정할 수 없으므로 디렉터리가 바뀐 것으로 봅니다.

히어독 본문은 검사에서 제외하고, 따옴표 안 문자열은 공백 없는 한 단어(경로 등)만 남기고 나머지는 자리표시자로 바꿉니다. `xargs`, `sudo`, `env`, 환경변수 대입 뒤의 명령도 봅니다. `git grep`, cd 없이 파일을 지정한 `grep`, `find`, `ls`, 실행 명령은 막지 않습니다.

참고로 `.claude/settings.json` 이나 `.claude/settings.local.json` 의 `defaultMode: "bypassPermissions"` 는 Claude Code 2.1.257부터 무시됩니다. bypass 는 유저 설정 `~/.claude/settings.json`, managed 설정, `--permission-mode` 플래그로만 켤 수 있습니다.

등록 예시는 commit-message 와 같은 `Bash` matcher 아래에 나란히 둡니다. `../adapters/claude/settings.example.json` 을 참고합니다.
