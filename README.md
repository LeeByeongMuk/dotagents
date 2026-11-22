# dotagents

Claude Code, Codex, Gemini에서 함께 쓰는 작업 규칙과 스킬을 모았습니다. 한 번 설치하면 프로젝트를 옮겨도 같은 커밋 메시지 규칙을 쓰고, 사용 가이드 작성이나 개발 활동 정리를 스킬에 맡길 수 있습니다.

각 에이전트는 프로젝트 지침을 가장 먼저 따릅니다. 그다음은 도구별 지침, 마지막은 이 저장소의 공통 규칙입니다.

## 빠른 시작

Git, Bash, make, jq, ripgrep이 필요합니다. 전역 설치에는 `main` 브랜치를 사용합니다. 설치 후에도 에이전트가 이 저장소의 파일을 읽으므로 계속 보관할 위치에 복제하세요.

```bash
git clone --branch main https://github.com/LeeByeongMuk/dotagents.git
cd dotagents
```

macOS에서 Homebrew를 쓴다면 여기서 `make deps`로 Git, jq, ripgrep, GitHub CLI를 설치할 수 있습니다.

**처음 설치할 때는 `managed` 방식을 권장합니다.** Claude의 `settings.json`과 Codex의 `hooks.json`이 일반 파일이면 그대로 사용합니다. 파일이 없으면 커밋 메시지 검사에 필요한 훅 설정을 만듭니다.

먼저 어떤 경로가 바뀌는지 확인하세요.

```bash
./tooling/scripts/install.sh --dry-run --global --layout managed
```

출력을 확인한 뒤 설치하고 연결 상태를 점검하세요.

```bash
./tooling/scripts/install.sh --global --layout managed
make doctor
```

`make doctor`가 빠진 훅을 알려주면 안내된 예제를 참고해 기존 설정에 추가하세요. Codex에서는 `/hooks`를 열어 훅을 검토하고 신뢰해야 실행됩니다. 설치를 마치면 평소처럼 작업할 프로젝트에서 에이전트를 시작하세요.

> **`make install`은 `legacy` 방식입니다.** 충돌하는 항목을 백업한 뒤 Claude 설정 전체를 저장소 파일에 연결합니다. 권한 확인을 생략하는 모드도 함께 적용됩니다. [설치 방식 비교와 복원 방법](docs/install.md)

## 사용 안내

- [프로젝트 지침 준비](docs/project-readiness.md) — 프로젝트에서 쓰는 빌드 명령과 팀 규칙을 에이전트에게 알려줍니다.
- [스킬과 요청 예시](agents/skills/owned/README.md) — 기본으로 설치되는 스킬이 어떤 일을 하는지 예시와 함께 살펴봅니다.
- [외부 스킬](docs/external-skills.md)과 [셸·Git 설정 예제](environment/README.md)는 필요할 때 따로 적용할 수 있습니다.

## 수정과 검증

공통 규칙은 `agents/rules/`, 도구별 지침은 `agents/adapters/`에서 수정합니다. 전역 설치에 쓰는 주 체크아웃은 `main`에 두고, 브랜치 작업은 별도 worktree에서 진행하세요.

```bash
make build   # 규칙이나 도구별 지침을 수정하면 실행
make check   # 구조, 생성 파일, 회귀 테스트 확인 (Python 3.11 이상)
```

[문서 목록](docs/README.md) · [유지보수 안내](tooling/README.md) · [MIT License](LICENSE)
