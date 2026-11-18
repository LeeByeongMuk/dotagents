# Modern Web Guidance 연동

웹 UI, CSS, 브라우저 API를 구현하거나 검토할 때 관련 가이드와 브라우저 호환성 정보를 조회하는 선택형 외부 스킬이다. 일반 웹 개발용 `modern-web-guidance`만 등록하며 `chrome-extensions`는 포함하지 않는다. 공통 제품 개발 워크플로우의 필수 단계나 기본 설치 대상은 아니다.

출처·검토 커밋·CLI 버전은 [sources.lock](../../../registry/sources.lock), 스킬 경로·호스트 선언은 [skills.toml](../../../registry/skills.toml)이 소유한다. 코드의 라이선스는 Apache-2.0이고 가이드 문서는 CC-BY-4.0이다. 외부 가이드 원본은 dotagents에 복사하지 않는다.

## 설치와 실행의 경계

[외부 스킬 관리 명령](../../../../docs/external-skills.md)에서 `modern-web-guidance`를 선택해 프로젝트의 기존 일반 스킬 디렉터리에 연결한다. 설치하기 전에 아래 프로젝트 지침을 해당 프로젝트의 기존 `AGENTS.md` 또는 호스트 지침에 통합한다. 설치 명령은 그 파일을 자동으로 바꾸지 않는다.

```sh
./tooling/scripts/external-skills.sh plan modern-web-guidance \
  --host codex --dest /path/to/project/.agents/skills \
  --state-dir /path/to/external-state

./tooling/scripts/external-skills.sh install modern-web-guidance \
  --host codex --dest /path/to/project/.agents/skills \
  --state-dir /path/to/external-state --apply
```

`claude` 또는 `gemini`에서도 지원 선언에 맞는 호스트와 실제 발견 경로를 선택한다. 이 선언과 파일 전달 성공은 호스트가 스킬을 실행했다는 검증이 아니다. `~/.agents`나 프로젝트의 `.agents`가 dotagents 원본으로 이어지는 legacy 링크이면 그 아래에 설치하지 않는다.

상류 `SKILL.md`는 CLI의 `@latest` 버전을 호출하므로 Git 커밋만 고정해서는 실행 버전이 고정되지 않는다. [run.sh](run.sh)는 잠금 파일의 `npm_version`으로 CLI를 호출하고 해당 프로세스에 `DISABLE_TELEMETRY=1`을 적용한다. 원본 스킬은 수정하지 않으며, 스킬을 설치하는 것만으로 실행 지시가 이 스크립트로 바뀌지는 않는다.

## 고정 버전으로 사용

Bash, Python 3.11 이상, Node.js 22 이상과 npm의 `npm`, `npx`가 필요하다. `make deps`나 스킬 설치기가 런타임을 설치하지 않는다. 처음 호출할 때 npm 패키지를 내려받아 npm 캐시에 저장할 수 있어 네트워크가 필요하다. 검색 엔진은 로컬에서 동작하며 별도 API 키가 필요하지 않다. 큰 가이드 조회 결과는 CLI가 임시 파일로 저장할 수 있다.

패키지는 npm이 찾은 프로젝트 루트의 `.npmrc`를 적용해 해석한다. 스크립트는 워크스페이스별 실행을 끄고 호출한 디렉터리에서 CLI를 한 번 실행한다. CLI는 그 디렉터리에서 `.mwgrc`를 찾고 상대 경로를 해석한다.

```sh
mwg=/path/to/dotagents/agents/integrations/skills/modern-web-guidance/run.sh
cd /path/to/project
"$mwg" --version
"$mwg" search "light dismiss dialog"
"$mwg" retrieve "light-dismiss-a-dialog"

# 프로젝트나 디렉터리 전체의 현대화 조사를 요청했을 때만 실행한다.
"$mwg" legacy-scan src --json
```

이 실행 경로는 `search`, `retrieve`, `list`, `legacy-scan`, `--version`만 전달하며 종료 상태를 그대로 반환한다. 설치·갱신·제거는 기존 외부 스킬 관리 명령으로 수행한다. 실험 기능 허용 명령도 이 스크립트로 전달하지 않는다. `.mwgrc`를 통한 실험 기능 허용은 프로젝트가 별도로 결정한다.

## 프로젝트에 통합할 지침

아래 내용의 체크아웃 경로와 브라우저 정책을 실제 프로젝트 값으로 바꿔 기존 지침에 통합한다. 팀에서 공유하는 프로젝트라면 개인 절대 경로 대신 팀이 정한 실행 진입점을 사용한다.

```markdown
## Modern Web Guidance

- 웹 UI·CSS·클라이언트 JavaScript의 브라우저 기능이나 호환성 판단이 필요한 작업에 사용한다. 단순 문구 수정, 백엔드·인프라·도구 설정 작업에는 강제하지 않는다.
- CLI는 `<dotagents-checkout>/agents/integrations/skills/modern-web-guidance/run.sh`로 호출한다. 상류 스킬과 CLI 출력에 나온 `npx ...@latest` 예시도 이 경로의 해당 명령으로 바꿔 실행한다.
- 지원 브라우저: [이 프로젝트의 실제 최소 지원 버전 또는 Baseline 기준].
- 폴리필·대체 구현 허용 범위: [이 프로젝트의 실제 정책]. 정책이 없으면 가이드의 기본 호환성 대응을 유지한다.
- 프로젝트의 디자인 시스템·기존 컴포넌트·타입·빌드 규칙을 우선한다. 가이드 적용만을 위해 라이브러리를 교체하거나 검사 규칙을 완화하지 않는다.
- `legacy-scan`은 프로젝트나 디렉터리 전체의 현대화·레거시 조사를 요청했을 때 사용한다. 결과의 `keepWhen`·`dropWhen` 조건을 검토해 오탐과 필요한 fallback을 보존한다.
- 실제 동작·접근성·성능은 프로젝트의 기존 검증 명령과 대상 브라우저에서 확인한다. 적용 결과는 프로젝트의 기존 보고 형식을 따른다.
```

## 버전 갱신과 검증

새 릴리스의 스킬 지침·CLI·가이드 변경을 검토한 뒤 `sources.lock`의 Git `revision`, `npm_version`, `reviewed_at`을 함께 갱신한다. 상류 패키지의 `package.json` 버전과 잠금 값을 대조하고 고정 실행 경로의 `--version`, `search`, `retrieve`를 확인한다. 기존 스킬 설치는 외부 스킬 관리 명령의 `update`로 바꾼다. npm CLI 갱신은 실행 스크립트가 다음 호출에서 새 잠금 버전을 사용하면서 반영된다.

`make check`는 네트워크 없이 실행 버전·통계 비활성화·인수와 작업 디렉터리 보존·오류 전달을 검사한다. `tooling/scripts/check-sources.sh`는 GitHub의 잠금 경로를 확인한다. 이 검사는 npm 패키지 실행, 호스트의 스킬 선택, 프로젝트 개선 효과를 대신하지 않는다. `legacy-scan`은 가이드 중 정적 패턴으로 찾을 수 있는 일부만 검사하므로 결과가 없다는 것을 전체 품질 보증으로 해석하지 않는다.

근거: [배포 저장소](https://github.com/GoogleChrome/modern-web-guidance), [CLI 개발 소스](https://github.com/GoogleChrome/modern-web-guidance-src), [현대화 범위](https://developer.chrome.com/docs/modern-web-guidance/modernization-workflow), [프로젝트 브라우저 정책](https://developer.chrome.com/blog/cross-browser-by-default).
