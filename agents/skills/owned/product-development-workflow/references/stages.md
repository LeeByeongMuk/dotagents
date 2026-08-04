# Audited stage execution reference

Read this reference only after the workflow has selected the audited path. Installed provider skills are optional accelerators. Their absence must not change the artifact or approval contract.

## Provider rules

- Discover providers through the host's available-skill inventory. Do not assume a home-directory path.
- Invoke a provider only when its current description matches the stage.
- Preserve the provider's own hard gates.
- If a provider fails, capture the failure concisely in the current artifact and run the built-in procedure once.
- Never fetch or modify an external provider as a side effect of this workflow.

## 1. Grill-me interview

Preferred provider: `grilling` or its compatibility entry `grill-me`.

Built-in procedure:

1. Inspect the repository and supplied material before asking factual questions.
2. Ask one question at a time.
3. Cover the target user, current behavior, painful moment, desired outcome, non-goals, constraints, evidence, and success signal.
4. Challenge vague answers with a concrete example.
5. Stop only when both sides share the same problem statement.

Do not implement anything in this stage.

## 2. Domain document

Built-in procedure:

1. Extract actors and their goals.
2. Define ubiquitous language and reject synonyms that hide different meanings.
3. Identify entities, value objects, commands, events, policies, and invariants only where the domain needs them.
4. Draw system and domain boundaries.
5. Record unresolved terms, assumptions, and explicit non-goals.

Keep this lighter than a full domain-driven-design program when the product does not need one.

## 3. Office hours

Preferred provider: gstack `office-hours`.

Built-in procedure:

1. Restate the problem and constraints from stages 1–2.
2. Challenge at least three load-bearing premises.
3. Present two or three materially different approaches.
4. Give an opinionated recommendation with user impact and tradeoffs.
5. Obtain explicit approach selection and write the design.

Do not start implementation before approval.

## 4. Light spec

Built-in procedure:

1. State goals and non-goals.
2. Define users and primary stories.
3. Write observable acceptance criteria.
4. Record functional behavior, failure behavior, constraints, dependencies, and open questions.
5. Keep architecture detail out unless it changes product behavior or feasibility.

## 5. Plan

Preferred provider: Superpowers `writing-plans`.

Built-in procedure:

1. Re-read the approved design and spec.
2. Break work into small, independently verifiable tasks.
3. Name exact files to create or modify when discoverable.
4. Put a failing test or validation before each behavior change where practical.
5. Give exact commands and expected outcomes.
6. Include documentation, migration, rollback, and distribution work when applicable.

## 6. Plan review

Preferred provider: gstack `autoplan`; otherwise use the relevant CEO, design, developer-experience, and engineering plan-review skills. Engineering review is always required for substantial work.

Built-in procedure:

1. Challenge scope and identify existing code to reuse.
2. Review component boundaries, data flow, trust boundaries, failure modes, and operational recovery.
3. Trace every planned code path to a test.
4. Review performance and developer experience.
5. Resolve blocking findings by recording plan amendments in `06-plan-review`; do not edit the approved `05-plan` artifact. Record accepted, rejected, and deferred recommendations. Stage 7 treats the newer approved review as the superseding decision.

## 7. Subagent implementation

Built-in procedure:

1. Reconcile `04-spec`, `05-plan`, and `06-plan-review`; the newest explicit approval wins conflicts.
2. Use a fresh subagent for each independent task when available. Give it the task, approved context, file boundary, and verification command.
3. After each task, review specification compliance before code quality.
4. Keep dependent tasks sequential. Use separate worktrees for parallel code changes.
5. Follow the repository's test-first or regression-test rules and commit discipline.
6. Record the actual files, commits, commands, failures, and deviations from plan.

## 8. Code and test review

Preferred providers: gstack `review`, then `qa` for interactive products or `qa-only` when fixes are outside the requested scope.

Built-in procedure:

1. Inspect the complete diff against the base branch.
2. Run syntax, static checks, unit/integration tests, and build commands required by the project.
3. Exercise critical user flows and visible failure states where the product can be run.
4. Fix authorized in-scope findings and rerun every affected check.
5. Record unresolved issues rather than hiding or weakening a test.

## 9. Architecture assessment and improvement

Built-in procedure:

1. Assess coupling, cohesion, duplication, dependency direction, state ownership, trust boundaries, and recovery paths.
2. Prefer no change when the implementation is already engineered enough.
3. Propose behavior-preserving changes with concrete evidence and blast radius.
4. Obtain user authorization before changing architecture.
5. After any code change, rerun every relevant stage 8 command and user flow.

## 10. Skill-refactoring candidate

Preferred provider for authorized creation: `skill-creator`.

Built-in procedure:

1. Identify only procedures that succeeded repeatedly or have strong evidence of recurrence.
2. Separate project-specific knowledge from portable instructions.
3. Propose trigger conditions, inputs, outputs, guardrails, and forward tests.
4. Recommend `no skill` when the behavior is one-off or too context-dependent.
5. Produce a report only. Create or update a skill only under separate explicit write scope.
