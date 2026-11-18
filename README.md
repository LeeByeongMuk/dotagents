# dotagents

Claude Code, Codex, Gemini에서 함께 쓰는 개인 AI 개발 설정 저장소입니다. 공통 규칙, 스킬, 훅과 프로젝트 템플릿을 한곳에서 관리하고 여러 프로젝트에 재사용합니다.

적용 우선순위는 **프로젝트 고유 규칙 → 도구 전용 설정 → 개인 공통 규칙**입니다. 각 프로젝트의 기술 선택과 검증 명령은 프로젝트가 정합니다.

## 빠른 시작

Git, Bash, make, jq, ripgrep이 필요합니다. macOS Homebrew에서는 `make deps`로 Git·jq·ripgrep·gh를 설치할 수 있습니다. 전체 검사와 외부 스킬 명령에는 **Python 3.11 이상**을 별도로 준비합니다. [설치 조건과 방식 선택](docs/install.md)

```bash
git clone https://github.com/LeeByeongMuk/dotagents.git
cd dotagents
```

아래는 기본 `legacy` 설치입니다. **`make install`은 충돌하는 기존 항목을 백업하고 저장소 링크로 교체합니다.** Claude 설정과 Codex 훅 설정도 대상입니다. 기존 설정과 다른 도구의 스킬을 함께 유지하려면 [managed 설치](docs/install.md#managed-설치)를 먼저 확인하세요.

```bash
make install-dry
# 출력된 변경 대상을 확인한 뒤 실행
make install
make doctor
```

실제 홈에는 `main`의 주 체크아웃에서 설치합니다. 설치한 저장소는 링크의 원본이므로 유지해야 합니다. Codex 커밋 훅은 설치 후 `/hooks`에서 검토하고 신뢰해야 실행됩니다.

## 할 수 있는 일

| 작업 | 안내 |
| --- | --- |
| 전역 설치, 갱신, 제거와 새 컴퓨터 복원 | [설치 안내](docs/install.md) |
| 프로젝트 지침·컨텍스트 점검과 초기화 | [프로젝트 준비](docs/project-readiness.md) |
| 환경과 작업에 맞는 스킬 선택 | [용도별 선택 목록](agents/skills/README.md#용도별-선택-목록) |
| 제품 개발, FSD 리팩터링, 공통 관례 반영, 사용 가이드, 저장소 활동 정리 | [직접 만든 스킬과 사용 예](agents/skills/owned/README.md) |
| 기획은 Plan, 구현은 Brief → Execute → Verify로 진행 | [제품 개발 워크플로우](agents/workflows/product-development/WORKFLOW.md) |
| 커밋 메시지 검사와 프로젝트별 예외 설정 | [훅 안내](agents/hooks/README.md) |
| 선택한 외부 스킬을 고정 커밋으로 설치·갱신·제거 | [외부 스킬 관리](docs/external-skills.md) |
| 셸·Git 설정 조각을 선택적으로 적용 | [개발 환경 프로필](environment/README.md) |
| Codex 모델·권한·CLI 프로필 설정 | [Codex 설정](agents/adapters/codex/README.md) |

외부 스킬과 개발 환경 프로필은 별도 명령으로 선택해 적용합니다. 기본 전역 설치에는 포함되지 않습니다. MCP·플러그인 자동 설치, AI 자산 프로필 합성, Gemini 커밋 훅 연결은 아직 제공하지 않습니다.

전체 문서는 [문서 목록](docs/README.md)에서, 원본의 위치와 역할은 [저장소 구조](agents/README.md)에서 확인할 수 있습니다.

## 수정과 검증

공통 규칙과 도구별 지침은 `agents/`에서 고치고, 생성 파일은 다시 만듭니다.

```bash
make build   # 규칙·어댑터 수정 후 dist 생성
make check   # 구조·생성본 검사와 모든 회귀 테스트
```

주 체크아웃은 `main`에 두고 브랜치 작업은 별도 worktree에서 합니다. 자산 추가와 검증 명령의 상세 내용은 [유지보수 안내](tooling/README.md)를 따릅니다.

## 라이선스

[MIT License](LICENSE)
