---
name: product-development-workflow
description: Use for product planning, product discovery, new products, or meaningful features with unresolved what/why decisions. Route planning-only requests to a non-mutating Plan, implementation requests to Brief → Execute → Verify, and formal high-risk work to audited. Reuse a current PRD, issue, or specification. Do not use for small edits, isolated bugs, explanations, or fact-finding that does not require a product decision.
---

# Product Development Workflow

Keep one shared product-decision contract across hosts. Preserve what the user is building, why it matters, how tradeoffs should be decided, and which constraints cannot move. Let the active model choose execution details inside the user's authorization boundary.

## Route the request

Choose one path before creating artifacts or changing files:

- `direct`: a small edit, isolated bug, explanation, or factual lookup that does not make a product decision. Do not use this workflow; follow the project's normal path.
- `plan`: the user asks to discover a product problem, define requirements, compare product alternatives, design, or plan without authorizing implementation. Inspect relevant material and return or update the requested planning artifact, then stop before Execute.
- `lean`: the user authorizes building or changing a product or meaningful feature. This is the default implementation path: Brief → Execute → Verify.
- `audited`: the user explicitly requests the ten-stage workflow, or formal evidence is required for compliance, sensitive security boundaries, irreversible data migration, cross-team approval, or a long-lived handoff.

Do not choose `audited` from file count, task size, or model distrust alone. Explain the concrete evidence requirement. If none exists, use `plan` or `lean` according to the user's requested action.

Words such as “research” or “explore” do not choose the route by themselves: use `plan` when the result makes product decisions and `direct` for factual lookup. If planning and implementation are requested together, use `lean` unless the implementation needs audited evidence. A high-risk subject alone does not authorize implementation; remain on `plan` until the user requests implementation or an audited artifact.

## Run the plan path

1. Inspect the repository and all material the user supplied before asking questions.
2. Reuse the current PRD, issue, or specification when it owns the product decisions. Do not create a workflow Brief or change files unless the user requested a durable artifact.
3. Return a compact plan that covers the problem, desired outcome and success signal, decision principles with reasons, hard constraints and non-goals, `AC-<number>` acceptance criteria, explicit decisions and rejected alternatives, and open product decisions.
4. Ask only when two plausible answers would materially change scope, behavior, risk acceptance, or a hard constraint. Otherwise state the assumption and recommendation.
5. Do not Execute, Verify an implementation, or reinterpret a planning request as authorization to build.

## Run the lean path

### Brief

1. Inspect the repository and supplied material before asking questions.
2. Reuse a current, authoritative project PRD, issue, or specification as the Brief when it can stay current and owns the product decisions.
3. Only when no suitable authority exists, read `references/brief-template.md` completely and create one Korean living document at `docs/workflows/<run-id>/brief.md`, using a lowercase hyphenated run ID.
4. When the authority is external or read-only, read the template and create a small local run record that links to it and owns only missing decisions, checkpoints, verification evidence, and remaining risks.
5. Ensure the authority and any local run record together cover the same product fields required by the plan path, plus execution checkpoints and verification evidence. Use stable `AC-<number>` identifiers from planning through verification.
6. Surface material assumptions, consequential alternatives, and user-owned open decisions together before Execute only when they could change the result. This is not an approval gate. Wait only when an open product decision blocks the direction.

The adopted product document is the authority for product facts. Keep it and at most one local run record current. Use their history or Git history instead of correction documents.

### Execute

1. Work from the Brief and current repository state in one continuous primary-agent context.
2. Plan internally and choose the task order and tools from uncertainty and risk rather than keyword rules.
3. Use an installed provider skill only when its specialized capability directly helps the current task. Do not invoke a fixed provider chain.
4. Use subagents only for genuine parallel work, context isolation, specialized tools, or an independent high-risk opinion. Do not split roles that one agent can own end to end.
5. Give every subagent a self-contained task, scope or file boundary, material constraints, expected evidence, and verification command. Do not assume it inherited the parent conversation or project instructions.
6. Do not auto-inject similarity-based memories. Read explicit project decisions and the living Brief instead.
7. Update the product authority or local run record when a durable decision, constraint, checkpoint, or remaining risk changes.
8. Apply the project's living-context documentation rule before completion.
9. Escalate only product choices not settled by the Brief; follow project authority rules for side effects and irreversible actions.

### Verify

1. Check every `AC-<number>` acceptance criterion against the implementation and record exact evidence.
2. Run the project's deterministic checks: relevant tests, static analysis, build, schema or format validators, and critical user-flow checks.
3. Add targeted review only when a concrete diff risk or acceptance criterion justifies it. Prefer exact validators over open-ended review.
4. Read exactly one host reference when it exists: `references/codex.md` on Codex or `references/claude.md` on Claude Code. On other hosts, use only this common policy. Never load an unrelated host reference.
5. If a check fails, fix the in-scope cause and rerun affected checks. Never weaken a check to obtain a pass.
6. Record commands, exit results, observed behavior, remaining risks, and final status in the local run record or adopted authority.
7. Report implementation correctness separately from checks that prove only structure or formatting.

Do not require a fixed model-generated review pass or generic self-review loop. Deterministic project checks remain mandatory.

## Resume a lean run

Read the adopted product authority, any local run record, project rules, Git status, diff, and recent commits. Continue from the recorded checkpoint and current repository truth without replaying completed discovery.

## Run the audited path

The audited path preserves the ten-stage compatibility workflow.

1. Read `references/stages.md` and `references/artifacts.md` completely.
2. Treat `agents/workflows/product-development/workflow.toml` as authoritative for its stages and artifacts.
3. Find the state command in this order: `dotagents-workflow` on `PATH`, `<project>/.dotagents/bin/dotagents-workflow`, then `./tooling/scripts/workflow.sh` inside dotagents.
4. Follow the stage, approval, resume, adopt, and verification contracts in those references.

The audited CLI proves stage order, artifact safety, approval continuity, and hashes. It does not prove implementation correctness; stages 7–9 must contain real test and QA evidence.

## Complete the work

For `lean`, finish after acceptance criteria have evidence, the run record and affected living context documents are current, and the requested delivery action is complete. For `audited`, finish only after the CLI `verify` command succeeds. Report unresolved risks and do not treat shipping as implicit.

When the run surfaces a portable convention, list it as a dotagents promotion candidate with a proposed destination. Apply it only through the separately authorized `dotagents-promote` skill.

## Safety

- Preserve project rules, user changes, package managers, test commands, and release policy.
- Never store secrets or hidden memory payloads in planning artifacts.
- Never modify an external provider as a side effect of this workflow.
- Use separate branches or worktrees for truly concurrent implementation.
