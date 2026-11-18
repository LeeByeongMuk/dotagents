# 선택한 외부 스킬 관리

[문서 목록](README.md) · [직접 만든 스킬](../agents/skills/owned/README.md) · [레지스트리와 잠금](../agents/registry/README.md)

`tooling/scripts/external-skills.sh`는 선택한 외부 스킬 하나를 검토한 커밋에 고정해 설치·갱신·제거한다. 기본 전역·프로젝트 설치와 별개이며 **`--apply`를 붙일 때만 변경**한다. 저장소 루트에서 실행하고 Bash, Git, **Python 3.11 이상**을 준비한다. `make deps`는 Python을 설치하지 않는다.

## 목록과 출처 확인

```bash
./tooling/scripts/external-skills.sh list
./tooling/scripts/external-skills.sh inspect superpowers-writing-plans
```

`list`는 설치 상태가 아닌 외부 스킬 ID·출처 ID·지원 호스트 선언을 출력한다. `inspect`는 소스 URL, 잠금 커밋과 저장소 상대 `SKILL.md` 경로를 보여 준다. 실제 상태도 확인하려면 아래의 호스트·목적지·상태 디렉터리를 함께 지정한다. 레지스트리의 호스트 선언은 호스트 실행 검증 결과가 아니다.

항목·호스트·경로의 원본은 [skills.toml](../agents/registry/skills.toml), 출처와 검토한 40자리 커밋의 원본은 [sources.lock](../agents/registry/sources.lock)이다. `profiles`나 `enabled_by_default`를 다운로드 정책으로 해석하지 않는다. 테스트나 검토한 별도 레지스트리는 `DOTAGENTS_SKILLS_FILE`, `DOTAGENTS_SOURCES_FILE`로 명시할 수 있다.

외부 스킬과 잠금 출처의 ID에는 소문자 영문·숫자와 단일 구분 하이픈을 쓴다. `kind = "owned"` 선언의 ID는 저장소의 [소유 스킬 이름 규칙](../agents/skills/README.md)을 따른다. 스킬 ID는 종류에 관계없이 같은 레지스트리에서 고유해야 한다.

공급자별 실행 조건이 있는 항목은 [연동 안내](../agents/integrations/README.md)를 함께 읽는다. [Modern Web Guidance](../agents/integrations/skills/modern-web-guidance/README.md)는 Git 커밋 외에 npm CLI 버전도 고정하며, 전용 실행 경로로 사용 통계를 비활성화한다. 스킬 파일 설치만으로 이 실행 보정이나 프로젝트 브라우저 정책이 적용되지는 않는다.

## 미리보기와 설치

목적지는 사용자가 준비한 **기존 일반 디렉터리**이며 선택 호스트가 스킬을 읽는 위치여야 한다. 상태 디렉터리도 별도로 준비하고 두 경로를 겹치지 않게 한다. 프로젝트의 `.agents/skills` 또는 `.claude/skills`를 사용할 수 있지만, 그 상위가 공유 원본으로 이어지는 링크이면 거부한다. 격리된 일반 디렉터리로도 파일 전달을 검증할 수 있다.

```bash
./tooling/scripts/external-skills.sh plan superpowers-writing-plans \
  --host codex --dest /path/to/project/.agents/skills \
  --state-dir /path/to/external-state

./tooling/scripts/external-skills.sh install superpowers-writing-plans \
  --host codex --dest /path/to/project/.agents/skills \
  --state-dir /path/to/external-state --apply

./tooling/scripts/external-skills.sh inspect superpowers-writing-plans \
  --host codex --dest /path/to/project/.agents/skills \
  --state-dir /path/to/external-state
```

`plan`과 `--apply` 없는 변경 명령은 fetch나 파일 쓰기를 하지 않는다. `--dry-run`도 같은 미리보기다. `--host`는 `claude`, `codex`, `gemini` 중 레지스트리가 지원한다고 선언한 하나다. 호스트를 자동 감지하거나 다른 호스트에 추가 링크를 만들지 않는다. 여러 호스트가 같은 스킬 디렉터리를 읽는 경우에는 이 링크를 함께 발견할 수 있다. 같은 목적지의 같은 스킬을 다른 호스트 이름으로 재등록하지 않는다.

