# 선택 개발 환경 프로필

[문서 목록](../docs/README.md) · [AI 설정 설치](../docs/install.md)

셸·Git 설정 조각을 **명시적으로 적용**하는 선택 기능이다. `make install`에 포함되지 않으며 사용하지 않으면 chezmoi도 필요 없다. [AI 자산 조합 프로필](../agents/profiles/README.md)과는 별도다.

| 파일 | 적용 내용 | 활성화 |
|---|---|---|
| `source/dot_config/dotagents-environment/shell.sh` | 기존 선택이 없을 때 `EDITOR=vi`, `VISUAL=$EDITOR`, `PAGER=less`. 존재하는 `~/.local/bin`을 PATH에 중복 없이 추가 | 기존 `.zshrc` 또는 `.bashrc`에서 source |
| `source/dot_config/dotagents-environment/git.inc` | `fetch.prune=true`, histogram diff, diff3 충돌 표시 | 기존 Git 설정에서 include |
| [Brewfile](Brewfile), [packages.debian.txt](packages.debian.txt) | 저장소의 기존 Git·jq·ripgrep·gh 도구와 선택 chezmoi 설치 안내 | 아래 패키지 명령을 별도 실행 |

셸 시작 파일, `.gitconfig`, Git 이름·이메일·서명·credential helper, SSH, AI provider 설정, 토큰·세션은 프로필이 관리하지 않는다. 예제는 별도 파일에만 배치하므로 사용자 설정을 자동 병합하거나 덮어쓰지 않는다. 개인 값은 로컬 설정에 유지한다. 예: Git의 `<your-name>`·`<your-email>`은 기존 `.gitconfig`의 `[user]`에만 두고 이 소스에 복사하지 않는다.

## 격리된 환경에서 먼저 확인

