# 설치와 관리

[문서 목록](README.md) · [프로젝트에 적용하기](project-readiness.md)

명령은 dotagents 저장소 루트에서 실행합니다. 전역 설치는 주 체크아웃의 `main`에서 하며, 설치된 링크가 계속 이 원본을 사용하므로 체크아웃을 유지합니다. Windows는 지원하지 않습니다.

## 필요한 도구

| 용도 | 준비할 도구 |
| --- | --- |
| 기본 설치·진단·커밋 훅 | Git, Bash, make, jq, ripgrep(`rg`) |
| 전체 검사(`make check`·`make test`), 외부 스킬 명령 | 위 도구와 Python 3.11 이상 |
| 외부 소스의 GitHub 경로 검증, PR 작업 | 인증된 GitHub CLI(`gh`) |
| 선택 개발 환경 프로필 | 별도 chezmoi. [준비 방법](../environment/README.md) |

macOS Homebrew에서는 `make deps`로 Git·jq·ripgrep·gh를 설치합니다. Python과 chezmoi는 이 명령이 설치하지 않습니다. `make doctor`는 기본 도구와 전역 설치 상태를 점검하며 Python 버전이나 chezmoi 준비 여부는 검사하지 않습니다.

## 설치 방식 선택

| 방식 | 사용할 때 | 설정 처리 |
| --- | --- | --- |
| `legacy` 기본값 | `.agents` 전체와 호스트 설정을 dotagents 원본에 연결할 때 | Claude 설정·Codex 훅 설정도 링크 |
| `managed` 선택 | 다른 도구의 스킬과 사용자 설정을 함께 유지할 때 | 기존 일반 설정 파일 보존, 없을 때만 최소 훅 설정 생성 |

두 방식 모두 공통 지침과 모든 직접 만든 스킬을 연결합니다. 프로필로 일부 스킬만 고르는 기능은 없습니다. 경로별 소유권과 기록 형식의 원본은 [설치 레이아웃 설계](designs/install-layouts.md)입니다.

### legacy 설치

`make install`은 `--global --force`입니다. 충돌하는 기존 파일·디렉터리·링크를 타임스탬프가 붙은 형제 경로로 백업한 뒤 교체합니다. 백업한 설정은 활성 설정이 아니며, 이미 올바른 링크는 유지합니다.

```bash
make install-dry
# 변경 대상을 검토한 뒤
make install
make doctor
```

충돌 시 백업·교체 대신 중단하려면 아래 명령을 사용합니다.

```bash
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global
```

이 방식은 저장소의 Claude `settings.json`을 사용하므로 `bypassPermissions` 기본 모드도 적용됩니다. Codex `config.toml`과 Gemini 설정, 별도 설정 예제 파일은 설치하지 않습니다.

### managed 설치

```bash
./tooling/scripts/install.sh --dry-run --global --layout managed
./tooling/scripts/install.sh --global --layout managed
make doctor
```

공유 `.agents/skills`에는 직접 만든 스킬별 링크만 추가합니다. 기존 Claude·Codex 일반 설정 파일은 덮어쓰거나 병합하지 않습니다. 파일이 없을 때 생성한 최소 훅 설정도 이후에는 사용자 소유이며 자동 갱신하지 않습니다.

