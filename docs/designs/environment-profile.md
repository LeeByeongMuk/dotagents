# 선택 환경 프로필과 제한된 배포 비교

현재 AI 자산은 기존 링크 설치기로 유지한다. 일반 개발 환경의 설정 조각은 별도의 선택 [environment 프로필](../../environment/README.md)로 명시적 적용을 제공한다. chezmoi를 일반 dotfiles 엔진으로 사용하며 별도 동기화·템플릿·백업 관리자를 구현하지 않는다. 이 문서는 환경 프로필의 운영 경계와 실제 비교 근거만 소유한다.

## 소유 경계

| 대상 | 소유자와 적용 방식 |
|---|---|
| 공통 AI 규칙·스킬·현재 호스트 설정 | 기존 `tooling/scripts/install.sh`; 이번 프로필과 무관 |
| 이동 가능한 셸·Git 조각 | 사용자가 선택한 별도 chezmoi source → destination의 `.config/dotagents-environment/` |
| 셸 시작 파일과 기존 Git 설정 | 사용자 소유. 수동 include로 활성화 |
| config·persistent state·cache | 기기별 전용 경로. source와 함께 Git으로 공유하지 않음 |
| 이름·이메일·서명·credential helper·인증·세션·AI provider 설정 | 로컬 사용자·도구 소유. 예제 source에 없음 |
| 패키지 | 기존 도구 목록에 기반한 선택 Brewfile/apt 목록. 적용 과정에서 자동 설치하지 않음 |

프로필은 새 source를 초기화하고 명시적 경로를 chezmoi에 전달하는 작은 진입점이다. 복구 트랜잭션이나 기존 파일 백업을 추가하지 않는다. `preview`/`status`는 destination에 쓰지 않는다. chezmoi 내부 상태에는 쓸 수 있다. `apply`는 기록된 대상의 사용자 수정과 충돌하면 실패하고 최초 기존 대상에는 확인을 요구한다. 기본 확인 입력을 자동으로 승인하거나 `--force`를 전달하지 않는다.

## 실험 조건과 재현

2026-11-17 macOS `27.0` arm64, Bash `3.2.57`, 저장소 기준 `3b6145f`의 기존 설치기를 사용했다. chezmoi `v2.74.1`의 공식 `darwin_arm64` 릴리스 아카이브를 임시 디렉터리에 내려받아 SHA256을 공식 checksums 파일과 대조한 뒤 바이너리만 풀었다. 전역 패키지 설치·실제 홈 적용·다른 저장소 수정은 하지 않았다.

