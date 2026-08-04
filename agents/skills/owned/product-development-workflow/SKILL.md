---
name: product-development-workflow
description: Run a planning-harness-first product workflow for new products or meaningful features with unresolved what/why decisions. Default to one living Brief, autonomous Execute, and deterministic Verify; use the audited ten-stage path only when explicitly requested or when compliance, irreversible changes, formal handoffs, or high-risk security work require stage evidence. Do not use for small edits, isolated bugs, explanations, or research-only tasks.
---

# Product Development Workflow

Keep the planning harness mandatory and the execution harness light. Preserve what the user is building, why it matters, how tradeoffs should be decided, and which constraints cannot move. Let the capable model choose the execution order, tools, and local plan.

## Route the request

Choose one path before creating artifacts:

- `direct`: a small edit, isolated bug, explanation, or research-only task. Do not use this workflow; follow the project's normal edit-and-verify path.
- `lean`: any product task routed to this skill. This is the default, including substantial features.
- `audited`: use only when the user explicitly requests the ten-stage workflow or when formal evidence is required for compliance, sensitive security boundaries, irreversible data migration, cross-team approval, or a long-lived handoff.

Do not choose `audited` from file count, task size, or model distrust alone. Explain the concrete risk that requires it. If no such risk exists, use `lean`.

If a `lean` run must escalate to `audited` mid-run, keep the Brief as source material. The audited CLI refuses `start` when the run's artifact directory already exists, so either start a new run ID or author the canonical stage artifacts in the same directory and use `adopt` after the user reviews them.

## Run the lean path

Read `references/brief.md` completely. Do not load `references/stages.md`, `references/artifacts.md`, or the machine contract on the lean path.

### Brief

1. Inspect the repository and all material the user supplied before asking questions.
2. Create one Korean living document at `docs/workflows/<run-id>/brief.md`, using a lowercase hyphenated run ID.
3. Capture the problem, desired outcome, success signal, decision principles with reasons, hard constraints, non-goals, acceptance criteria, explicit decisions, rejected alternatives, and open product decisions.
4. Use the full source material when it fits the available context. Retrieve or chunk only when the corpus is too large, and preserve surrounding rules, exceptions, and document relationships.
5. Ask only about missing product information that would materially change the result. Do not repeat a ceremonial interview when the current request already establishes what, why, and the decision criteria.
6. Treat the user's explicit request as direction. Do not add a separate approval gate merely to confirm a faithful summary. Stop only for a consequential unresolved product choice.

The Brief is the planning harness and the single source of truth. Edit it as decisions change. Git history and its decision log preserve history; do not create correction documents that compete with the current truth.

### Execute

1. Work from the Brief and current repository state in one continuous primary-agent context.
2. Plan internally, choose the task order, and select tools from uncertainty and risk rather than keyword rules.
3. Use an installed provider skill only when its specialized capability directly helps the current task. Do not invoke a fixed chain of providers or inherit unrelated provider gates.
4. Use subagents only for genuine parallel work, context isolation, specialized tools, or an independent high-risk opinion. Do not split planner, writer, implementer, and reviewer roles for work one agent can own end to end.
5. Avoid multi-call prompt chains that pass summaries between stages when the complete task fits one context.
6. Do not auto-inject similarity-based memories. Read explicit project decisions and the living Brief instead.
7. Update the Brief when the user makes a durable decision, rejects an alternative, changes a constraint, or when work pauses and needs a checkpoint.
8. Ask before irreversible actions, external side effects outside the authorized workflow, or product choices not settled by the Brief. Make reversible technical choices autonomously and record the important ones.

### Verify

1. Check every acceptance criterion in the Brief against the implementation.
2. Run the project's deterministic checks: relevant tests, static analysis, build, schema or format validators, and critical user-flow checks.
3. Add targeted review only when the diff or risk profile justifies it. Prefer exact validators over open-ended requests to find problems.
4. If a check fails, fix the in-scope cause and rerun the affected checks. Never weaken a check to obtain a pass.
5. Record commands, exit results, observed behavior, remaining risks, and final status in the same Brief.
6. Report implementation correctness separately from checks that prove only structure or formatting.

Do not run generic self-review loops until the model declares its own answer good. One evidence-based review pass plus deterministic verification is the default.

## Resume a lean run

Read the living Brief, project rules, Git status, diff, and recent commits. Continue from the recorded checkpoint and current repository truth. Do not replay completed discovery or reconstruct a chain of intermediate summaries.

## Run the audited path

The audited path is the preserved ten-stage compatibility workflow.

1. Read `references/stages.md` and `references/artifacts.md` completely.
2. Treat `agents/workflows/product-development/workflow.toml` as authoritative for its ten stages and artifacts.
3. Find the state command in this order: `dotagents-workflow` on `PATH`, `<project>/.dotagents/bin/dotagents-workflow`, then `./tooling/scripts/workflow.sh` inside dotagents.
4. Follow the stage, approval, resume, adopt, and verification contracts in those references.

The audited CLI verifies stage order, artifact safety, approval continuity, and hashes. It does not prove implementation correctness; stages 7-9 must contain real test and QA evidence.

## Complete the work

For `lean`, finish after the Brief is updated with verification evidence and the user-requested delivery action is complete. For `audited`, finish only after the CLI `verify` command succeeds. In both paths, report unresolved risks and do not treat shipping as implicit unless the user requested it.

## Safety

- Preserve project-specific rules, user changes, package managers, test commands, and release policy.
- Never store secrets or hidden memory payloads in the Brief.
- Never modify an external provider as a side effect of this workflow.
- Use separate branches or worktrees for truly concurrent implementation.