기존 설정에 필수 훅이 없으면 doctor가 안내하는 예제에서 필요한 등록만 수동 통합합니다. 공유 부모 디렉터리나 설정 경로가 심볼릭 링크이면 중단하며 `--force`로 우회할 수 없습니다. legacy에서 전환할 때는 [이행 절차](designs/install-layouts.md#이행과-제거)에 따라 기존 설치를 제거한 뒤 다시 설치합니다.

### 설치 후 확인

`make doctor`는 실제 설치 원본을 기준으로 지침·설정·스킬·훅의 연결 상태를 검사합니다. 호스트가 실제로 읽고 실행했는지까지 검사하지는 않습니다. Codex에서는 `/hooks`로 커밋 훅을 검토하고 신뢰해야 실행됩니다. [훅 동작과 예외](../agents/hooks/README.md)

전역 설치 후에는 대상 프로젝트에서 에이전트를 실행합니다. 프로젝트마다 다시 링크를 설치할 필요는 없습니다. 로컬 지침이 필요하면 [프로젝트 준비 안내](project-readiness.md)를 사용합니다.

## 갱신과 원본 이동

| 변경 | 반영 방법 |
| --- | --- |
| 공통 규칙·호스트 지침 어댑터 수정 | `make build`로 생성본 갱신 |
| 기존 스킬·훅 원본 수정 | 라이브 링크에 즉시 반영. 별도 빌드 불필요 |
| 스킬 추가·제거, 설치 경로 변경 | 사용하는 방식으로 dry-run 후 재설치 |
| 저장소 위치 이동 | 새 위치의 주 체크아웃에서 같은 방식으로 재설치 |
| managed 설정 예제 변경 | 사용자 설정에 필요한 항목만 수동 반영 |

managed 설치의 재설치에도 `--layout managed`를 명시합니다. `make install`은 legacy용이므로 기존 managed 설치 갱신에 사용하지 않습니다. 실제 홈에서 linked worktree나 다른 브랜치를 설치하려 하면 중단하고, dry-run에서는 경고만 표시합니다.

설치기는 기존 기록에 있는 관리 링크를 새 원본으로 갱신합니다. 설치 목록에서 빠진 항목은 이전 원본을 가리키는 링크만 정리하고 기록된 백업을 복원합니다. 이 정리 과정에서 사용자가 바꾼 대상은 보존합니다. 현재 설치 대상과의 충돌은 선택한 방식과 `--force` 여부에 따라 처리합니다. 스킬 추가·제거의 원본 수정 절차는 [스킬 관리](../agents/skills/README.md)를 따릅니다.

## 제거

```bash
./tooling/scripts/uninstall.sh --dry-run --global
./tooling/scripts/uninstall.sh --global
```

프로젝트에 공통 파일을 직접 링크한 경우에는 다음 명령을 사용합니다.

```bash
./tooling/scripts/uninstall.sh --dry-run --project /path/to/project
./tooling/scripts/uninstall.sh --project /path/to/project
```

기록에 있고 현재도 같은 원본을 가리키는 링크만 제거합니다. 백업은 대상 경로가 비어 있을 때 복원하며, 바뀌거나 사라진 대상은 기록과 함께 남겨 확인할 수 있게 합니다.

managed 제거는 공유 디렉터리·외부 스킬·사용자 설정을 남깁니다. 생성해 둔 최소 훅 설정도 남으므로 dotagents 훅을 더 이상 쓰지 않으면 해당 등록만 직접 제거합니다. [제거 후 남는 항목](designs/install-layouts.md#이행과-제거)

## 기록과 문제 확인

- 전역 설치 기록: `${XDG_STATE_HOME:-$HOME/.local/state}/dotagents/install.tsv`
- managed 추가 기록: 같은 위치의 `install.tsv.meta.tsv`
- 프로젝트 링크 설치 기록: `<project>/.dotagents-install.tsv`

| 증상 | 확인할 내용 |
| --- | --- |
| 링크 원본이 없거나 이동됨 | 체크아웃을 복원하거나 새 위치에서 재설치 |
| 기존 파일·공유 디렉터리와 충돌 | dry-run에서 대상과 소유권 확인 후 설치 방식 선택 |
| managed 기록 일부가 없거나 손상됨 | 남은 기록과 원본을 확인하고 복구. 기록만 지워 우회하지 않음 |
| 링크는 정상이지만 훅이 실행되지 않음 | 호스트의 설정 로딩과 Codex 훅 신뢰 상태 확인 |

설치 도중 일반 오류나 INT·TERM으로 중단되면 바뀐 링크·백업·설치 기록을 복구합니다. 복구에 실패하면 수동 처리에 필요한 경로를 남깁니다. SIGKILL·전원 차단과 제거 도중의 일괄 복구는 보장하지 않습니다. managed 설정 생성과 기록의 상세 실패 정책은 [설치 설계](designs/install-layouts.md)에 있습니다.

## 새 컴퓨터에서 복원

저장소를 사용할 위치에 clone하고 [필요한 도구](#필요한-도구)를 준비한 뒤, 선택한 방식으로 dry-run → 설치 → doctor를 실행합니다. 전체 검증은 [유지보수 안내](../tooling/README.md#검증)를 따릅니다.

로그인·인증값과 사용자 소유 설정은 로컬에서 별도로 준비합니다. [외부 스킬](external-skills.md)과 [개발 환경 프로필](../environment/README.md)도 각각 선택해 적용합니다.
