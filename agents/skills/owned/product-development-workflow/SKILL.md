---
name: product-development-workflow
description: Use for product planning, product discovery, new products, or meaningful features with unresolved what/why decisions. Route planning-only requests to a non-mutating Plan and implementation requests to Brief → Execute → Verify. Reuse a current PRD, issue, or specification. Do not use for small edits, isolated bugs, explanations, or fact-finding that does not require a product decision.
---

# Product Development Workflow

Keep one shared product-decision contract across hosts. Preserve what the user is building, why it matters, how tradeoffs should be decided, and which constraints cannot move. Let the active model choose execution details inside the user's authorization boundary.

## Route the request

Choose one path before creating artifacts or changing files:

- `direct`: a small edit, isolated bug, explanation, or factual lookup that does not make a product decision. Do not use this workflow; follow the project's normal path.
- `plan`: the user asks to discover a product problem, define requirements, compare product alternatives, design, or plan without authorizing implementation. Inspect relevant material and return or update the requested planning artifact, then stop before Execute.
- `lean`: the user authorizes building or changing a product or meaningful feature: Brief → Execute → Verify.

When compliance, a sensitive security boundary, an irreversible data change, or cross-team approval requires formal evidence, stay on `lean` and make the required approvals and evidence acceptance criteria in the Brief.

Words such as “research” or “explore” do not choose the route by themselves: use `plan` when the result makes product decisions and `direct` for factual lookup. If planning and implementation are requested together, use `lean`. A high-risk subject alone does not authorize implementation; remain on `plan` until the user requests implementation.

## Run the plan path

1. Reuse the current PRD, issue, or specification when it owns the product decisions. Do not create a workflow Brief or change files unless the user requested a durable artifact.
2. Return a compact plan that covers the problem, desired outcome and success signal, decision principles with reasons, hard constraints and non-goals, `AC-<number>` acceptance criteria, explicit decisions and rejected alternatives, and open product decisions.
3. Ask only when two plausible answers would materially change scope, behavior, risk acceptance, or a hard constraint. Otherwise state the assumption and recommendation.
4. Do not Execute, Verify an implementation, or reinterpret a planning request as authorization to build.

## Run the lean path

Read `references/model-fit.md` only when its trigger below applies.
### Brief

1. Reuse a current, authoritative project PRD, issue, or specification as the Brief when it can stay current and owns the product decisions.
2. Only when no suitable authority exists, read `references/brief-template.md` completely and create one Korean living document at `docs/workflows/<run-id>/brief.md`, using a lowercase hyphenated run ID.
3. When the authority is external or read-only, read the template and create a small local run record that links to it and owns only missing decisions, checkpoints, verification evidence, and remaining risks.
4. Ensure the authority and any local run record together cover the same product fields required by the plan path, plus execution checkpoints and verification evidence. Use stable `AC-<number>` identifiers from planning through verification.
5. Surface material assumptions, consequential alternatives, and user-owned open decisions together before Execute only when they could change the result. This is not an approval gate. Wait only when an open product decision blocks the direction.

The adopted product document is the authority for product facts. Keep it and at most one local run record current. Use their history or Git history instead of correction documents.

### Model Fit

After the Brief is current and before Execute, read and apply `references/model-fit.md` only when the user explicitly asks to choose or compare models. A host that merely offers several models is not a trigger. That reference owns the candidate inventory, decision order, and result record.

Separate the recommendation from execution. Model Fit is a bounded pre-execution recommendation, not a new approval stage or a fixed multi-model chain. If the active model still satisfies every acceptance criterion but the host cannot apply a recommended switch, continue the run and record it as a next-run recommendation.

### Execute

1. Work from the Brief and current repository state in one continuous primary-agent context.
2. Use an installed provider skill only when its specialized capability directly helps the current task. Do not invoke a fixed provider chain.
3. Use subagents only for genuine parallel work, context isolation, specialized tools, or an independent high-risk opinion.
4. Give every subagent a self-contained task, scope or file boundary, material constraints, expected evidence, and verification command. Do not assume it inherited the parent conversation or project instructions.
5. Do not auto-inject similarity-based memories. Read explicit project decisions and the living Brief instead.
6. Update the product authority or local run record when a durable decision, constraint, checkpoint, or remaining risk changes.
7. Apply the project's living-context documentation rule before completion.
8. Escalate only product choices not settled by the Brief; follow project authority rules for side effects and irreversible actions.

### Verify

1. Check every `AC-<number>` acceptance criterion against the implementation and record exact evidence.
2. Run the project's deterministic checks: relevant tests, static analysis, build, schema or format validators, and critical user-flow checks.
3. Add targeted review only when a concrete diff risk or acceptance criterion justifies it. Prefer exact validators over open-ended review.
4. Read exactly one host reference when it exists: `references/codex-cli.md` on Codex or `references/claude-code.md` on Claude Code. On other hosts, use only this common policy. Never load an unrelated host reference.
5. If a check fails, fix the in-scope cause and rerun affected checks. Never weaken a check to obtain a pass.
6. Record commands, exit results, observed behavior, remaining risks, and final status in the local run record or adopted authority.
7. Report implementation correctness separately from checks that prove only structure or formatting.

Do not require a fixed model-generated review pass or generic self-review loop. Deterministic project checks remain mandatory.

## Resume a run

Read the adopted product authority, any local run record, project rules, Git status, diff, and recent commits. Continue from the recorded checkpoint and current repository truth without replaying completed discovery.

## Complete the work

For `lean`, finish after acceptance criteria have evidence, the run record and affected living context documents are current, and the requested delivery action is complete. Report unresolved risks and do not treat shipping as implicit.

When the run surfaces a portable convention, list it as a dotagents promotion candidate with a proposed destination. Apply it only through the separately authorized `dotagents-promote` skill.

## Safety

- Preserve project rules, user changes, package managers, test commands, and release policy.
- Never store secrets or hidden memory payloads in planning artifacts.
- Never modify an external provider as a side effect of this workflow.
- Use separate branches or worktrees for truly concurrent implementation.
