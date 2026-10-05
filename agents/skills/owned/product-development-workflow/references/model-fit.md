# Model Fit policy

Use this reference after the Brief is current and before Execute, only when the user explicitly asks to choose or compare models. Model Fit recommends the primary model and effort for this run. It does not replace product routing, grant permission for external calls, or change the model by itself.

## Keep the assessment bounded

- Use the primary agent to assess fit. Do not call every candidate, ask each model to nominate itself, or create a fixed cross-provider debate.
- Treat a user-pinned model as a selection constraint, not permission to override authorization, availability, security, data policy, required tool or modality, context, or budget ceilings. Validate those non-negotiable constraints before skipping comparison; if the pinned model conflicts, do not execute it, record the hard-filter reason, and stop for user direction.
- Skip current-run selection when the user pinned an exact model or project policy already fixes the model and that model passes every non-negotiable constraint. Record the reason and continue on that model.
- When only one candidate is runnable and no comparison candidate was explicitly supplied, keep it as Primary, record that current-run selection was skipped, and continue. If the user explicitly supplied a non-runnable candidate for comparison, it may appear only as a next-run recommendation; the sole runnable candidate remains Primary for this run.
- Run it once after material task facts are known. Re-run only when the Brief, hard constraints, candidate inventory, or representative eval evidence changes enough to alter the result.
- Prefer staying in the current context. Recommend a switch only when the expected benefit is material enough to repay context transfer and re-verification.

## Build the candidate inventory

Consider candidates the host reports as runnable or the user explicitly supplies for comparison. A supplied non-runnable candidate may inform a next-run recommendation, but it fails the current-run availability filter and cannot be selected for immediate execution. Represent Claude, Codex, and future local models with the same fields:

| Field | Required meaning |
|---|---|
| `provider` | Provider or runtime, such as `anthropic`, `openai`, or a future local runtime |
| `model` | Exact host-visible model ID or alias; never infer a candidate from a family name |
| `runnable` | Whether this host can select it now without changing authentication or policy |
| `source` | Current official documentation, host inventory, or project eval that established its metadata |
| `source_checked_at` | Date the external or host metadata was checked |
| `role` | Provider-documented or eval-supported role such as capability-first, balanced, efficient, or specialized |
| `effort_modes` | Host-supported effort values and default, or `unknown` |
| `requirements` | Context, modalities, tools, sandbox, data boundary, and other hard capabilities |
| `economics` | Relative latency and cost class; exact prices stay in the current source instead of this repository |
| `eval_evidence` | Relevant project eval, workload, model version, date, quality result, latency, and cost when available |

Do not guess missing metadata from a model name. Verify time-sensitive roles, availability, effort support, and economics against current official provider documentation. Treat account access and host model lists as local facts that official catalog pages cannot prove.

## Describe the task shape

Assess the current Brief and repository on these dimensions without turning them into a numeric score:

- **Capability pressure:** unresolved product judgment, novel architecture, ambiguous requirements, cross-cutting invariants, deep analysis, visual judgment, or weak deterministic checks.
- **Horizon and autonomy:** expected run length, number of dependent tool steps, recovery needs, and how much state must remain coherent.
- **Failure impact:** security, privacy, money, irreversible data, public API compatibility, or expensive rollback.
- **Tool and context fit:** required modalities, computer use, provider skills, context volume, sandbox behavior, and output limits.
- **Efficiency pressure:** latency target, budget, expected volume, and whether the work is repetitive or mechanically specified.
- **Continuity cost:** how much Brief, repository, tool state, and reasoning would need to be transferred and re-verified after a switch.

## Decide in evidence order

