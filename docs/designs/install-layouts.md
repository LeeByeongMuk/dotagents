# 전역 설치 layout과 소유권

[설치 사용 안내](../install.md) · [문서 목록](../README.md)

전역 설치의 기본값은 `legacy`이며 `--layout managed`가 공유 스킬 디렉터리와 사용자 설정의 소유권을 분리하는 선택입니다. 프로젝트 설치는 기존 legacy 링크 방식을 유지하며 managed 옵션을 받지 않습니다. owned 스킬 선택·추가·제거 절차는 [스킬 안내](../../agents/skills/README.md)가 소유합니다.

| 대상 | legacy 기본값 | managed 선택 |
|---|---|---|
| `~/.agents` | checkout의 `agents/` 전체 링크 | 기존 내용을 보존하는 실제 디렉터리 |
| `~/.agents/skills` | 원본 checkout 안의 디렉터리 | 실제 공유 디렉터리, owned 스킬별 링크만 관리 |
| `~/.agents/rules`, `hooks`, `templates` | 전체 링크를 통해 접근 | 각각 원본 디렉터리를 가리키는 관리 링크 |
| Claude 스킬 | owned 스킬별 링크 | owned 스킬별 링크 |
| 호스트 지침 | `dist/`의 생성된 진입점 링크 | 같은 생성된 진입점 링크 |
| Claude `settings.json`, Codex `hooks.json` | 추적된 설정 파일 링크 | 없을 때만 최소 hook JSON을 일반 파일로 복사 |
| 설치 기록 | 기존 3열 `install.tsv` | managed 표식 + 같은 3열 링크 행 + metadata sidecar |

고정 항목의 경로·원본·종류·진단 라벨은 `tooling/scripts/lib/install-layout.sh`의 `fixed_install_entries`가 정의하고 설치기와 doctor가 함께 사용합니다. 스킬 집합은 별도의 공용 owned 디렉터리 열거를 사용합니다. registry는 설치 정책이 아닙니다.

## 선택과 충돌

```sh
./tooling/scripts/install.sh --dry-run --global --layout managed
./tooling/scripts/install.sh --global --layout managed
```

재설치·원본 checkout 이동 후 갱신에도 `--layout managed`를 명시합니다. `--force`가 없으면 기존 관리 대상과의 충돌은 무변경 중단합니다. `--force`는 owned 링크의 충돌 대상을 백업한 뒤 교체하며 제거 시 기록된 백업을 복원합니다. `~/.agents`와 `~/.agents/skills` 자체는 교체 대상이 아니므로 다른 도구의 스킬·메모·폴더를 옮기거나 삭제하지 않습니다. 스킬 이름이 실제 관리 대상과 같다면 충돌로 취급합니다.

managed 모드에서는 대상의 부모가 심볼릭 링크이면 설치·retired 처리·제거 전에 중단합니다. `--force`로 우회할 수 없습니다. 특히 legacy `~/.agents` 링크를 따라 원본 checkout에 스킬 링크나 설정을 쓰는 전환은 허용하지 않습니다. 설정 경로가 심볼릭 링크여도 managed 설치를 거부하며, 사용자가 원본과 소유권을 검토해 일반 파일로 바꾼 뒤 다시 실행해야 합니다.

rules·hooks·templates와 각 owned 스킬은 계속 원본 checkout을 가리키는 라이브 링크입니다. 그 안을 직접 편집하면 원본이 바뀝니다. 이 모드는 공유 `skills` 디렉터리에 다른 도구가 스킬을 추가하는 일을 원본 checkout 쓰기와 분리하며, 원본 전체를 읽기 전용 배포본으로 만들지는 않습니다.

## 사용자 설정과 hook 등록

managed 설치는 다음 파일이 없을 때만 seed를 만듭니다.

- `~/.claude/settings.json`: [최소 Claude hook 예시](../../agents/adapters/claude/hooks.example.json)의 복사본
- `~/.codex/hooks.json`: [Codex hook 설정](../../agents/adapters/codex/hooks.json)의 복사본

두 seed의 최상위 키는 `hooks`뿐입니다. `hooks.PreToolUse`에 Claude는 `matcher: "Bash"`, Codex는 `matcher: "^Bash$"`인 항목을 두고, 내부 `hooks` 배열에 `type: "command"`와 다음 명령을 등록합니다.

```text
"$HOME"/.agents/hooks/commit-message/pre-tool-use.sh
```

Codex seed는 `timeout: 30`도 포함합니다. doctor가 검사하는 필수 계약은 위 matcher·type·command의 정확한 등록이며 timeout은 검사하지 않습니다. 기존 설정의 다른 키나 다른 hook은 유지할 수 있습니다. 기존 일반 파일은 JSON이 비었거나 잘못되어도, `--force`로 재설치해도 덮어쓰거나 병합하지 않습니다. 기존 파일에 필수 등록이 없으면 doctor가 예시 경로와 수동 통합 방법을 알리고 실패합니다. 진단은 설정 내용이나 비밀 값을 출력하지 않습니다.

