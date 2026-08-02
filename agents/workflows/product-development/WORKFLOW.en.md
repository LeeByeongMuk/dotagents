# Product Development Workflow

[한국어](WORKFLOW.md)

This reusable ten-stage process moves from interview through domain modeling, design, spec, plan, implementation, review, and architecture assessment. Every stage leaves a Korean-English artifact pair and explicit user approval so Claude Code, Codex, Gemini, or a later session can resume from the same point.

## When to use it

Use it for:

- A new product or feature moving from idea to implementation
- `standard` work with unresolved user, domain, or scope decisions
- `substantial` work spanning multiple surfaces, services, boundaries, or architecture decisions

Do not use it for a known small edit, an isolated bug, an explanation, or research-only work.

## Ten stages

| Stage | Result |
|---|---|
| 1. Grill-me interview | User, problem, status quo, evidence, success criteria |
| 2. Domain document | Language, actors, invariants, boundaries, non-goals |
| 3. gstack office hours | Premise challenge, alternatives, approved design |
| 4. Light spec | User stories, behavior, acceptance criteria, constraints |
| 5. Plan | Exact files, tasks, tests, and verification commands |
| 6. Plan review | Scope, architecture, test, and performance review |
| 7. Subagent implementation | Tasks, changed files, commits, check evidence |
| 8. Code/test review | Diff review, tests, build, and QA results |
| 9. Architecture assessment/improvement | Assessment, approved changes, full re-verification |
| 10. Skill-refactoring candidate | Repeated procedures and skill-candidate report (optional) |

The machine contract is [workflow.toml](workflow.toml); agent execution rules live in [SKILL.md](../../skills/owned/product-development-workflow/SKILL.md).

## Install

Check the dry run from the repository root:

```bash
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global
```

For one project only:

```bash
./tooling/scripts/install.sh --dry-run --project /path/to/project
./tooling/scripts/install.sh --project /path/to/project
```

Global installation provides `~/.local/bin/dotagents-workflow`; project installation provides `<project>/.dotagents/bin/dotagents-workflow`. The installer warns when `~/.local/bin` is not on `PATH`, and the full path still works.

## Use

The simplest entry is to request the skill in a supported host:

```text
Use $product-development-workflow to take this product idea from interview through implementation review.
```

The skill classifies the work and starts a run. You can also use the state tool directly:

```bash
dotagents-workflow start \
  --project /path/to/project \
  --run checkout-redesign \
  --scope substantial

dotagents-workflow status \
  --project /path/to/project \
  --run checkout-redesign
```

Artifacts appear under `<project>/docs/workflows/checkout-redesign/`:

```text
01-interview.md
01-interview.en.md
02-domain.md
02-domain.en.md
...
```

The agent presents both files and calls the following command only after explicit approval:

```bash
dotagents-workflow approve \
  --project /path/to/project \
  --run checkout-redesign \
  --stage 1 \
  --user-approved
```

`--user-approved` represents a human decision that file existence cannot replace. A general request to proceed or silence is not stage approval. Approval records the SHA-256 of both files, so `status`, later approvals, and `verify` fail if either approved artifact changes. Keep approved artifacts immutable; record corrections as a new decision in a later stage or replace the run.

### Start from an existing spec or plan

Copy existing documents to the canonical names for the run and fill the required prior-stage content. After the user reviews and approves the whole set, adopt it:

```bash
dotagents-workflow adopt \
  --project /path/to/project \
  --run existing-plan \
  --scope standard \
  --through 5 \
  --user-approved
```

Empty placeholders and symbolic links are rejected.

### Verify completion

A full run completes after stage 10. A run started with `--skip-skill-refactor` completes after stage 9.

```bash
dotagents-workflow verify \
  --project /path/to/project \
  --run checkout-redesign
```

This verifies stage order, safe artifact pairs, approval records, and terminal state. It does not independently prove code correctness; actual test and QA evidence belongs in stages 7–9.

## External skills

External skills are optional providers:

- Interview: Matt Pocock's `grilling` (`grill-me` compatibility entry)
- Design, plan review, and code review: gstack
- Implementation planning: Superpowers `writing-plans`

When an installed provider is compatible, the workflow uses it. If it is absent or fails, one built-in attempt continues under the same artifact contract. The workflow never installs or modifies an external skill automatically. Reviewed sources and commits are recorded in `agents/registry/skills.toml` and `agents/registry/sources.lock`.

## Recovery and safety

- Use `status` to see the interruption point and next artifact.
- If the state file is lost but artifacts and an empty run-state directory remain, review and recover them with `adopt`.
- A lock prevents concurrent mutation of one run; stale locks are reclaimed under documented safety rules.
- Different run IDs isolate state, not code changes. Use separate branches/worktrees for parallel implementation.
- Any stage 9 code change requires a complete rerun of relevant stage 8 checks.
- Stage 10 produces a candidate report by default. Creating a real skill requires separate authorization.
