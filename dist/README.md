# Generated distributions

`tooling/scripts/build.sh`가 각 호스트의 얇은 어댑터와 `agents/rules/`의 공통 규칙을 합쳐 만드는 최종본입니다. 설치는 이 디렉터리의 파일을 호스트 진입점에 링크하므로, 호스트가 규칙 문서를 따로 읽지 않아도 규칙이 적용됩니다.

이 디렉터리의 파일을 직접 편집하지 않습니다. 어댑터는 `agents/adapters/<호스트>/`, 규칙은 `agents/rules/`에서 고친 뒤 `make build`로 다시 생성합니다. `make check`가 생성본이 원본과 일치하는지 검사하므로 원본만 고치고 생성을 잊으면 검사에서 걸립니다.
