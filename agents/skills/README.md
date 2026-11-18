# Skills

## 용도별 선택 목록

프로젝트 환경과 지금 필요한 작업을 기준으로 스킬을 고릅니다. ★는 사용자가 자주 쓴다고 확인한 스킬에 붙입니다. 현재 즐겨찾기는 비어 있습니다.

| 환경 | 작업 | 스킬 |
| --- | --- | --- |
| 공통 | 제품 기획, 구현과 검증 | [product-development-workflow](owned/product-development-workflow/SKILL.md) |
| 공통 | 아이디어 검토, 요구사항 구체화 | 선택형 외부 스킬 `gstack-office-hours`, `mattpocock-grilling` |
| 공통 | 구현 계획 정리 | 선택형 외부 스킬 `superpowers-writing-plans`, `gstack-autoplan` |
| 공통 | 코드 변경 검토 | 선택형 외부 스킬 `gstack-review` |
| 공통 | 저장소 활동 요약, 사용자 가이드 작성 | [repo-activity-review](owned/repo-activity-review/SKILL.md), [usage-guide](owned/usage-guide/SKILL.md) |
| 공통 | 여러 프로젝트에서 쓸 관례를 dotagents에 반영 | [dotagents-promote](owned/dotagents-promote/SKILL.md) |
| 프론트엔드 | 웹 UI, 브라우저 API와 호환성 가이드 조회 | 선택형 외부 스킬 [modern-web-guidance](../integrations/skills/modern-web-guidance/README.md) |
| 프론트엔드 | FSD를 이미 채택한 프로젝트의 구조 정리 | [fsd-refactor](owned/fsd-refactor/SKILL.md) |
| 프론트엔드 | 브라우저에서 사용자 흐름 검증 | 선택형 외부 스킬 `gstack-qa` |
| 백엔드 | API, 데이터, 서버 작업 | 공통 스킬을 사용하고, 전용 스킬은 검토와 실제 사용을 거친 뒤 등록합니다. |

즐겨찾기와 환경 분류는 선택을 돕는 표시입니다. 외부 스킬을 사용할 때는 대상 호스트와 프로젝트를 지정해 연결합니다. 등록 정보는 [skills.toml](../registry/skills.toml), 출처와 고정 버전은 [sources.lock](../registry/sources.lock), 설치·갱신·제거 절차는 [외부 스킬 관리 안내](../../docs/external-skills.md)에서 확인할 수 있습니다.

## 직접 만든 스킬 관리

직접 만든 스킬은 `owned/<name>/SKILL.md`에 둡니다. 외부 스킬을 수정하지 않고 보정해야 하면 `wrappers/<name>/SKILL.md`를 그때 만듭니다.

`owned/<name>/SKILL.md`가 있는 모든 디렉터리가 전역·프로젝트 설치 대상입니다. `tooling/scripts/lib/owned-skills.sh`가 이 집합을 한 번 정의하며, 설치기는 Claude의 개별 링크를 만들고 Codex·Gemini는 공통 `.agents/skills/` 별칭을 사용합니다. 진단기는 [설치 layout](../../docs/designs/install-layouts.md)에 따라 확인한 실제 설치 원본의 디렉터리를 기준으로 아직 설치되지 않은 스킬도 검사합니다. 명령을 실행한 checkout이나 설치 기록의 목록으로 기대 집합을 대신하지 않습니다.

스킬을 추가할 때는 다음 세 자산을 함께 만듭니다.

1. 소문자 영문·숫자로 시작하고 소문자 영문·숫자·하이픈만 쓰는 `owned/<name>/SKILL.md` 원본 디렉터리
2. 이 디렉터리의 `<name>` → `owned/<name>` 상대 심볼릭 링크
3. `../registry/skills.toml`의 같은 ID·`kind = "owned"`·`source = "agents/skills/owned/<name>"` 메타데이터

설치기·진단기·테스트 준비 목록에는 이름을 추가하지 않습니다. `make check`는 모든 owned 원본의 별칭과 registry ID·원본 경로가 일치하는지 검사합니다. 루트 별칭은 발견 경로이며 원본과 편집 위치는 계속 `owned/`입니다. 설치기가 원본 checkout에 별칭을 만들지 않습니다.

제거할 때도 원본 디렉터리·별칭·registry 항목을 함께 지우고 `make check`를 실행합니다. 다음 설치는 기존 매니페스트의 retired 처리로 관리 링크를 제거하고 기록된 백업을 복원하며, 사용자가 바꾼 대상은 보존합니다. 원본 경로가 없거나 owned 집합이 비었거나, 잘못된 이름 또는 `SKILL.md`가 없는 디렉터리가 있으면 설치 변경 전에 실패합니다. 전체 스킬 제거를 빈 목록으로 표현하지 않습니다.

기본 설치기는 owned 디렉터리에서 설치 대상을 정합니다. `optional`, `enabled_by_default`, `profiles`는 현재 owned 설치 대상을 걸러내지 않습니다. 전역 `install.tsv`와 프로젝트 `.dotagents-install.tsv`는 실제 설치·백업 내역을 기록합니다.

각 스킬은 입력, 출력, 실행 조건, 실패 조건과 부작용을 명시합니다. 특정 프로젝트 경로, 비밀, 조직 내부 정보나 불필요하게 고정된 도구 버전을 포함하지 않습니다.
