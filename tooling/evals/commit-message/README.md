# 커밋 메시지 eval

생성된 호스트 진입점(`dist/<host>/`)만 받은 모델이 `agents/hooks/commit-message/check.sh`를 통과하는 커밋 메시지를 쓰는지 측정합니다. 제품 워크플로우 eval과 달리 규칙 본문을 포함한 진입점 전체를 프롬프트에 넣습니다. 규칙 전달 경로 자체가 측정 대상이기 때문입니다.

훅이 없는 호스트에서도 규칙만으로 관례가 지켜지는지 확인하는 용도입니다. Codex와 Gemini는 `commit-msg` 훅을 자동 설치하지 않습니다.

## 실행

```sh
./tooling/evals/commit-message/run.sh --provider codex --model gpt-5.6-sol \
  --label candidate --output /absolute/path/outside/repo.jsonl
```

`--entry FILE`로 다른 진입점 개정본을 주면 규칙 변경 전후를 비교할 수 있습니다. 출력은 저장소 밖 절대 경로여야 하며 기존 파일을 덮어쓰지 않습니다. 모델 도구는 모두 끄고 진입점의 SHA-256을 결과에 기록합니다.

## 채점

사례마다 다섯 가지를 봅니다. `checker`는 실제 커밋 훅과 같은 `check.sh` 판정, `type`은 기대한 type, `breaking`은 `!`와 `BREAKING CHANGE:` 푸터, `revert`는 `revert: <원래 header>`와 `This reverts commit <SHA>.`, `no_trailer`는 도구가 붙이는 서명이 없는지입니다. 다섯이 모두 참일 때만 `pass`입니다.

사례는 `cases.json`이 원본입니다. 언어 관례, 호환성 깨짐, revert, 과장 표현 유도, 영어 로그의 명령형을 각각 겨냥합니다.
