# 유지보수와 관리 명령

[문서 목록](../docs/README.md) · [저장소 구조](../agents/README.md) · [설치 안내](../docs/install.md)

아래 명령은 저장소 루트에서 실행합니다. 실제 홈에 연결된 주 체크아웃은 `main`에 두고, 브랜치 작업은 별도 `git worktree add`로 분리합니다.

## 명령 찾기

| 명령 | 용도 |
| --- | --- |
| `make help` | Make 타깃 목록 |
| `make deps` | macOS Homebrew로 Git·jq·ripgrep·gh 설치 |
| `make doctor` | 기본 도구와 전역 설치 상태 진단 |
| `make install-dry` / `make install` | legacy 전역 설치 미리보기 / 기존 항목 백업·교체 |
| `make uninstall` | 기록에 따른 전역 링크 제거와 백업 복원 |
| `make build` | 공통 규칙과 어댑터를 합쳐 `dist/` 생성 |
| `make check` | 저장소 전체 검사와 모든 회귀 테스트 |
| `make test` | `tests/*_test.sh`만 실행 |
| `./tooling/scripts/check-sources.sh` | 인증된 GitHub CLI로 외부 잠금 출처·경로 검증 |

추가 명령의 인자와 적용 범위는 각 안내가 소유합니다.

- [legacy·managed 설치와 제거](../docs/install.md): `scripts/install.sh`, `scripts/uninstall.sh`
- [프로젝트 점검·초기화](../docs/project-readiness.md): `scripts/project.sh`
- [외부 스킬 관리](../docs/external-skills.md): `scripts/external-skills.sh`
- [개발 환경 프로필](../environment/README.md): `environment/profile.sh`

## 변경 절차

1. [새 자산의 위치](../agents/README.md#새-자산의-위치-정하기)와 [기존 원본](../agents/README.md#ai-자산의-위치)을 확인하고 해당 원본을 수정합니다. 공통 규칙·호스트 지침 어댑터를 바꿨으면 `make build`를 실행합니다.
2. 스킬은 [추가·제거 절차](../agents/skills/README.md), 훅은 [동작·지원 호스트·실패 정책](../agents/hooks/README.md), 외부 자산은 [레지스트리와 잠금](../agents/registry/README.md)을 함께 갱신합니다.
3. 영향을 받는 사용 안내를 갱신하고, 문서 이동 시 상대 링크와 제목 앵커를 확인합니다. 문서별 원본은 [문서 목록](../docs/README.md)을 기준으로 연결합니다.
4. `make check`와 `git diff --check`를 실행하고 이번 변경의 diff를 검토합니다.

새 자산에 특정 프로젝트 경로, 비공개 조직 정보, 불필요하게 고정된 도구 버전을 넣지 않습니다. API 키·토큰·쿠키·세션·개인 키·실제 인증 설정은 저장하지 않고 예제에는 `<your-api-key>` 같은 자리표시자를 씁니다. `.gitignore`와 비밀 패턴 검사는 보조 수단입니다.

## 검증

[필요한 도구](../docs/install.md#필요한-도구)를 준비합니다. 전체 검사에는 **Python 3.11 이상**이 필요하며 `make deps`는 Python을 설치하지 않습니다.

`make check`는 필수 파일, 스킬·레지스트리 일관성, 깨진 심볼릭 링크, 셸 문법, 생성본 최신 여부, 경로 하드코딩, 비밀 패턴·파일명, 공통 규칙의 어댑터 중복, 설치 dry-run과 모든 회귀 테스트를 검사합니다. Markdown 링크 대상과 제목 앵커는 별도로 확인해야 합니다. GitHub Actions도 macOS에서 Python 3.11을 준비하고 같은 검사를 실행합니다.

기본 검사는 외부 소스를 다운로드하거나 모델을 호출하지 않습니다. chezmoi가 없으면 환경 프로필의 실제 바이너리 통합 부분은 생략합니다. `make check`는 테스트의 표준 출력을 숨기므로 세부 통과·skip 내역은 개별 테스트를 직접 실행해 확인합니다. `check-sources.sh`는 별도의 네트워크 검사이며 비밀 값은 출력하지 않습니다. 실제 호스트 로딩·훅 신뢰 상태는 `make doctor`와 회귀 테스트의 보장 범위가 아닙니다.

## 구현의 공통 원본

- `scripts/lib/owned-skills.sh`: 설치기와 진단기가 사용하는 owned 스킬 디렉터리 열거
- `scripts/lib/install-layout.sh`: 고정 설치 항목과 레이아웃·소유권 판정
- `scripts/check-owned-skills.sh`: owned 원본·발견용 별칭·registry의 일관성 검사

설치 런타임은 owned 스킬 선택에 TOML 파서를 요구하지 않습니다. 별도 외부 스킬 명령은 Python의 TOML 파서로 레지스트리와 잠금을 읽습니다.

## 평가

| 안내 | 평가 대상 |
| --- | --- |
| [제품 개발](evals/product-development/README.md) | Claude Code·Codex의 공통 결과 계약, 라우팅·행동, effort·사용량 |
| [커밋 메시지](evals/commit-message/README.md) | 생성된 호스트 지침을 받은 모델의 커밋 메시지 |
| [개편 인터페이스](evals/renewal/README.md) | 프로젝트·환경 명령 선택과 적용 경계 |

실제 모델 평가는 별도로 실행하며 사용량을 소비합니다. 평가 조건과 관찰 결과는 [문서 목록의 평가 기록](../docs/README.md#평가)에서 확인합니다.
