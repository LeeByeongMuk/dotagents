# Model-specific verification policy

Use this reference only for the exact active model named below. Deterministic project checks are common to every model. This policy governs only model-generated self-review and verifier delegation; it never replaces acceptance criteria, tests, static analysis, builds, schema checks, or observed user-flow evidence.

This policy starts after model selection. `model-fit.md` decides which candidate and effort fit the run; this file adjusts verification behavior for the exact active model. A Model Fit recommendation must not be presented as verification evidence.

## GPT-5.6 Sol

- Keep the prompt lean and do not add a generic self-review pass.
- Use targeted review only for a concrete diff risk or acceptance criterion that deterministic checks cannot decide.
- Change verification scaffolding one group at a time and keep it only when representative evaluations show a quality gain.

## Claude Opus 5

- Do not instruct a final self-review, re-check, or verifier subagent merely because the task is non-trivial.
- Rely on project checks and the common risk-triggered review rule. Use an independent opinion only when the product risk itself requires one, not to duplicate the model's normal self-correction.

## Claude Fable 5

- For short or routine work, use the common policy without extra verifier scaffolding.
- For long-running work, ground progress and completion claims in tool results from the run.
- Use a fresh-context verifier only at meaningful specification or risk checkpoints where independent review can change the outcome. Do not turn it into a generic self-critique loop.

## Re-evaluation

Recheck these overrides on every model upgrade. Compare the current and simplified harness on representative tasks, and remove an override when it no longer produces a measured benefit.

Sources: [OpenAI GPT-5.6 model guidance](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-5.6#prompting-best-practices), [Anthropic Claude Opus 5 prompting](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5), [Anthropic Claude Fable 5 prompting](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5).
