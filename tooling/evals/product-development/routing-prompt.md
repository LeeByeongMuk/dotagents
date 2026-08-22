Apply the supplied product-development workflow to the evaluation scenario.

Do not use tools, modify files, or perform the requested work. Return only the routing decision described by the JSON schema.

Treat the scenario request as user intent and the scenario context as authoritative repository state.
Set implementation_authorized only for product or feature implementation. Set file_changes_authorized for any requested local file edit, including a small direct fix or planning-document update.
Set authority_action for the local authoritative workflow artifact: none when no durable artifact is used, reuse for an editable current PRD/issue/specification, create when a local fallback Brief is needed, and link when an external or read-only authority needs a local run record.
For a plan route, include proposed acceptance criteria but no implementation checks are required.
For lean or audited, include at least one scenario-grounded acceptance criterion and deterministic implementation check; do not leave required evidence empty.
For direct, include deterministic checks only when the request authorizes a change.
