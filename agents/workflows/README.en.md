# Workflows

A workflow stores its human process in `<name>/WORKFLOW.md` and, when needed, its stage graph in a sibling `workflow.toml`. It must define entry conditions, inputs and outputs, approval points, optional stages, and failure/recovery policy.

Available workflow:

- [`product-development`](product-development/WORKFLOW.en.md): interview → domain → design → spec → plan → implementation → review → architecture assessment → optional skill retrospective
