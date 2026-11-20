---
name: dotagents-promote
description: Prepare reusable rules, templates, or skills in the checkout behind the user's global dotagents installation. Use when they ask to add a convention to their dotagents setup or accept a promotion candidate proposed in a workflow completion report.
---

# Dotagents Promote

Use this workflow when maintaining your own global dotagents installation. The destination is the local clone or fork linked to that installation. Follow the [Git rules](../../../rules/git.md) for commit authorization.

## Collect and classify candidates

1. Start from the candidates the user named or accepted from a completion report. Otherwise review the current session for durable, project-agnostic learnings: corrected agent behavior, repeated conventions, reusable structures.
2. Assign each candidate one destination:
   - `agents/rules/<topic>.md`: meta-rules that hold in every project regardless of stack.
   - `agents/templates/<profile>/`: stack- or domain-specific conventions.
   - `agents/skills/owned/<name>/`: repeatable multi-step procedures.
   - Reject: anything tied to one project belongs in that project's `AGENTS.md`, not in dotagents.
3. Reject candidates that contain project paths, service names, credentials, or one-off context. When the final list differs from what the user asked for, confirm it before editing.

## Apply on an isolated worktree

1. Run [scripts/resolve-source.sh](scripts/resolve-source.sh) from the installed skill directory and use its output as `<repo>`. It verifies the global installation (legacy `.agents` link or managed installation record and live rules link) and checks that its primary checkout is on `main`. Stop if the resolver fails.
2. Never edit the primary checkout. Preserve its existing index and working tree and start the promotion from the committed state of `main`.
3. Create a worktree: `git -C <repo> worktree add <scratch>/promote-<slug> -b promote/<slug> main`.
4. Edit inside the worktree only. Follow the repository's conventions: Korean human-readable docs, the existing rule and template styles, and no rule text duplicated into adapters.
5. When a change adds required files or edits contract lines, update `tooling/scripts/check.sh` and the `tooling/tests/` assertions in the same branch.

## Verify and hand off

1. When a change affects a common rule or host adapter used to generate `dist/`, run `make build` inside the worktree. Run `make check` for every promotion.
2. Hand off the promotion branch with unstaged changes by default. If the user explicitly requests a commit and verification passes, stage only the promotion changes and commit with a message that names the promoted convention. Do not merge into `main` and do not push.
3. Report the branch name, worktree path, verification result, and a diff summary. Keep the worktree available for review.

## Safety

- Never run this skill as a hook or as a side effect of another task.
- Never promote secrets, private organization details, or project-identifying content.
