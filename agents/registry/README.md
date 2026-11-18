# 레지스트리와 소스 잠금

[문서 목록](../../docs/README.md) · [스킬 관리](../skills/README.md) · [외부 스킬 사용법](../../docs/external-skills.md)

## 파일별 역할

| 파일 | 내용 |
| --- | --- |
| [skills.toml](skills.toml) | 내부·외부 스킬의 ID, 출처, 지원 호스트와 워크플로우 연결 |
| [sources.lock](sources.lock) | 검토한 외부 저장소 URL·커밋과 출처 정보 |
| [hooks.toml](hooks.toml) | 훅 이벤트, 실행 항목, 지원 호스트와 기본 활성화 정책 |
| [mcp.toml](mcp.toml) | MCP 선언용 파일. 현재 서버 항목 없음 |
| [plugins.toml](plugins.toml) | 플러그인 선언용 파일. 현재 플러그인 항목 없음 |

`skills.toml`의 `workflows`는 워크플로우 자체에 `product-development`, lean 검증 후보에 `product-development:verify`를 사용합니다. 연결되지 않은 외부 스킬은 빈 목록입니다.

Modern Web Guidance의 Git 커밋은 스킬 파일을 고정하고 `sources.lock`의 `npm_version`은 실행 CLI와 그 안의 가이드를 고정합니다. 별도 실행 스크립트가 `npm_version`을 사용합니다. [Modern Web Guidance 연동](../integrations/skills/modern-web-guidance/README.md)

## 설치에서의 사용

| 명령 | 대상 선택 |
| --- | --- |
| 전역·프로젝트 `install.sh` | [owned 디렉터리](../skills/README.md)를 열거. registry로 필터링하거나 외부 스킬을 다운로드하지 않음 |
| 선택형 `external-skills.sh` | 명시한 외부 ID와 호스트를 registry에서 확인하고 잠금 커밋을 사용. `--apply`에서만 변경 |

`optional`, `enabled_by_default`, `profiles`는 현재 자동 다운로드나 owned 설치 선택 정책이 아닙니다. 실제 설치·백업·파일 해시는 각 명령의 별도 설치 기록이 소유합니다. 외부 명령의 목적지·상태 경로와 지원 범위는 [외부 스킬 안내](../../docs/external-skills.md)를 따릅니다.

## 갱신과 검증

owned 항목의 ID·원본 경로는 실제 디렉터리와 일치해야 하며 `make check`가 누락·중복·불일치를 검사합니다. 외부 커밋은 검토 후 `sources.lock`에 기록하고, 기존 설치 반영은 별도 `update`로 실행합니다. 레지스트리만 고쳐도 설치가 자동으로 바뀌지는 않습니다.

`tooling/scripts/check-sources.sh`는 인증된 GitHub CLI로 잠금 커밋의 소스 상대 경로를 검증합니다. 호스트의 실행 성공이나 외부 스킬의 품질을 검증하는 명령은 아닙니다.

새 외부 항목에는 안정적인 ID, 출처, 버전 또는 커밋, 라이선스, 지원 호스트와 적용 정보를 기록합니다. 비밀 값 대신 필요한 환경 변수 이름만 적습니다.
