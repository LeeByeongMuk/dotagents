# Living Brief contract

Use this contract for the default `Brief → Execute → Verify` path. The Brief is a mandatory planning authority, not necessarily a new file and not an execution checklist. Keep the authority and any local run record current, compact, and readable without prior chat history.

## Location and lifecycle

- Source priority: reuse a current project PRD, issue, or specification that already owns the product decisions.
- Local fallback: `docs/workflows/<run-id>/brief.md`
- External/read-only authority: link it from the local fallback and record only missing decisions, checkpoints, evidence, and risks locally.
- Language: preserve an adopted project's language; write a new local fallback in Korean.
- Status for a local fallback: `PLANNING`, `EXECUTING`, `VERIFYING`, or `COMPLETE`
- Editing: update the authority and the same local fallback throughout the run.
- History: preserve important changes in the decision log and the authority's or Git history.

Do not hash-lock the Brief, duplicate product facts into the local run record, or fork corrections into additional stage documents. A resumed agent should find one authority for product facts and at most one local run record.

## Required content

The authority and local run record may use the project's existing structure, but together they must cover the fields below. Use this template only when creating the local fallback:

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
- Surface material assumptions, consequential alternatives, and user-owned open questions together only when they could change the result; this is not an approval gate.
- Verify facts from the repository or authoritative sources instead of asking the user to recall discoverable details.
- Apply the project's living-context documentation rule before completion.

## Completion rules

Declare the run complete, and set `Status: COMPLETE` when the local fallback has that field, only when:

1. every acceptance criterion is checked or explicitly rejected by the user;
2. verification rows contain actual results rather than planned commands;
3. remaining risks are explicit;
4. living context documents affected by the change are updated, or the Brief records that none were affected;
5. the requested delivery action, if any, is complete.
