# Git safety

- 작업 트리에는 사용자의 미커밋 변경이 섞여 있을 수 있으므로, 스테이징과 커밋은 이번 작업에서 만든 변경으로 한정한다.
- 명시적 승인 없이 force push, hard reset, 광범위 삭제, 기록 재작성을 하지 않는다.
- 커밋·푸시 등 git 이력을 만드는 작업은 사용자가 명시적으로 요청할 때만 수행한다. 검토 요청이나 "~해야 될 듯" 같은 숙의 표현은 실행 지시로 해석하지 않는다.

## Commit messages

프로젝트에 커밋 규칙이 있으면 그것을 따른다. 없으면 `git log`의 기존 관례를 따르고, 그것도 없으면 아래 기본값을 쓴다. 기본값은 Conventional Commits 1.0.0과 Angular 커밋 가이드를 기준으로 한다. 이 기본값은 같은 원본의 `hooks/commit-message/check.sh`가 커밋 시 기계적으로 검사한다.

### Format

```
<type>(<scope>)!: <summary>

<body>

<footer>
```

- header는 필수, scope·body·footer는 선택이다. 각 부분은 빈 줄로 구분한다.
- type은 다음 중 하나만 쓴다. `feat` 기능 추가, `fix` 버그 수정, `refactor` 동작 변경 없는 구조 개선, `perf` 성능 개선, `docs` 문서만 변경, `test` 테스트 추가·수정, `build` 빌드 시스템·의존성, `ci` CI 설정, `chore` 그 외 유지보수, `revert` 되돌리기.
- scope는 영향받는 패키지·모듈·디렉터리 이름을 소문자로 쓴다. 여러 영역에 걸치면 생략한다.
- 호환성을 깨는 변경은 type 뒤에 `!`를 붙이고 footer에 `BREAKING CHANGE: <설명>`을 쓴다.

### Summary

- 명령형·현재형으로 쓴다(add, fix, 추가, 수정).
- 영어면 소문자로 시작하고, 끝에 마침표를 찍지 않는다. 50자 이내를 목표로 하고 72자를 넘기지 않는다.
- 언어는 기존 로그를 따르고, 없으면 사용자가 대화에 쓰는 언어를 따른다.

### Body and footer

- body는 diff로 알 수 없는 것, 즉 왜 바꿨는지와 이전·새 동작의 차이를 설명할 때만 쓴다. 한 줄 72자 이내로 줄바꿈한다.
- 이슈 참조는 footer에 `Fixes #123`, `Closes #123`, `Refs #123` 형식으로 쓴다.
- revert는 `revert: <원래 header>`로 쓰고 body에 `This reverts commit <SHA>.`와 되돌리는 이유를 적는다.

### Style

- 평문으로 쓴다. 이모지를 쓰지 않으며, 불릿·제목 기호·굵은 글씨는 훅이 거부한다.
- "이 커밋은 ~", "comprehensive" 같은 서술형·과장 표현은 훅이 거부한다. 정확한 목록은 `check.sh`의 `forbidden_re`가 원본이다.
- 한 커밋에는 한 가지 목적만 담는다. 관련 없는 변경이 섞여 있으면 커밋을 나눈다.
- 도구가 자동으로 붙이는 서명·트레일러는 프로젝트가 요구하지 않으면 붙이지 않는다.
