# dotagents

Claude Code, Codex, Gemini에서 함께 쓰는 스택 독립적인 개인 에이전트 기본값과 공유 도구를 관리합니다.

적용 우선순위는 **프로젝트 고유 규칙 → 도구 전용 설정 → 개인 공통 규칙**입니다. 각 프로젝트의 기술 선택과 검증 명령은 프로젝트가 정합니다.

- 전역 설치로 공통 규칙과 호스트 지침, 직접 만든 스킬을 연결하고 지원하는 호스트에 커밋 메시지 훅을 준비합니다. 각 스킬은 해당 작업에서 실행 조건에 맞춰 사용합니다. [전역 설치](docs/install.md) · [스킬 선택](agents/skills/README.md#용도별-선택-목록)
- 외부 스킬과 셸·Git 환경 예제는 필요할 때 각각 선택해 적용합니다. [외부 스킬 관리](docs/external-skills.md) · [선택 개발 환경 프로필](environment/README.md)
- 프로젝트의 기술 스택, 빌드·검증 명령과 관례는 로컬 지침에 둡니다. 기존 지침을 점검하고 지침이 없으면 로컬 템플릿으로 시작할 수 있습니다. [프로젝트 준비](docs/project-readiness.md)

## 빠른 시작

Git, Bash, make, jq, ripgrep이 필요합니다. macOS Homebrew에서는 `make deps`로 Git·jq·ripgrep·gh를 설치할 수 있습니다. 전체 검사와 외부 스킬 명령에는 **Python 3.11 이상**을 별도로 준비합니다. [설치 조건과 방식 선택](docs/install.md)

```bash
git clone https://github.com/LeeByeongMuk/dotagents.git
cd dotagents
```

처음 설치할 때는 `managed` 방식을 권장합니다. Claude의 `settings.json`과 Codex의 `hooks.json`이 일반 파일이면 그대로 사용하고, 파일이 없을 때만 최소 커밋 훅 설정을 만듭니다.

```bash
./tooling/scripts/install.sh --dry-run --global --layout managed
# 출력된 변경 대상을 확인한 뒤 실행
./tooling/scripts/install.sh --global --layout managed
make doctor
```

실제 홈에는 `main`의 주 체크아웃에서 설치하고 링크 원본인 체크아웃을 유지합니다. `make doctor`가 기존 설정에 빠진 훅 등록을 알려주면 예시를 확인해 추가합니다. Codex에서는 `/hooks`에서 훅을 검토하고 신뢰해야 실행됩니다. [managed 설치](docs/install.md#managed-설치)

`make install-dry`와 `make install`은 기존 `legacy` 방식의 미리보기와 적용 명령입니다. 적용하면 충돌 항목을 백업하고 Claude 설정 전체를 저장소 파일에 연결합니다. 이 설정에는 권한 확인을 생략하는 모드와 개인 플러그인·상태줄 구성이 포함됩니다. [legacy 설치](docs/install.md#legacy-설치)

작업별 안내는 [문서 목록](docs/README.md)에서 확인할 수 있습니다. [AI 자산 프로필](agents/profiles/README.md) · [저장소 구조](agents/README.md#새-자산의-위치-정하기)

## 수정과 검증

공통 규칙과 도구별 지침은 `agents/`에서 고치고, 생성 파일은 다시 만듭니다.

```bash
make build   # 규칙·어댑터 수정 후 dist 생성
make check   # 구조·생성본 검사와 모든 회귀 테스트
```

주 체크아웃은 `main`에 두고 브랜치 작업은 별도 worktree에서 합니다. 자산 추가와 검증 명령의 상세 내용은 [유지보수 안내](tooling/README.md)를 따릅니다.

## 라이선스

[MIT License](LICENSE)