[공식 설치 안내](https://www.chezmoi.io/install/)로 chezmoi를 별도 준비한다. 실행기는 다운로드나 패키지 설치를 하지 않는다. 기존 바이너리가 PATH에 없다면 `export CHEZMOI_BIN=/absolute/path/to/chezmoi`로 지정한다. 검증 기준은 chezmoi `2.74.1`이다.

저장소 루트의 Bash 또는 zsh에서 실행한다. source·destination·config·state·cache 다섯 경로를 매번 명시한다. 임시 경로 안의 source에 예제를 복사해 Git 저장소를 초기화하며, 커밋·원격 연결·자동 apply는 하지 않는다.

```bash
profile_root=$(mktemp -d "${TMPDIR:-/tmp}/dotagents-environment.XXXXXX")
mkdir "$profile_root/destination"
profile_args=(
  --source "$profile_root/source"
  --destination "$profile_root/destination"
  --config "$profile_root/config/chezmoi.toml"
  --state "$profile_root/state/chezmoi.boltdb"
  --cache "$profile_root/cache"
)
./environment/profile.sh init "${profile_args[@]}"
./environment/profile.sh preview "${profile_args[@]}"
```

`init`은 새 source만 허용한다. 기존 source와 config는 덮어쓰지 않는다. config·state·cache는 source 밖의 프로필 전용 경로에 둔다. 기존 다른 chezmoi 프로필의 config를 재사용하면 그 hooks·자동화 설정도 적용될 수 있다. `preview`와 `status`는 destination에 프로필 조각을 적용하지 않지만 chezmoi 내부 상태 파일은 만들 수 있다.

diff를 검토한 뒤 다음 명령으로 임시 destination에 적용한다.

```bash
./environment/profile.sh apply "${profile_args[@]}"
./environment/profile.sh status "${profile_args[@]}"
```

source의 파일을 고친 뒤 `preview` → `apply`를 반복한다. 적용은 복사 방식이며 소스 수정이 즉시 반영되지 않는다. 실행기는 [chezmoi의 `--error-on-conflict`](https://www.chezmoi.io/reference/command-line-flags/global/#--error-on-conflict-bool)로 이미 적용한 대상의 사용자 수정과 충돌하면 실패한다. 최초 적용의 기존 파일에는 `--less-interactive`로 확인을 요구하며, 비대화형 입력이 비어 있으면 실패한다. `--error-on-conflict` 하나만으로는 최초 기존 파일 보존을 보장하지 않는다. 여러 파일 적용은 트랜잭션이 아니므로 앞 파일은 이미 바뀌었을 수 있다. 백업·되돌리기와 실제 비교 결과는 [배포 비교](../docs/designs/environment-profile.md)를 확인한다.

## 실제 사용자 환경에서 사용

임시 실행을 검토한 뒤 별도의 지속 경로와 `--destination "$HOME"`을 선택해 같은 init → preview → apply 명령을 실행한다. 실제 적용은 사용자가 선택하는 별도 단계다. destination은 이미 존재해야 하며 모든 경로는 절대 경로여야 한다. source·config·state·cache는 적용 경로인 `$HOME/.config/dotagents-environment/`와 겹치지 않는 곳에 둔다. 예를 들어 `$HOME/.local/dotagents-env-profile/` 아래에 네 경로를 나란히 둘 수 있다. 여러 기기는 source만 Git으로 공유하고 config·state·cache는 기기별로 둔다. 원격 저장소 생성·push는 자동화하지 않는다.

적용 후 기존 `.zshrc` 또는 `.bashrc`에 다음 행을 직접 추가해 활성화한다. 개인 override는 이 행 뒤에 둔다.

```sh
[ ! -r "$HOME/.config/dotagents-environment/shell.sh" ] || . "$HOME/.config/dotagents-environment/shell.sh"
```

기존 `.gitconfig`에는 아래 조각을 추가한다. 동일 키에 대한 사용자 override를 유지하려면 이 include 뒤에 둔다. 이 프로필의 파일 위치는 `$XDG_CONFIG_HOME` 대신 destination 기준 `.config/`로 고정돼 있다.

```gitconfig
[include]
    path = ~/.config/dotagents-environment/git.inc
```

### 비활성화와 관리 중단

Git은 include를 제거하면 이후 실행부터 해당 조각을 읽지 않는다. 셸은 시작 파일의 source 행을 제거하고 새 세션에서 확인한다. 이미 열린 셸의 환경 변수·PATH는 source 행을 제거해도 되돌아가지 않는다.

적용 파일을 보존하면서 관리만 중단하려면 동일한 격리 경로 인자로 [chezmoi forget](https://www.chezmoi.io/reference/commands/forget/)을 사용한다. `destroy`는 source와 destination 양쪽을 삭제하며, 기존 AI 제거기의 백업 복원과 다르다. 일반 제거 명령으로 권하지 않는다.

## 패키지 준비도 별도 선택

아래 목록을 확인한 뒤 필요한 설치 명령만 실행한다. 프로필 init·preview·apply가 패키지 설치를 실행하지는 않는다. 언어 런타임, Node/Python 버전, GUI 앱, 로그인은 프로젝트 또는 로컬 환경이 소유한다. 전체 `make check`에 필요한 Python 3.11 이상도 패키지 목록에 포함되지 않는다.

macOS에서 이미 Homebrew를 사용하는 경우:

```bash
cat environment/Brewfile
brew bundle check --file=environment/Brewfile
# 설치하기로 정한 경우에만:
brew bundle install --file=environment/Brewfile
```

[Homebrew bundle](https://docs.brew.sh/Manpage#bundle-subcommand)의 check는 누락 항목을 검사하고 install은 설치한다. `brew bundle cleanup`은 사용하지 않는다.

Debian/Ubuntu에서:

```bash
cat environment/packages.debian.txt
apt_packages=$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' environment/packages.debian.txt)
printf '%s\n' "$apt_packages" | xargs apt-get --simulate install --no-install-recommends
# 설치하기로 정한 경우에만:
sudo apt-get update
printf '%s\n' "$apt_packages" | xargs sudo apt-get install --no-install-recommends
```

`gh`는 [Debian stable](https://packages.debian.org/stable/gh)과 [Ubuntu 24.04의 universe](https://packages.ubuntu.com/noble/gh)에 있다. 배포판·저장소별 가용성은 위 simulate로 확인한다. chezmoi는 apt 목록에서 분리했으며, [공식 사전 빌드 패키지·바이너리와 검증 안내](https://www.chezmoi.io/install/#verify-your-download)에 따라 해당 OS/아키텍처를 골라 설치한다. 로컬 바이너리라면 `CHEZMOI_BIN`으로 선택할 수 있다.

검증된 범위와 실행하지 않은 설치 작업은 [배포 비교의 검증 결과](../docs/designs/environment-profile.md#검증-결과와-범위)에 기록되어 있다.

## 검사

```bash
make check
# 별도 준비된 실제 chezmoi 바이너리로 통합 검사까지 실행:
CHEZMOI_BIN=/absolute/path/to/chezmoi ./tooling/tests/environment_test.sh
# 기존 링크 설치와 명시적 적용의 제한된 비교:
CHEZMOI_BIN=/absolute/path/to/chezmoi ./environment/compare.sh
```

기본 검사는 네트워크 없이 경로 전달, 기존 설정 보존, 셸·Git 조각 동작을 확인한다. chezmoi가 있으면 임시 경로의 실제 통합 검사도 실행하며, 없으면 해당 통합 부분의 skip을 출력한다.
