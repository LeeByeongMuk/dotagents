# Living Brief contract

Use this contract for the default `Brief → Execute → Verify` path. The Brief is a mandatory planning harness, not an execution checklist. Keep it current, compact, and readable without prior chat history.

## Location and lifecycle

- Path: `docs/workflows/<run-id>/brief.md`
- Language: Korean
- Status: `PLANNING`, `EXECUTING`, `VERIFYING`, or `COMPLETE`
- Editing: update the same file throughout the run
- History: preserve important changes in the decision log and Git history

Do not hash-lock the Brief or fork corrections into additional stage documents. A resumed agent should find one current truth.

## Required content

```markdown
# 제품 Brief: <이름>

- Run ID: `<run-id>`
- Status: `PLANNING | EXECUTING | VERIFYING | COMPLETE`
- Updated: `YYYY-MM-DD`

## 문제

<누가, 언제, 무엇을 하지 못해서, 무엇을 포기하는가?>

## 원하는 결과와 성공 신호

- 결과: <문제가 해결되면 달라지는 것>
- 성공 신호: <관찰하거나 측정할 수 있는 증거>

## 판단 원칙

- <A보다 B를 선택한다. 왜냐하면 ...>

## 절대 제약과 비목표

- 제약: <보안, 비용, 일정, 호환성, 법률 등>
- 비목표: <이번 작업에서 하지 않을 것>

## 수용 조건

- [ ] <사용자나 시스템이 관찰할 수 있는 완료 조건>

## 결정 기록

| 날짜 | 결정 | 버린 대안 | 이유 | 결정자 |
|---|---|---|---|---|

## 열린 제품 결정

- `None` 또는 사용자가 결정해야 할 항목만 기록

## 실행 체크포인트

- 현재 상태: <무엇이 완료되었는가>
- 다음 행동: <재개 시 바로 할 일>
- 변경 파일: <현재까지의 핵심 경로>

## 검증 증거

| 수용 조건/위험 | 검증 방법 | 결과 |
|---|---|---|

## 남은 위험

- `None` 또는 검증하지 못한 구체적 위험
```

## Quality rules

- State the problem as a specific human or system failure, not “improve X.”
- Give every preference a reason so the agent can generalize it to an unseen choice.
- Keep acceptance criteria observable. Avoid “works well,” “clean,” or “high quality” without a testable meaning.
- Record rejected alternatives only when they could otherwise be proposed again.
- Keep routine implementation notes out of the decision log.
- Ask the user only when an open product decision changes scope, behavior, risk acceptance, or a hard constraint.
- Verify facts from the repository or authoritative sources instead of asking the user to recall discoverable details.

## Completion rules

Set `Status: COMPLETE` only when:

1. every acceptance criterion is checked or explicitly rejected by the user;
2. verification rows contain actual results rather than planned commands;
3. remaining risks are explicit;
4. the requested delivery action, if any, is complete.
