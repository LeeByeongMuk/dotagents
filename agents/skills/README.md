# Skills

직접 만든 스킬은 `owned/<name>/SKILL.md`에 둡니다. 외부 스킬을 수정하지 않고 보정해야 하면 `wrappers/<name>/SKILL.md`를 그때 만듭니다.

`owned/<name>/SKILL.md`가 있는 모든 디렉터리가 전역·프로젝트 설치 대상입니다. `tooling/scripts/lib/owned-skills.sh`가 이 집합을 한 번 정의하며, 설치기는 Claude의 개별 링크를 만들고 Codex·Gemini는 공통 `.agents/skills/` 별칭을 사용합니다. 진단기는 실제 설치된 `.agents` 원본의 디렉터리를 기준으로 아직 설치되지 않은 스킬도 검사합니다. 명령을 실행한 checkout이나 설치 기록의 목록으로 기대 집합을 대신하지 않습니다.

스킬을 추가할 때는 다음 세 자산을 함께 만듭니다.

1. 소문자 영문·숫자로 시작하고 소문자 영문·숫자·하이픈만 쓰는 `owned/<name>/SKILL.md` 원본 디렉터리
2. 이 디렉터리의 `<name>` → `owned/<name>` 상대 심볼릭 링크
3. `../registry/skills.toml`의 같은 ID·`kind = "owned"`·`source = "agents/skills/owned/<name>"` 메타데이터

설치기·진단기·테스트 준비 목록에는 이름을 추가하지 않습니다. `make check`는 모든 owned 원본의 별칭과 registry ID·원본 경로가 일치하는지 검사합니다. 루트 별칭은 발견 경로이며 원본과 편집 위치는 계속 `owned/`입니다. 설치기가 원본 checkout에 별칭을 만들지 않습니다.

제거할 때도 원본 디렉터리·별칭·registry 항목을 함께 지우고 `make check`를 실행합니다. 다음 설치는 기존 매니페스트의 retired 처리로 관리 링크를 제거하고 기록된 백업을 복원하며, 사용자가 바꾼 대상은 보존합니다. 원본 경로가 없거나 owned 집합이 비었거나, 잘못된 이름 또는 `SKILL.md`가 없는 디렉터리가 있으면 설치 변경 전에 실패합니다. 전체 스킬 제거를 빈 목록으로 표현하지 않습니다.

registry는 출처·지원 정보이며 설치 입력이 아닙니다. `optional`, `enabled_by_default`, `profiles`는 현재 owned 설치 대상을 걸러내지 않습니다. 전역 `install.tsv`와 프로젝트 `.dotagents-install.tsv`는 실제 설치·백업 내역이며 원하는 스킬 집합의 원본이 아닙니다.

각 스킬은 입력, 출력, 실행 조건, 실패 조건과 부작용을 명시합니다. 특정 프로젝트 경로, 비밀, 조직 내부 정보나 불필요하게 고정된 도구 버전을 포함하지 않습니다. 외부 원본과 버전은 `../registry/skills.toml`과 `../registry/sources.lock`에서 관리합니다.