1. **Apply hard filters.** Remove candidates that cannot satisfy availability, authorization, data policy, required tools or modalities, context, budget ceilings, or a user-pinned constraint.
2. **Protect task success.** For high capability pressure, long horizons, or high failure impact, prefer the strongest remaining candidate supported by current documentation or representative evals. Do not trade a known acceptance failure for lower cost.
3. **Prefer project evidence.** A representative eval on the current model version and real project prompt outranks provider positioning. Compare acceptance success, edge cases, tool completion, latency, and cost. An eval from another workload is weak evidence.
4. **Tune before switching when appropriate.** If the active model family supports effort controls and the gap is marginal, prefer an evidence-backed effort change over a provider or model handoff.
5. **Charge for continuity.** Keep the active model when candidates are close, evidence is weak, or a switch would discard useful context. A different candidate must materially improve a hard requirement, demonstrated success rate, high-impact capability fit, or a user-stated cost or latency objective.
6. **Use efficiency only after the quality bar.** For well-specified, reversible, high-volume work with strong deterministic checks, prefer the lowest-cost or lowest-latency candidate that has evidence of meeting the acceptance bar.

Never combine uncertain inputs into a precise weighted score. If two candidates remain close, say so and stay with the active model.

## Choose effort and optional second-model use

- Preserve the host default effort unless current official guidance or project evals justify another supported value.
- Use higher effort for measured gains on demanding work, not as a substitute for a more suitable model, clearer Brief, or missing deterministic checks.
- Use lower effort when representative evals retain the acceptance bar and latency or cost matters.
- Do not add a second model by default. An advisor or fresh-context verifier is justified only for a concrete high-risk decision where independence can change the outcome, or for an explicitly authorized representative benchmark.
- Starting a paid benchmark, another provider process, or a new remote session requires the same authority as any other external or costly action.

## Produce and record the result

Write a concise result in the adopted authority's run record or the local Brief execution checkpoint:

```markdown
### Model Fit

- Decision: `stay | switch | recommendation-only | blocked`
- Primary: `<provider>/<exact-model>` or `None` when every allowed candidate is filtered
- Next-run recommendation: `None` or `<provider>/<exact-model>: <reason>`
- Effort: `<supported value | host default | unknown>`
- Optional secondary: `None` or `<provider>/<model>: <bounded role>`
- Confidence: `high | medium | low`
- Hard filters: <removed candidates and exact reasons, or None>
- Evidence: <project evals, current official sources, and observed task facts>
- Tradeoff: <why this candidate beats the strongest alternative after continuity cost>
- Execution: `<applied by host | current run continues on active model | next-run recommendation | blocked pending user direction>`
- Re-evaluate when: <specific Brief, inventory, model-version, or eval change>
```

Use `high` confidence only when hard constraints or current representative evals decide the result. Use `medium` for current official role guidance plus a clear task fit. Use `low` when metadata or workload evidence is incomplete; low confidence cannot justify an automatic cross-provider switch.

Use `stay` when the active model remains Primary, `switch` only when the host actually applies an authorized current-run change, `recommendation-only` when a different candidate is advice for a later run rather than an executed change, and `blocked` when no candidate can execute without violating a hard constraint or an unresolved pinned-model conflict.

If the recommended model is not the active model, separate the recommendation from execution:

- Apply it only when the host supports an in-scope model selection without losing required state and current authority permits the action.
- Otherwise continue with the active model when it can still meet the acceptance criteria, record `recommendation-only`, and preserve the recommendation for the next run.
- Stop for user direction only when the active model cannot meet a hard constraint or the user explicitly required the recommended model to execute this run.

## Provider coverage and extension

Initial policy coverage is Claude and Codex/OpenAI model families. The comparison contract remains provider-neutral: a local candidate may participate later when its runtime supplies the same inventory fields, respects project data and tool constraints, and has representative eval evidence. Being local, private, or cheap is not by itself evidence that it meets the quality bar.

Current provider selection guidance: [OpenAI Models](https://developers.openai.com/api/docs/models), [Anthropic Choosing the right model](https://platform.claude.com/docs/en/about-claude/models/choosing-a-model). Recheck both pages and representative project evals when model families change.
