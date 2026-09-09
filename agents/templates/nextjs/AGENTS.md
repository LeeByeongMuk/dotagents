# Next.js project AI guide

이 템플릿은 시작점일 뿐이다. `package.json`, lockfile, Next.js 설정, 소스 구조를 조사하고 실제 기술에 맞게 수정한다. Next.js·React 버전, 패키지 매니저, 테스트 러너, 인증·데이터 라이브러리를 가정하거나 고정하지 않는다.

## Project context

- Router: `[App Router / Pages Router / 혼합]`
- Language: `[TypeScript / JavaScript]`
- Styling: `[실제 선택]`
- Data and auth: `[실제 선택]`
- Package manager: `[lockfile로 확인]`

## Boundaries

- Server/Client Component 경계 규칙: `[이 프로젝트가 정한 규칙, 예: 데이터 접근 위치, 클라이언트 컴포넌트 허용 범위]`
- 비즈니스 로직 위치: `[디렉터리]`
- FSD를 실제 채택한 경우에만 `fsd-optional.md`를 프로젝트 규칙으로 조정해 사용한다.

## Verification

`package.json`에 실제 정의된 typecheck, lint, test, build 명령을 기록한다. 존재하지 않는 명령을 새 표준처럼 가정하지 않는다.