설정 이름이 비어 있을 때만 완성된 seed를 하드 링크로 게시합니다. 설정 디렉터리가 있는 파일시스템에서 하드 링크를 지원해야 합니다. 게시 직전에 호스트가 일반 파일을 만들면 보존하고 설치를 계속합니다. 디렉터리나 심볼릭 링크가 생기면 그 경로를 보존하고 설치를 중단합니다.

seed는 생성 즉시 사용자가 소유하는 일반 파일입니다. 설치 ledger에 넣지 않으며 이후 원본 예시 변경을 자동 반영하지 않습니다. 호스트가 쓰거나 사용자가 수정해도 추적된 원본 설정으로 쓰기가 전달되지 않습니다. 설치 중 실패·INT·TERM으로 롤백할 때는 이번 설치에서 게시한 inode와 게시 전 바이트가 유지되는지 확인한 뒤 seed를 제거합니다. 확인 시 호스트가 수정·교체한 설정은 보존하며, 확인과 제거는 별도 작업입니다.

doctor의 등록 검사는 호스트 로딩·실행 성공이나 Codex hook 신뢰 상태를 보장하지 않습니다. 실제 홈에서 필요한 수동 통합과 `/hooks` 신뢰 설정은 사용자가 확인합니다. 테스트는 임시 홈에서 파일 구조와 복구만 검증합니다.

## 기록과 진단

전역 ledger는 `${XDG_STATE_HOME:-$HOME/.local/state}/dotagents/install.tsv`입니다. managed ledger의 첫 줄은 `# dotagents-layout=managed-v1`이며 나머지 링크 행은 기존과 같은 `대상<TAB>원본<TAB>백업` 3열입니다. seed와 공유 부모 디렉터리는 링크 행에 넣지 않습니다. legacy ledger에는 이 표식을 추가하지 않습니다.

managed sidecar는 `install.tsv.meta.tsv`이며 다음 네 필드만 허용합니다. 값은 실제 절대 경로로 기록합니다.

```text
version<TAB>1
layout<TAB>managed
agents<TAB><checkout의 절대 경로>/agents
target_root<TAB><설치 홈의 절대 경로>
```

필드 누락·중복·알 수 없는 키·지원하지 않는 버전·다른 target root·잘못된 source 형식·ledger 표식 누락은 중단 사유입니다. ledger와 metadata는 한 설치 transaction에서 저장하며 일반 오류·INT·TERM이면 이전 둘을 함께 복원합니다. SIGKILL·전원 차단이나 제거 명령 자체의 중단 rollback은 보장하지 않습니다.

doctor는 managed metadata에 기록된 원본을 검사합니다. 명령을 실행한 checkout이나 임의의 실제 `~/.agents` 디렉터리에서 소유권을 추정하지 않습니다. ledger와 metadata 중 하나만 사라졌으면 설치·제거·진단이 실패하며 먼저 기록을 복구해야 합니다. 부분 제거로 수정된 대상만 ledger에 남아 있어도 managed 표식과 metadata를 보존합니다. 둘 다 지운 상태의 소유권을 복구하는 탐색기는 제공하지 않습니다.

legacy는 sidecar 없이 기존 `.agents` ledger 행을 계속 사용합니다. ledger 없는 과거 설치는 `.agents`가 심볼릭 링크이며 원본의 `rules/git.md`가 있을 때 기존 방식으로 인식합니다. 단순히 같은 파일이 들어 있는 실제 공유 디렉터리는 설치로 간주하지 않습니다.

전역에 설치된 `dotagents-promote`는 legacy `.agents` 링크 또는 managed ledger·metadata와 실제 rules 링크를 검증해 스킬을 제공하는 원본을 확인합니다. 승격 worktree는 이 원본이 `main`에 있는 주 체크아웃일 때 생성할 수 있습니다. [dotagents-promote 스킬](../../agents/skills/owned/dotagents-promote/SKILL.md)

## 이행과 제거

layout 간 자동 변환은 제공하지 않습니다. 기존 설치의 dry-run과 사용자 변경·백업을 먼저 검토하고 명시적으로 제거한 뒤 새 layout으로 설치합니다.

```sh
./tooling/scripts/uninstall.sh --dry-run --global
./tooling/scripts/uninstall.sh --global
./tooling/scripts/install.sh --dry-run --global --layout managed
./tooling/scripts/install.sh --global --layout managed
```

수정된 대상 때문에 ledger가 남으면 먼저 해당 대상과 백업을 검토해 제거를 완료해야 합니다. managed 설정 symlink나 공유 부모 symlink도 사용자의 검토 없이 자동 변환하지 않습니다. legacy로 돌아갈 때도 명시적 제거를 거치며, 남아 있는 공유 디렉터리·외부 스킬을 보존할 방법을 먼저 결정합니다.

managed 제거는 기록된 링크와 그 백업만 처리합니다. 외부 스킬, 공유 디렉터리, 사용자가 바꾼 대상과 설정 seed는 남깁니다. 마지막 관리 링크 제거가 끝나면 ledger와 metadata를 함께 지웁니다. 남은 seed의 hook 등록은 자동 삭제하지 않으므로 dotagents hook을 더 이상 쓰지 않으면 사용자 설정에서 직접 제거해야 합니다. 설정 파일을 통째로 지우거나 다른 hook을 변경할 필요는 없습니다.
