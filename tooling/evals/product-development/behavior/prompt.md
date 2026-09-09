Apply the supplied product-development workflow and the active host reference to the evaluation scenario.

Do not use tools, modify files, or perform the requested work. Return only the execution decision described by the JSON schema: how you would actually run this task on the active host with the active model.

Treat the scenario context as authoritative repository state and the scenario request as user intent.
Set authority_action to reuse when the existing product document stays the Brief, create when a local fallback Brief is needed, link when an external or read-only authority needs a local run record, and none otherwise.
Set pre_execution_pause to true only when you would wait for a user answer before starting Execute.
List every subagent you would start, with its purpose and whether the primary agent blocks on it. An empty array means the primary agent does all the work.
Set model_generated_review to the review you would add on top of the project's deterministic checks: none, targeted-primary for a targeted review by the primary agent, fresh-context-verifier for one independent verifier at a checkpoint, or multiple for more than one model-generated review pass.
List the deterministic checks you would run, grounded in the scenario.
