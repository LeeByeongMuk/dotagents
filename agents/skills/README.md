# 스킬 관리

[직접 만든 스킬과 사용 예](owned/README.md) · [외부 스킬 관리](../../docs/external-skills.md) · [문서 목록](../../docs/README.md)

## 원본과 설치 대상

| 자산 | 역할 |
| --- | --- |
| `owned/<name>/SKILL.md` | 직접 만든 스킬 원본. 모든 유효한 디렉터리가 전역·프로젝트 링크 설치 대상 |
| `<name>` → `owned/<name>` | 원본 checkout의 공통 발견용 별칭 |
| [skills.toml](../registry/skills.toml)의 owned 항목 | ID·원본 경로·출처·지원 정보. owned 설치 선택에는 사용하지 않음 |

`tooling/scripts/lib/owned-skills.sh`가 owned 집합을 정의합니다. Claude에는 개별 링크를 만들고, Codex·Gemini는 공통 `.agents/skills/`를 사용합니다. 실제 연결 방식은 [설치 레이아웃](../../docs/designs/install-layouts.md)이 정합니다. 진단기는 명령을 실행한 checkout이 아니라 실제 설치 원본의 스킬 집합을 기준으로 미설치 항목도 검사합니다.

registry의 `optional`, `enabled_by_default`, `profiles`는 owned 설치 대상을 거르지 않습니다. 설치 매니페스트는 실제 설치·백업 내역이며 원하는 스킬 집합의 원본이 아닙니다. 외부 스킬 명령의 레지스트리 사용은 [별도 정책](../registry/README.md)을 따릅니다.

## 추가

다음 세 자산을 함께 만듭니다.

1. 소문자 영문·숫자로 시작하고 소문자 영문·숫자·하이픈만 쓰는 `owned/<name>/SKILL.md` 원본 디렉터리
2. 이 디렉터리의 `<name>` → `owned/<name>` 상대 심볼릭 링크
3. `../registry/skills.toml`의 같은 ID·`kind = "owned"`·`source = "agents/skills/owned/<name>"` 메타데이터

[스킬 목록](owned/README.md)에 사용 예를 추가하고 `make check`를 실행합니다. 설치기·진단기·테스트 준비 목록에 이름을 추가할 필요는 없습니다. 설치기가 원본 checkout의 별칭을 만들어 주지는 않습니다.

## 제거

원본 디렉터리·별칭·registry 항목과 스킬 목록을 함께 정리하고 `make check`를 실행합니다. 다음 설치는 기존 매니페스트를 기준으로 관리 링크를 제거하고 기록된 백업을 복원하며, 사용자가 바꾼 대상은 보존합니다.

원본 경로가 없거나 owned 집합이 비었거나, 잘못된 이름 또는 `SKILL.md`가 없는 디렉터리가 있으면 설치 변경 전에 실패합니다. 전체 스킬 제거를 빈 목록으로 표현하지 않습니다.

## 작성과 외부 자산

각 스킬은 입력, 출력, 실행 조건, 실패 조건과 부작용을 명시합니다. 특정 프로젝트 경로, 비밀, 조직 내부 정보나 불필요하게 고정된 도구 버전을 포함하지 않습니다.

외부 원본과 버전은 [레지스트리와 잠금](../registry/README.md)으로 관리합니다. 외부 스킬을 수정하지 않고 보정할 필요가 생겼을 때 `wrappers/<name>/SKILL.md`를 추가합니다. 현재 설치기의 자동 열거 대상은 `owned/`이며 wrapper 연결은 별도로 정해야 합니다.