- 릴리스: [twpayne/chezmoi v2.74.1](https://github.com/twpayne/chezmoi/releases/tag/v2.74.1)
- 검증한 아카이브: `chezmoi_2.74.1_darwin_arm64.tar.gz`
- SHA256: `fbc7b86c7b36eb0448e2a99a616b6d32f022d1f3895076ad44f4c5d65a77fe60`
- 바이너리 commit: `2f68f47e745f69f78c137f46d4abe29230b74aa1`

동일 fixture는 `.claude/settings.json`, `.codex/hooks.json` 두 경로의 작은 JSON이다. 내용은 `{"fixture":"v1"}` 계열의 가상 값이며 실제 설정·인증을 수집하지 않았다. 기존 설치기는 그 외 AI 링크도 계속 설치한다. 따라서 이 실험은 두 표본의 배포 의미를 비교하며 설치기 전체의 기능 동등성·이전 완료를 검증하지 않는다.

[compare.sh](../../environment/compare.sh)는 source·destination·config·persistent state·cache를 모두 임시 경로로 분리한다. 직접 chezmoi 호출의 HOME도 임시 경로다. 기존 설치기에는 임시 `DOTAGENTS_HOME`·`XDG_STATE_HOME`을 전달한다. 종료 시 fixture를 지운다. 네트워크 호출은 스크립트 안에 없다.

비교 fixture에는 현재 checkout의 `tooling/scripts/` 전체를 복사해 설치기의 runtime helper도 함께 포함한다. 충돌을 만들기 전에 빈 fixture의 dry-run·실제 설치·제거가 성공하는지 확인하고, 이후 예상 실패는 실제 충돌 메시지도 확인한다. 원래 `3b6145f` 기준의 비교 관찰과 별개로, helper를 도입한 설치기와 조합해도 이 비교가 실행되는지 확인하는 호환성 장치다.

```bash
CHEZMOI_BIN=/absolute/path/to/verified/chezmoi ./environment/compare.sh
CHEZMOI_BIN=/absolute/path/to/verified/chezmoi ./tooling/tests/environment_test.sh
CHEZMOI_BIN=/absolute/path/to/verified/chezmoi make check
git diff --check
```

## 실제 관찰

아래 행은 `compare.sh`의 실제 단언을 통과했다. chezmoi 명령에는 `--mode file --less-interactive --error-on-conflict --no-tty`를 사용했다. 강제 적용은 가상 fixture의 보장 차이를 확인하기 위한 명시적 실험이며 환경 프로필은 제공하지 않는다.

| 시나리오 | 기존 링크 설치 | chezmoi 명시적 적용 |
|---|---|---|
| 최초 사용자 파일 충돌 | preflight에서 실패. 사용자 파일과 나머지 설치 대상 무변경 | `--less-interactive`에서 확인 입력이 없으면 실패. 충돌 파일 보존. 모든 다른 파일의 무변경은 보장하지 않음 |
| 강제 적용과 반복 | 기존 파일을 기록된 형제 백업으로 옮겨 링크 설치. 재설치 가능 | `--force apply`는 덮어씀. 실험이 수동 백업을 만들었으며 chezmoi가 복구용 원본 백업을 만든 것은 아님. 재적용 후 status가 비어 있음 |
| source 변경·드리프트 | 즉시 target에서 새 내용이 보임 | target은 이전 내용 유지. status가 차이를 표시. apply 후 수렴 |
| target을 직접 편집 | 링크를 따라 checkout source가 바뀜 | source는 그대로. 다음 apply가 충돌 실패하고 target 편집 보존 |
| 뒤 파일 충돌 | 충돌 preflight는 전체 변경 전에 수행 | 첫 파일을 새 버전으로 적용한 뒤 두 번째 파일 충돌로 실패. 첫 변경은 남음 |
| 적용 도중 실행 오류 | 별도 임시 홈에서 두 번째 JSON 대상의 `ln` 실패를 주입. 앞 링크 제거, 두 원본 복원, 설치 manifest 미발행 확인 | 앞 행의 충돌 실패로 batch rollback 부재 관찰. 동일한 `ln` 주입은 사용하지 않음 |
| 제거·반복 적용 | 소유 링크 제거 후 원래 사용자 백업 복원. 제거 반복 가능 | source 파일만 삭제하면 target은 남음. `destroy` 후 source·target이 없어지고 원본 백업 복원은 없었음. 반복 destroy는 비관리 대상 오류. 이후 apply가 제거 대상을 되살리지 않음 |
| 사용자가 링크 대신 새 파일을 놓음 | uninstall이 사용자 대체 파일 보존 | 별도 대응 동작을 억지로 맞추지 않음. 기록된 target 편집 보존은 위에서 확인 |

별도의 실제 CLI 확인에서 `--error-on-conflict`만 사용한 최초 적용은 기존 파일을 덮어썼다. 기록된 이전 내용이 없는 경우와 이미 관리한 파일의 충돌을 구분해야 한다. 따라서 프로필은 `--less-interactive`도 지정한다. 이 동작은 실험 버전에 대한 관찰이며 향후 버전도 실제 통합 검사로 확인한다.

사용자 파일의 보존과 적용 전체의 원자성은 별개다. chezmoi의 [apply 문서](https://www.chezmoi.io/reference/commands/apply/)는 대상 상태로 맞추고 이전 적용 이후 수정된 파일에 확인을 요구한다고 설명한다. [전역 플래그 문서](https://www.chezmoi.io/reference/command-line-flags/global/)의 `--less-interactive`, `--error-on-conflict`, source/destination/config/cache/state 옵션과 실제 동작을 함께 확인했다. [destroy](https://www.chezmoi.io/reference/commands/destroy/)는 양쪽 파일을 영구 삭제하며 백업 복원 명령이 아니다.

공식 destroy 문서의 state 제거는 해당 관리 대상의 persistent-state entry를 뜻하며 전체 state DB·config·cache를 삭제한다는 의미가 아니다. 이 실험의 직접 단언은 source·target 제거와 이후 apply의 비복원이며 DB 내부 entry 삭제 자체를 검사하지는 않았다.

## 검증 결과와 범위

| 검사 | 결과 |
|---|---|
| 실제 `environment_test.sh` | PASS — 새 source 초기화, config 보존, 기존 source 재초기화 거부, 공백 경로, preview 무적용, 최초 기존 조각 충돌, 적용·반복·드리프트, source 변경의 명시적 반영, target 편집 보존, 기존 `.gitconfig`·`.zshrc`·`.bashrc` 보존 |
| 엔진 없이 기본 검사 | PASS — 누락 경로 거부, preview 경로 전달·apply 미호출, 셸 사용자 선택·PATH 중복 방지, Git 조각 유효성·identity/auth 비소유. 실제 엔진 부분은 skip으로 표시 |
| 실제 `compare.sh` | PASS — 표의 여덟 비교 시나리오, 임시 fixture만 사용 |
| runtime helper 통합 호환성 | PASS — standalone 환경 브랜치와 `b3b6ef1`의 설치 스크립트·helper를 조합한 임시 사본에서 legacy 기본값 비교. helper를 일부러 제거한 사본은 최초 dry-run에서 실패하며 충돌 PASS를 출력하지 않음 |
| 실제 엔진을 지정한 `make check`·`git diff --check` | PASS — 종료 0. 기존 회귀 검사 전체와 새 환경 검사, 생성본 최신 여부, 설치 dry-run 통과 |

실제 호스트의 설정 로딩, 여러 기기 동기화, macOS Homebrew·Debian/Ubuntu apt 설치, Debian/Ubuntu에서의 프로필 실행은 미검증이다. 패키지 목록은 공식 패키지 정보와 기존 저장소 도구 목록으로 작성했으며 설치 성공을 주장하지 않는다. 명시적 적용의 INT/TERM/SIGKILL·전원 차단 복구나 disk-full 복구도 이 실험으로 보장하지 않는다. 기존 설치기의 INT/TERM 복구는 기존 회귀 검사가 담당하며, 제거 명령 자체의 중단 rollback과 SIGKILL·전원 차단은 기존 보장에도 포함되지 않는다.

## PR 판단에 남기는 차이

선택 환경 프로필은 일반 dotfiles의 명시적 검토·적용 경로로 사용할 수 있다. 기존 AI 설치를 chezmoi로 옮기려면 11개 전역·9개 프로젝트 대상, owned 스킬 발견, 기존 설치 기록·백업의 이행, retired 처리, doctor 기대값을 따로 다뤄야 한다. 이번 작은 프로필을 병합해도 AI 배포 전환을 결정한 것은 아니다.

전환하면 source의 즉시 반영과 호스트의 checkout 직접 쓰기를 줄일 수 있지만 별도 적용·로컬 충돌 해결이 필요하다. 기존 설치기의 실행 오류/INT/TERM 복구와 백업 복원 보장을 유지하려면 추가 이행 작업이 필요하고, chezmoi 기본 batch 동작을 택하면 그 보장 차이를 수용하는 결정이 필요하다. 두 방식에 같은 복구 구현을 요구하지 않으며 이 실험으로 동일한 보장을 주장하지 않는다.
