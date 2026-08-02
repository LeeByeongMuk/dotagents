---
name: product-development-workflow
description: Run a resumable ten-stage product-development workflow from interview and domain modeling through spec, plan, implementation, review, architecture assessment, and an optional skill-refactoring report. Use for a new product or substantial feature with unresolved product decisions. Do not use for small edits, isolated bugs, explanations, or research-only tasks.
---

# Product Development Workflow

Turn an unsettled product idea into implementation with explicit user approvals, bilingual artifacts, and resumable local state. Keep the workflow portable: prefer compatible installed skills, but use the built-in procedure when a provider is absent or fails.

## Required references

Read these files completely before starting or resuming a run:

1. `references/stages.md` for stage execution and provider fallbacks.
2. `references/artifacts.md` for required artifact content and evidence.

The machine contract is `agents/workflows/product-development/workflow.toml` in the dotagents source. Treat it as authoritative for stage numbers, artifact basenames, and optionality.

## Route the request

Classify the task before creating state:

- `small`: a known local change with no unresolved product or domain decision. Do not start this workflow; use the project's normal implementation and verification path.
- `standard`: new behavior or unresolved requirements within one bounded area.
- `substantial`: multiple surfaces, services, or domain boundaries, or a meaningful architecture decision.

If the user explicitly invokes this skill, confirm only the `standard` versus `substantial` scope when it is not evident. Otherwise, explain why the workflow applies and obtain confirmation before starting it. The user decides product scope; do not infer a consequential choice from silence.
Explicit invocation does not turn a `small` task into product work. Explain that the normal edit-and-verify path is more appropriate and do not create workflow state or ask for a scope tier.

## Find the state command

Use the first executable path that exists:

1. `dotagents-workflow` on `PATH`.
2. `<project>/.dotagents/bin/dotagents-workflow`.
3. `./tooling/scripts/workflow.sh` when working in the dotagents repository.

If none exists, stop and tell the user to rerun the dotagents global or project installer. Do not recreate state manually.

## Start, resume, or adopt

Use a lowercase hyphenated run ID that names the feature.

For a new run:

```bash
dotagents-workflow start --project <project-root> --run <run-id> --scope <standard|substantial>
```

Add `--skip-skill-refactor` only when the user does not want stage 10. `start` never creates artifact content.

For an existing run, call `status` and continue at `current_stage`:

```bash
dotagents-workflow status --project <project-root> --run <run-id>
```

If existing approved material should become stages 1 through N, copy it into the exact canonical bilingual artifact names, fill any required missing sections, show the whole set to the user, and only after explicit approval run:

```bash
dotagents-workflow adopt --project <project-root> --run <run-id> \
  --scope <standard|substantial> --through <N> --user-approved
```

Never approve empty placeholders. Never adopt symlinks or documents outside the canonical artifact directory.

## Execute one stage at a time

For the current stage:

1. Read every approved prior artifact relevant to the decision. Stage 7 must read the spec, plan, and plan review together.
2. Use the preferred provider from `references/stages.md` when it is installed and compatible.
3. If the provider is absent, execute the built-in procedure. If an installed provider fails, record that failure in the current artifact and execute the built-in procedure once. Do not install, downgrade, or edit an external skill unless the user separately requests it.
4. Create both `<artifact>.md` in Korean and `<artifact>.en.md` in English under `docs/workflows/<run-id>/`. Keep them semantically equivalent and mark their content `FINAL` before presenting them for approval.
5. Check the artifact against `references/artifacts.md`. For stages 7–9, include commands, exit results, changed files, remaining failures, and decisions.
6. Present the result and ask the user for explicit approval. Product decisions and gates belong to the user.
7. Only after an affirmative answer, advance with:

```bash
dotagents-workflow approve --project <project-root> --run <run-id> \
  --stage <N> --user-approved
```

8. Call `status` and report the next stage.

Do not combine approval for an unseen artifact with the work that creates it. Do not call `--user-approved` based on an earlier general request to proceed.
Do not edit an approved artifact. Its recorded SHA-256 hashes make it immutable workflow evidence; put later corrections in a newly approved stage or replace the run explicitly.

## Stage-specific gates

- Stage 3: compare at least two viable approaches and record why the user selected one.
- Stage 5: include exact files, small build tasks, tests, and verification commands.
- Stage 6: resolve every blocking plan-review finding before approval.
- Stage 7: use fresh subagents per independent task when the host supports them; otherwise execute the same task boundaries inline. Follow the project test discipline.
- Stage 8: run the project's required checks and product-appropriate QA. Fix in-scope findings, rerun the checks, and preserve evidence.
- Stage 9: assess before changing. Make architecture changes only with evidence and user authorization, then rerun every relevant stage 8 check.
- Stage 10: report repeated successful procedures and skill candidates. Creating or modifying a reusable skill needs separate write authorization.

A generic affirmative reply to the stage 10 report approves only that report. Treat skill creation as authorized only when the user explicitly asks to create or modify the named skill and its target location.

## Complete the run

After the final required stage is approved, run:

```bash
dotagents-workflow verify --project <project-root> --run <run-id>
```

Report the structural verification result separately from implementation correctness. Summarize the artifact directory, checks recorded in stages 7–9, unresolved concerns, and the optional next action such as shipping or opening a PR. Shipping is not an implicit eleventh stage.

## Safety rules

- Never write runtime state under the shared `.agents` link.
- Never edit state files by hand or source them as shell code.
- Treat artifact translation quality as a human/agent review, not something the CLI proves.
- Use separate branches or worktrees for concurrent implementation runs; run IDs isolate state, not code changes.
- Preserve project-specific rules, test commands, package managers, and release policy.