적용할 때는 잠금 커밋만 Git으로 fetch하고 실제 커밋을 확인한다. `HEAD`·태그·최신 릴리스를 선택하지 않는다. checkout이나 외부 설치기를 실행하지 않고 Git 객체의 파일을 읽어 저장하므로 checkout 훅·smudge 필터·`export-ignore`가 전달 파일을 바꾸지 않는다. 검토할 출처는 공개 GitHub HTTPS 또는 로컬 Git 저장소의 `file:///` URL로 제한한다. 사용자 Git 전역 설정·credential helper·URL rewrite를 사용하지 않으므로 비공개 저장소 인증은 이 명령의 범위가 아니다.

### 전달 파일과 설치 기록

| 위치 | 의미 |
|---|---|
| `<state>/checkouts/<source>/<commit>/repository.git` | 확인한 커밋의 Git 객체 캐시 |
| 같은 경로의 `payload/` | 전체 저장소의 파일·실행 비트·안전한 내부 링크. 선택 스킬의 형제 디렉터리·참조·스크립트 자산을 보존 |
| 같은 경로의 `receipt.json` | 출처·커밋·전달 파일 전체의 해시 |
| `<state>/installs/<target-hash>.json` | 실제 연결한 스킬·호스트·목적지·원본·커밋·해시 |
| `<dest>/<skill-id>` | 캐시 안의 해당 스킬 디렉터리로 가는 링크 |

캐시의 전체 저장소 레이아웃을 유지하지만 호스트가 발견하는 링크는 선택한 스킬 하나다. 보조 스크립트를 자동 실행하거나 의존성을 설치하지 않는다. 특히 gstack의 브라우저·바이너리·플러그인·훅·설정·고정 홈 경로 등을 준비했다는 뜻이 아니다. 외부 스킬의 자체 지침이 별도 환경이나 고정 경로를 요구하면 그 출처의 안내와 실제 환경을 별도로 검토한다. 호스트의 로딩·실행 성공은 파일 전달 검사와 구분한다.

## 갱신과 제거

새 커밋은 사용자가 내용을 검토한 뒤 `sources.lock`에 기록한다. `update`는 선택한 설치 기록의 링크와 캐시가 그대로일 때만 새 잠금 커밋으로 바꾼다. `install`은 기존 설치의 잠금 출처가 바뀌면 `update`를 사용하라고 알린다. 같은 잠금 상태로 `install`을 반복하면 같은 파일과 링크를 유지한다. 기록된 링크가 없어졌고 다른 파일이 자리를 차지하지 않았으면 복구할 수 있다.

```bash
./tooling/scripts/external-skills.sh update superpowers-writing-plans \
  --host codex --dest /path/to/project/.agents/skills \
  --state-dir /path/to/external-state --apply

./tooling/scripts/external-skills.sh remove superpowers-writing-plans \
  --host codex --dest /path/to/project/.agents/skills \
  --state-dir /path/to/external-state --apply
```

제거는 실제 설치 기록으로 판단하므로 레지스트리에서 항목이 빠졌거나 소스가 오프라인이어도 가능하다. 정확히 기록한 링크와 출처·해시를 확인한 뒤 링크와 해당 설치 기록만 지운다. 캐시는 다른 선택 항목과 옛 커밋의 검토 근거를 보존하기 위해 남긴다. 외부 스킬 자산을 편집했거나 링크를 다른 파일·링크로 바꿨으면 갱신·제거 모두 거부하고 보존한다. 사용자 수정은 별도 경로에 보관하고 소유 경계를 확인한 뒤 후속 작업을 결정한다. `--force`나 임의 대상 인수는 제공하지 않는다.

## 경로와 실패 처리

목적지·상태 경로의 모든 상위 링크, 경로 순회, 원본 저장소 및 같은 Git 저장소의 다른 worktree, 홈 자체와 Git 메타데이터 경로는 거부한다. 소스 내부의 외부로 나가는 링크·순환 링크·submodule·대소문자 충돌도 대상 링크를 쓰기 전에 실패한다.

