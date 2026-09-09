# Claude Code verification policy

Read this reference only on Claude Code. The shared workflow owns routing, authorization, acceptance criteria, and deterministic verification; this file contains only Claude-specific thinking, review, and delegation guidance.

This policy starts after model selection. `model-fit.md` decides which candidate and effort fit the run. A Model Fit recommendation must not be presented as verification evidence.

## Claude Opus 5

- Do not add a final self-review, re-check, or verifier subagent merely because the task is non-trivial.
- Use an independent opinion only when product risk requires one, not to duplicate the model's normal verification.

## Claude Fable 5 and 5.1

- For short or routine work, use the shared policy without extra verifier scaffolding.
- For long-running work, ground progress and completion claims in tool results.
- Use a fresh-context verifier only at a meaningful specification or risk checkpoint where independent review can change the outcome.

When delegating to Claude Code's built-in Explore or Plan subagent, include every task-specific constraint it needs in the delegation message because those built-ins may omit `CLAUDE.md` and Git status. Effort and thinking configuration belongs in Claude settings or invocation options, not in the shared skill.

Sources: [Claude prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices), [Claude Code subagents](https://code.claude.com/docs/en/sub-agents).
