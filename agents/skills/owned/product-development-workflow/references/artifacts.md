# Audited artifact contract

Read this reference only after the workflow has selected the audited path. Write every audited artifact as a Korean `.md` file. The CLI checks only safe file structure and state; the agent and user own content review.

## Common required sections

Every stage artifact must contain:

1. Title and run ID
2. Content status: `DRAFT` while editing, then `FINAL` before requesting approval
3. Purpose
4. Inputs: approved artifacts and repository evidence used
5. Findings or result
6. Decisions: choice, owner, and rationale
7. Open questions or `None`
8. Next-stage handoff

`FINAL` means the content is frozen for review; it does not mean the user approved it. The workflow state is the authority for approval. After `approve` succeeds, do not edit the file: the CLI stores its SHA-256 hash and rejects later changes during `status`, subsequent approval, and `verify`. Record corrections in the next stage as a new decision, or start/adopt a replacement run when an already-approved artifact itself must change.

## Stage-specific content

### 01-interview

- Target user and painful moment
- Current workaround or status quo
- Desired outcome and success signal
- Evidence and assumptions
- Constraints and non-goals
- Interview questions and summarized answers

### 02-domain

- Actors and goals
- Ubiquitous language glossary
- Entities and value objects where needed
- Commands, events, policies, and invariants
- Context/system boundaries
- Unknowns and non-goals

### 03-design

- Problem statement
- Constraints and premises
- At least two approaches with tradeoffs
- Recommended and selected approach
- Success criteria
- Dependencies and distribution

### 04-spec

- Goals and non-goals
- User stories or jobs
- Functional and failure behavior
- Observable acceptance criteria
- Constraints and dependencies
- Open questions

### 05-plan

- Exact files or discovery tasks
- Small ordered implementation tasks
- Test-first or regression-test steps
- Exact commands and expected results
- Documentation, migration, rollback, and distribution tasks when applicable

### 06-plan-review

- Review dimensions and providers used
- Findings with severity and disposition
- Changes made to the plan
- Accepted, rejected, and deferred recommendations
- Unresolved blockers; approval requires none
- Final implementation task order

### 07-implementation

- Approved spec, plan, and plan-review inputs
- Task ledger and subagents used, or `None`
- Changed files and commits
- Commands with exit codes and meaningful results
- Plan deviations and rationale
- Updated living context documents or `None affected`
- Remaining failures or `None`

### 08-review

- Diff range and review providers
- Findings and fixes
- Static, test, build, and QA commands with exit codes
- Critical user flows exercised and results
- Remaining failures and risk acceptance

### 09-architecture

- Assessment before changes
- Evidence for each proposed change
- User authorization decision
- Changed files or explicit `No architecture change`
- Full relevant stage 8 command rerun with exit codes
- Remaining architecture debt or `None`

### 10-skill-retro

- Repeated successful and failed procedures
- Candidate skill trigger, inputs, outputs, and guardrails
- Portability and project-specific boundaries
- Forward-test scenarios
- Recommendation: create, revise, wait for more evidence, or no skill
- Separate write authorization status

## Approval checklist

Before requesting approval, verify:

- The file exists, is a non-empty regular file, and is not a symlink.
- The file lives directly in `docs/workflows/<run-id>/`.
- Required common and stage-specific sections are present.
- Facts are sourced from the repository or authoritative documentation where possible.
- Product decisions are explicit rather than inferred.
- Stages 7–9 include real command results, not commands that were merely planned.