legacy `~/.agents -> dotagents/agents` 아래에는 외부 스킬을 설치할 수 없다. 프로젝트의 일반 디렉터리를 사용하거나, 전역 공유 디렉터리가 필요하면 [managed 설치](install.md#managed-설치)의 소유권과 이행 절차를 확인한다. 목적지와 모든 상위 경로는 일반 디렉터리여야 한다. 외부 스킬 명령이 호스트의 설정·규칙 링크나 설치 방식을 바꾸지는 않는다.

fetch·경로·출처 실패와 설치 기록 게시 전의 실패는 기존 대상과 설치 기록을 보존한다. 설치·갱신 기록의 실제 게시 또는 제거 기록의 실제 삭제를 커밋 경계로 삼는다. 그 직후 오류나 SIGTERM이 발생하면 새 기록에 맞춰 링크의 변경도 유지하고 `committed:`를 출력한다. 이 경우 비정상 종료여도 변경은 반영됐으므로 `inspect`로 실제 상태를 확인한다. 기록만 새 상태인데 링크만 이전 상태로 되돌리지 않는다. 동시에 사용자가 대상을 다른 파일로 교체했으면 그 파일을 보존하며, 남은 설치 기록과의 충돌은 다음 점검에서 알린다.

상태 디렉터리의 잠금으로 같은 상태를 사용하는 동시 변경을 거부한다. 잠금을 얻은 뒤 링크와 설치 기록이 사전 점검에서 확인한 상태인지 다시 확인한다. 이 사이 대상이 바뀌면 대상과 설치 기록을 보존하고 중단한다. fetch한 캐시는 연결 실패 뒤에도 남을 수 있다. SIGKILL·전원 차단이나 적용 도중 외부 프로세스가 디렉터리를 교체하는 상황은 완전한 트랜잭션 복구를 보장하지 않는다. 중단된 `.external-skills.lock`과 기록·링크를 확인한 뒤 재개한다. 이 명령은 설치 기록을 서로 다른 상태 디렉터리 사이에서 자동 이관하거나 캐시를 수거하지 않는다.

## 기존 도구 선택 근거

2026-11-17에 공식 `vercel-labs/skills`의 [패키지](https://github.com/vercel-labs/skills/blob/57217cf86ba38148a57af9e90d14a4c049558330/package.json) 버전 `1.9.0`, [명령 계약](https://github.com/vercel-labs/skills/blob/57217cf86ba38148a57af9e90d14a4c049558330/docs/commands.md), [설치 구현](https://github.com/vercel-labs/skills/blob/57217cf86ba38148a57af9e90d14a4c049558330/src/installer.ts)을 읽었다. CLI를 설치하거나 실행하지 않았다. 전체 커밋 고정·스킬·호스트 선택·변경 상태 표시는 이미 제공된다. 목적지는 프로젝트·전역 호스트 경로 중심이며 설치 구현에는 대상 디렉터리를 정리하고 다시 쓰는 경로가 있다. 이번의 명시적 임의 목적지·선택 항목 소유권·변경 대상 보존을 함께 적용하는 공개 CLI 계약은 확인하지 못했다. 이 요구에 한정해 Git 객체 fetch와 링크·출처 기록을 감싸며 별도 다운로드 프레임워크나 공급자 설치기를 만들지 않았다. Git의 [fetch](https://git-scm.com/docs/git-fetch), [ls-tree](https://git-scm.com/docs/git-ls-tree), [cat-file](https://git-scm.com/docs/git-cat-file) 계약을 사용한다.

## 검증

`tooling/tests/external_skills_test.sh`는 임시 로컬 Git 소스에서 실제 fetch와 링크로 다음을 검사하며 `make check`에 포함된다.

- 고정 버전·보조 자산 전달, 미리보기 무변경, 갱신·제거·오프라인 제거·재실행
- 사용자 변경 보존, 경로 보호, 잠금 경합과 잠금 직후 대상 교체
- 기록 게시 전 실패 복구, 게시·삭제 직후 오류·SIGTERM의 일관된 상태

Python 3.11 이상이 필요하고 네트워크는 사용하지 않는다. 실제 잠금 출처의 경로 확인은 별도 읽기 전용 `tooling/scripts/check-sources.sh`로 실행한다. 실제 호스트 실행과 외부 스킬의 작업 품질은 이 검사에 포함되지 않는다.
