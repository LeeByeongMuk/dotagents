---
name: dotagents-promote
description: Promote project-transcending conventions, rules, or template material from the current session into the shared dotagents repository. Use when the user asks to reflect a learned convention into dotagents or accepts a promotion candidate proposed in a workflow completion report. Stages changes on an isolated git worktree branch, never on the live main checkout, and never as a background side effect of another task.
---

# Dotagents Promote

Move durable, project-agnostic learnings into the dotagents single source deliberately. Invoking this skill authorizes edits and commits on an isolated promotion branch only. Merging into `main` remains a separate user decision.

## Collect and classify candidates

1. Start from the candidates the user named or accepted from a completion report. Otherwise review the current session for durable, project-agnostic learnings: corrected agent behavior, repeated conventions, reusable structures.
2. Assign each candidate one destination:
   - `agents/rules/<topic>.md`: meta-rules that hold in every project regardless of stack.
   - `agents/templates/<profile>/`: stack- or domain-specific conventions.
   - `agents/skills/owned/<name>/`: repeatable multi-step procedures.
   - Reject: anything tied to one project belongs in that project's `AGENTS.md`, not in dotagents.
3. Reject candidates that contain project paths, service names, credentials, or one-off context. When the final list differs from what the user asked for, confirm it before editing.

## Apply on an isolated worktree

1. Resolve the dotagents repository root from the `~/.agents` symlink target's parent directory. Abort when the symlink or the repository is missing.
2. Never edit the primary checkout. The symlink serves the live configuration for every project, so the primary checkout must stay on a clean `main`.
3. Create a worktree: `git -C <repo> worktree add <scratch>/promote-<slug> -b promote/<slug> main`.
4. Edit inside the worktree only. Follow the repository's conventions: Korean human-readable docs, the existing rule and template styles, and no rule text duplicated into adapters.
5. When a change adds required files or edits contract lines, update `tooling/scripts/check.sh` and the `tooling/tests/` assertions in the same branch.

## Verify and hand off

1. Run `./tooling/scripts/check.sh` inside the worktree. It must pass before committing.
2. Commit on the promotion branch with a message that names the promoted convention. Do not merge into `main` and do not push.
3. Report the branch name, worktree path, and a diff summary. Merging is the user's approval act. After merge or rejection, remove the worktree with `git worktree remove`.

## Safety

- Never run this skill as a hook or as a side effect of another task.
- Never leave the primary checkout dirty, detached, or off `main`.
- Never promote secrets, private organization details, or project-identifying content.
