# Codex verification policy

Read this reference only on Codex. The shared workflow owns routing, authorization, acceptance criteria, and deterministic verification; this file contains only Codex-specific model-generated review guidance.

## GPT-5.6 Sol

- Keep the prompt lean and do not add a generic self-review pass.
- Use targeted review only for a concrete diff risk or acceptance criterion that deterministic checks cannot decide.
- Change verification scaffolding one group at a time and keep it only when representative cross-host evaluations show a quality gain.

For other Codex models, use the shared risk-triggered review policy unless a measured model-specific regression justifies an override. Model and reasoning-effort selection belongs in Codex configuration, not in the shared skill.

Source: [OpenAI GPT-5.6 model guidance](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-5.6#prompting-best-practices).
