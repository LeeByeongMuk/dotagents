# 커밋 규칙 압축 eval

- Date: `2026-09-17`
- Baseline: `eaf6006`의 `dist/codex/AGENTS.md` (압축 전 `git.md` 1,546자)
- Candidate: 압축본 (802자)
- Models: GPT-5.6 Sol, GPT-5.6 Luna, Claude Opus 5, Claude Fable 5.1 (모두 medium)
- Result: 압축본이 Sol에서 2사례, Luna에서 추가 1사례 회귀. 세 규칙을 근거와 함께 복원한 뒤 네 모델 모두 5/5

## 목적

`git.md`에서 Conventional Commits 형식 재진술을 제거하고 검사기를 가리키게 한 변경이, 검사기를 자동 설치하지 않는 호스트에서도 안전한지 측정한다. 기존 제품 워크플로우 eval은 `--ignore-rules`로 규칙을 배제하므로 이 변경을 관측할 수 없다.

## 방법

`tooling/evals/commit-message/run.sh`가 생성된 진입점 전체와 최근 로그, 스테이징된 변경 설명을 주고 커밋 메시지만 받는다. 도구는 끄고 medium effort, 조합당 1회 실행했다. 판정은 실제 커밋 훅과 같은 `check.sh`에 type, 호환성 깨짐 표기, revert 형식, 트레일러 부재를 더한 다섯 항목이다.

## 결과

| 사례 | baseline | candidate | fixed |
|---|---|---|---|
| feature-korean-log | pass | pass | pass |
| breaking-signature | pass | **fail** | pass |
| revert-commit | pass | **fail** | pass |
| docs-narrative-trap | pass | pass | pass |
| fix-english-log | pass | pass | pass |

두 실패의 원인이 서로 달랐다.

- `breaking-signature`: candidate가 `BREAKING CHANGE:` 푸터를 101자 한 줄로 썼고 `check.sh`가 100자 제한으로 거부했다. 제거한 "한 줄 72자 이내로 줄바꿈한다"가 baseline에서 줄바꿈을 만들고 있었다. 훅이 있는 호스트에서는 커밋 실패로 드러나고, 훅이 없는 호스트에서는 그대로 커밋된다.
- `revert-commit`: candidate가 `revert(render): ... 되돌리기` 헤더와 `Reverts: 9f2c1ab` 푸터를 썼다. `revert`는 유효한 type이라 `check.sh`가 통과시킨다. 즉 검사기가 잡지 못하는 조용한 관례 손실이다. 같은 실행에서 영어 로그 저장소에 한국어 메시지를 쓰는 언어 관례 이탈도 함께 나타났다.

## GPT-5.6 Luna 추가 측정

두 줄 복원본을 Luna에 돌리자 `breaking-signature`만 실패했다. 같은 사례를 3회 반복하면 복원본은 0/3, 압축 전 진입점은 3/3이었다. 복원본에서 Luna는 헤더의 `!`와 `BREAKING CHANGE:` 푸터 중 하나만 썼고 둘을 함께 쓴 적이 없다. 제거한 "type 뒤에 `!`를 붙이고 footer에 `BREAKING CHANGE:`를 쓴다"가 두 표기를 한 문장으로 묶고 있었다. Sol, Opus 5, Fable 5.1은 이 문장 없이도 둘을 함께 썼으므로 Luna에서만 드러난 손실이다. `check.sh`는 `!`를 선택 항목으로 두므로 잡지 못한다.

| 모델 | breaking-signature 복원본(2줄) | 압축 전 | 복원본(3줄) |
|---|---|---|---|
| GPT-5.6 Luna | 0/3 | 3/3 | 3/3 |

## 판정

ADR 0002 3항의 "반복되는 현재 증거가 있는 실패" 예외를 적용해 세 줄을 복원했다. 복원 후 `git.md`는 991자로 압축 전 대비 36% 작다.

- `호환성을 깨는 변경은 type 뒤에 !를 붙이고 footer에 BREAKING CHANGE: <설명>을 쓴다.`
- `body와 footer는 한 줄 72자 이내로 줄바꿈한다.`
- `revert는 revert: <원래 header>로 쓰고 body에 This reverts commit <SHA>.와 되돌리는 이유를 적는다.`

복원본으로 GPT-5.6 Sol, GPT-5.6 Luna, Claude Opus 5, Claude Fable 5.1 모두 5/5를 기록했다. 나머지 형식 규정은 검사기가 원본이라는 결론이 유지된다. 거부당한 것은 "검사기가 기계적으로 잡으니 규칙에서 빼도 된다"는 일반화이며, 검사기가 관측하지 않는 형식과 커밋 시점 이후에만 드러나는 제한은 규칙에 남아야 한다.

## 열린 질문

Luna의 breaking-signature 외에는 조합당 1회 실행이라 분산은 재지 않았다. Gemini는 실행기 어댑터가 없어 측정하지 못했다. 사례 5개는 형식 규정만 겨냥하며 커밋 분할이나 scope 선택 같은 판단은 채점하지 않는다.
