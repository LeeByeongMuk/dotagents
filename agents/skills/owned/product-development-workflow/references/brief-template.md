# Local Brief template

Read this reference only when the workflow must create a local Brief or an external/read-only authority needs a local run record. Do not load it when an editable current PRD, issue, or specification already owns all product decisions and can hold execution evidence.

## Location and lifecycle

- Source priority: reuse a current project PRD, issue, or specification.
- Local fallback: `docs/workflows/<run-id>/brief.md`
- Preserve the language of an adopted Brief. For a new local Brief or run record, use the language the user requests. Otherwise follow the project's documentation language, falling back to the conversation language if the project has no established one.
- Status: `PLANNING`, `EXECUTING`, `VERIFYING`, or `COMPLETE`
- History: update the same authority and local run record; use their history or Git instead of correction documents.

Do not hash-lock a lean Brief or duplicate product facts. A resumed agent should find one authority for product facts and at most one local run record.

## Template

Write the headings, field labels, and content in the selected language. Keep the run ID, status values, and acceptance criterion identifiers stable.

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

- [ ] `AC-01` <사용자나 시스템이 관찰할 수 있는 완료 조건>

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

| AC/위험 | 검증 방법 | 결과 |
|---|---|---|

## 남은 위험

- `None` 또는 검증하지 못한 구체적 위험
```

## Quality rules

- State a specific human or system failure, not “improve X.”
- Give every preference a reason so the agent can generalize it.
- Make each `AC-<number>` criterion observable and keep its identifier stable through execution and verification.
- Record rejected alternatives only when they could otherwise recur.
- Ask only when an answer changes scope, behavior, risk acceptance, or a hard constraint.
- Verify discoverable facts instead of asking the user to recall them.
- Apply the project's living-context documentation rule before completion.

## Completion rules

Declare the run complete only when:

1. every acceptance criterion is checked or explicitly rejected by the user;
2. verification rows contain actual results rather than planned commands;
3. remaining risks are explicit;
4. living context documents affected by the change are updated, or the Brief records that none were affected;
5. the requested delivery action, if any, is complete.
