---
name: dotagents-promote
description: Identify reusable conventions for the user's own dotagents installation when they request candidates, or prepare changes when they ask to apply a convention.
---

# Dotagents Promote

Use this workflow when maintaining your own global dotagents installation. The destination is the local clone or fork linked to that installation. Follow the [Git rules](../../../rules/git.md) for commit authorization.

## Collect and classify candidates

1. Start with the conventions the user named. When asked to find candidates, review the session for corrected agent behavior, repeated conventions, and reusable structures.
2. Assign each candidate one destination:
   - `agents/rules/<topic>.md`: meta-rules that hold in every project regardless of stack.
   - `agents/templates/<profile>/`: stack- or domain-specific conventions.
   - `agents/skills/owned/<name>/`: repeatable multi-step procedures.
   - Reject: anything tied to one project belongs in that project's `AGENTS.md`, not in dotagents.
3. Exclude project paths, service names, credentials, and one-off context. For a candidate review, report the candidates and their destinations, then stop. Apply changes only when the user asks. Confirm any change to the requested scope before editing.

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
