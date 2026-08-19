---
name: product-development-workflow
description: Run a planning-harness-first product workflow for new products or meaningful features with unresolved what/why decisions. Default to one authoritative Brief source, autonomous Execute, and deterministic Verify; reuse a current product document before creating a workflow Brief. Use the audited ten-stage path only when explicitly requested or when compliance, irreversible changes, formal handoffs, or high-risk security work require stage evidence. Do not use for small edits, isolated bugs, explanations, or research-only tasks.
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

Read `references/brief.md` completely. Read `references/model-fit.md` only when its trigger below applies. Do not load `references/stages.md`, `references/artifacts.md`, or the machine contract on the lean path.

### Brief

1. Inspect the repository and all material the user supplied before asking questions.
2. Reuse a current, authoritative project PRD, issue, or specification as the Brief when it can stay current and owns the product decisions. Otherwise create one Korean living document at `docs/workflows/<run-id>/brief.md`, using a lowercase hyphenated run ID.
3. When the authority is external or read-only, create a small local Brief that links to it and records only missing decisions, execution checkpoints, verification evidence, and remaining risks. Do not duplicate product facts.
4. Ensure the authority and any local run record together cover the problem, desired outcome, success signal, decision principles with reasons, hard constraints, non-goals, acceptance criteria, explicit decisions, rejected alternatives, and open product decisions.
5. Use the full source material when it fits the available context. Retrieve or chunk only when the corpus is too large, and preserve surrounding rules, exceptions, and document relationships.
6. Ask only about missing product information that would materially change the result. Do not repeat a ceremonial interview when the current request already establishes what, why, and the decision criteria.
7. Surface material assumptions, consequential alternatives, and user-owned open decisions together before Execute only when they could change the result. This is not an approval gate. Wait only when an open product decision blocks the direction.
8. Treat the user's explicit request as direction. Do not add a separate approval gate merely to confirm a faithful summary.

The adopted product document is the authority for product facts. A local Brief, when needed, owns only the run-specific decisions and evidence that the authority cannot hold. Keep each current and use Git history or the authority's history instead of correction documents.

### Model Fit

After the Brief is current and before Execute, read and apply `references/model-fit.md` when the host exposes at least two runnable model candidates or the user explicitly requests model selection.

1. Compare only host-reported or user-supplied candidates. Use one provider-neutral inventory for Claude, Codex, and future local runtimes.
2. Apply hard constraints before capability, representative eval evidence, context continuity, cost, and latency. Do not create a weighted score or map keywords directly to models.
3. Preserve the active model when the user pinned it, only one candidate is runnable, candidates are close, or evidence is too weak to repay a handoff, but only after the active model passes every non-negotiable hard constraint. A pinned model that conflicts with authorization, security, data policy, required capabilities, or budget must not run; record the conflict and stop for user direction.
4. Separate the recommendation from execution. Never claim to switch models, start another provider, or run a paid benchmark unless the host can perform that action and current authority permits it.
5. Record the exact candidate, effort, confidence, evidence, rejected alternatives, execution status, and re-evaluation trigger in the product authority's run record or local Brief checkpoint.

Model Fit is a bounded pre-execution recommendation, not a new approval stage or a fixed multi-model chain. If the active model still satisfies every acceptance criterion but the host cannot apply a recommended switch, continue the run and record it as a next-run recommendation.

### Execute

1. Work from the Brief and current repository state in one continuous primary-agent context.
2. Plan internally, choose the task order, and select tools from uncertainty and risk rather than keyword rules.
3. Use an installed provider skill only when its specialized capability directly helps the current task. Do not invoke a fixed chain of providers or inherit unrelated provider gates.
4. Use subagents only for genuine parallel work, context isolation, specialized tools, or an independent high-risk opinion. Do not split planner, writer, implementer, and reviewer roles for work one agent can own end to end.
5. Avoid multi-call prompt chains that pass summaries between stages when the complete task fits one context.
6. Do not auto-inject similarity-based memories. Read explicit project decisions and the living Brief instead.
7. Update the product authority or local Brief when the user makes a durable decision, rejects an alternative, changes a constraint, or when work pauses and needs a checkpoint.
8. Apply the project's living-context documentation rule before completion.
9. Escalate only product choices not settled by the Brief; follow the project's authority rules for side effects and irreversible actions.

### Verify

1. Check every acceptance criterion in the Brief and its authoritative sources against the implementation.
2. Run the project's deterministic checks: relevant tests, static analysis, build, schema or format validators, and critical user-flow checks.
3. Add targeted review only when the diff or risk profile justifies it. Prefer exact validators over open-ended requests to find problems.
4. If a check fails, fix the in-scope cause and rerun the affected checks. Never weaken a check to obtain a pass.
5. Record commands, exit results, observed behavior, remaining risks, and final status in the local Brief or the adopted authority's run record.
6. Report implementation correctness separately from checks that prove only structure or formatting.
7. When the active model is GPT-5.6 Sol, Claude Opus 5, or Claude Fable 5, read `references/model-verification.md` and apply only the matching model section.

Do not require a fixed model-generated review pass or run generic self-review loops. Deterministic project checks remain mandatory; add targeted review only under step 3 or the matching model guidance.

## Resume a lean run

Read the adopted product authority, any local Brief, project rules, Git status, diff, and recent commits. Continue from the recorded checkpoint and current repository truth. Do not replay completed discovery or reconstruct a chain of intermediate summaries.

## Run the audited path

The audited path is the preserved ten-stage compatibility workflow.

1. Read `references/stages.md` and `references/artifacts.md` completely.
2. Treat `agents/workflows/product-development/workflow.toml` as authoritative for its ten stages and artifacts.
3. Find the state command in this order: `dotagents-workflow` on `PATH`, `<project>/.dotagents/bin/dotagents-workflow`, then `./tooling/scripts/workflow.sh` inside dotagents.
4. Follow the stage, approval, resume, adopt, and verification contracts in those references.

The audited CLI verifies stage order, artifact safety, approval continuity, and hashes. It does not prove implementation correctness; stages 7-9 must contain real test and QA evidence.

## Complete the work

For `lean`, finish after the run record is updated with verification evidence, affected living context documents are current, and the user-requested delivery action is complete. For `audited`, finish only after the CLI `verify` command succeeds. In both paths, report unresolved risks and do not treat shipping as implicit unless the user requested it.

When the run surfaced a convention, rule, or template worth reusing beyond this project, list it in the completion report as a dotagents promotion candidate with a proposed destination. Do not modify dotagents in the same run; apply accepted candidates through the `dotagents-promote` skill under separate approval.

## Safety

- Preserve project-specific rules, user changes, package managers, test commands, and release policy.
- Never store secrets or hidden memory payloads in the Brief.
- Never modify an external provider as a side effect of this workflow.
- Use separate branches or worktrees for truly concurrent implementation.
