# dotagents

[한국어](README.md)

dotagents is the single source of truth for a personal AI development operating system shared across Claude Code, Codex, and Gemini. It manages common rules, workflows, owned skills, prompts, hooks, external-integration contracts, and host adapters in one repository for reuse across projects.

The repository now provides both its structure/installation foundation and the ten-stage product-development workflow defined in the original image. Host hook installation, MCP configuration generation, automatic external-skill synchronization, and profile composition remain future work.

## Principles and precedence

Precedence is **project-specific rules → host-specific configuration → personal shared defaults**. Shared settings do not replace a project's framework, package manager, tests, or branch policy.

- `agents/` is the single source of truth for all human-edited AI assets.
- `tooling/` handles installation, generation, updates, diagnostics, and verification.
- `docs/` stores explanations and decisions too long for the root README.
- `dist/` is reserved for generated host-specific final outputs.
- Behavior and explanation use Markdown; machine-readable lists, versions, and profiles use TOML.
- Secrets and local session state never belong in the repository.

## Repository layout

The root stays small and exposes only sources, management tools, documentation, and generated output.

```text
.
├── AGENTS.md
├── README.md
├── README.en.md
├── dotagents.toml
├── agents/
│   ├── rules/                     # behavior, coding, Git, security
│   ├── routing/                   # request-to-workflow/skill rules
│   ├── workflows/                 # composed procedures and contracts
│   ├── skills/
│   │   ├── owned/                 # authored skills, including the workflow orchestrator
│   │   └── wrappers/              # local adaptation of external skills
│   ├── prompts/
│   ├── hooks/
│   ├── profiles/
│   ├── integrations/
│   │   ├── skills/
│   │   ├── mcp/
│   │   ├── plugins/
│   │   └── tools/
│   ├── adapters/
│   │   ├── claude/
│   │   ├── codex/
│   │   └── gemini/
│   ├── registry/                  # asset lists and reviewed source locks
│   └── templates/
├── tooling/
│   ├── scripts/
│   ├── schemas/
│   └── tests/
├── docs/
│   ├── decisions/
│   └── designs/
└── dist/
```

Add a schema under `tooling/schemas/` together with the first consumer. Do not freeze a format without an executable consumer.

## Area contracts

### Rules, routing, and workflows

- Keep shared rules as small independent files in `agents/rules/<topic>.md`.
- Routing chooses a workflow or one skill based on request type and size.
- A workflow may combine human instructions in `agents/workflows/<name>/WORKFLOW.md` with a machine contract in `workflow.toml`.
- Workflows declare entry conditions, stages, input/output artifacts, user approval points, failure/recovery behavior, and optional stages.

Do not force the full process onto a trivial edit. A typo may need only implementation and verification; a bug needs investigation and a regression test; a substantial feature can run from problem definition through plan, implementation, QA, and retrospective.

### Skills and prompts

- Owned skills live at `agents/skills/owned/<name>/SKILL.md`.
- Wrappers that adapt an external skill without modifying it live at `agents/skills/wrappers/<name>/SKILL.md`.
- Do not copy external sources wholesale. Record source and reviewed revision in `agents/registry/skills.toml` and `sources.lock`.
- Prompts declare purpose, input, output, applicability, and safety limits.

### Hooks

Hooks handle lifecycle operations such as session start, before/after tool use, pre-commit, pre-ship, and context recovery. Each hook declares its trigger, supported hosts, side effects, and failure policy and is registered in `agents/registry/hooks.toml`.

Hooks can execute local commands and therefore cross a trust boundary. Never auto-enable an unreviewed external hook.

### Integrations and registry

`agents/integrations/` stores installation methods, configuration templates, health checks, host differences, and local wrappers rather than complete external copies.

- `skills.toml`: owned/external skill IDs, sources, hosts, profiles, and workflow stages
- `mcp.toml`: purpose, transport, required environment-variable names, permissions, and health checks
- `hooks.toml`: events, commands, hosts, and default enablement
- `plugins.toml`: sources, versions, and installation targets
- `sources.lock`: reviewed tags or commits

Never put API keys, tokens, cookies, or endpoint credentials in the registry. Record only required variable names such as `GITHUB_TOKEN`.

### Profiles, adapters, and dist

Profiles combine rules, skills, hooks, and integrations for project types such as `minimal`, `default`, `full`, or `nextjs`. A project selects a profile and overrides only its local differences.

Adapters connect common sources to Claude Code, Codex, and Gemini entry formats. The current installer links thin adapters directly. A future generator can combine `profile + project override + adapter` into reviewed output under `dist/`.

```text
agents/ sources
  + profile
  + project override
  + host adapter
        |
        +--> dist/claude
        +--> dist/codex
        +--> dist/gemini
```

Never edit generated `dist/` files directly; change the source and regenerate.

## Current capabilities and future work

The repository currently provides:

- Shared rules and thin host adapters
- Generic and Next.js project templates
- Safe global/project symbolic-link installation and removal
- Collision detection, forced-install backups, and uninstall restoration
- Repair after repository moves or internal path changes
- Structure, secret-pattern, shell-syntax, installation, and workflow tests
- A ten-stage product-development workflow from interview through architecture assessment
- Bilingual per-stage artifacts, explicit user approval, resumption, and existing-document adoption
- Shared skill discovery and a global/project CLI across Claude Code, Codex, and Gemini
- Owned/external skill registry entries and reviewed source commit locks

The following remains structural or not yet automated:

- External skill/plugin download and version updates
- MCP configuration generation and health checks
- Host-specific hook installation and execution
- Profile composition and `dist/` generation
- General skill-routing evaluation beyond the owned workflow description

## Install

Clone the repository where you want it and inspect a dry run first.

```bash
cd /path/to/dotagents
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global
```

Global mode creates:

- `~/.agents` → this repository's `agents/`
- `~/.claude/CLAUDE.md` → `agents/adapters/claude/CLAUDE.md`
- `~/.claude/skills/product-development-workflow` → the owned workflow skill
- `~/.codex/AGENTS.md` → `agents/adapters/codex/AGENTS.md`
- `~/.gemini/GEMINI.md` → `agents/adapters/gemini/GEMINI.md`
- `~/.local/bin/dotagents-workflow` → the workflow state command

Codex and Gemini discover the same owned skill through `~/.agents/skills/product-development-workflow`. The installer warns when `~/.local/bin` is not on `PATH`; the full command path still works.

Existing targets are reported as conflicts, and the default run changes nothing. `--force` first backs up an existing item to a timestamped sibling. Do not use `--force` before reviewing the current configuration.

```bash
./tooling/scripts/install.sh --dry-run --global --force
```

### Apply to one project

```bash
./tooling/scripts/install.sh --dry-run --project /path/to/project
./tooling/scripts/install.sh --project /path/to/project
```

Project mode installs `.agents`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude/skills/product-development-workflow`, and `.dotagents/bin/dotagents-workflow`. Codex and Gemini use the project `.agents/skills` alias. Existing project files stop installation; either reference common rules manually or use `--force` only after review.

To create project-local rules, copy a template and adapt it:

```bash
cp agents/templates/generic/AGENTS.md /path/to/project/AGENTS.md
# or
cp agents/templates/nextjs/AGENTS.md /path/to/project/AGENTS.md
```

The Next.js template does not assume technology choices. Consult `agents/templates/nextjs/fsd-optional.md` only when the project has actually chosen FSD.

## Use the product-development workflow

In a supported host, ask:

```text
Use $product-development-workflow to take this idea from interview through implementation review.
```

The workflow skips small known edits. For `standard` or `substantial` product work it runs:

```text
interview → domain → office hours → light spec → plan
→ plan review → implementation → code/test review → architecture assessment
→ skill-refactoring candidate (optional)
```

You can also start and inspect state directly:

```bash
dotagents-workflow start --project /path/to/project --run feature-name --scope substantial
dotagents-workflow status --project /path/to/project --run feature-name
```

Artifacts are stored as Korean `.md` and English `.en.md` pairs under `<project>/docs/workflows/<run-id>/`. The agent presents each pair and advances only after explicit user approval. The state pins each approved file's SHA-256, so later changes fail `status` and completion verification. See the [product-development workflow guide](agents/workflows/product-development/WORKFLOW.en.md) for adopting existing specs/plans, skipping stage 10, recovery, and completion verification.

## Uninstall

Uninstall removes only links recorded in the installation manifest that still point to the same source. Backups created by `--force` are restored when the target is empty. User-replaced links or files are preserved.

```bash
./tooling/scripts/uninstall.sh --dry-run --global
./tooling/scripts/uninstall.sh --global

./tooling/scripts/uninstall.sh --dry-run --project /path/to/project
./tooling/scripts/uninstall.sh --project /path/to/project
```

The global manifest lives at `${XDG_STATE_HOME:-$HOME/.local/state}/dotagents/install.tsv`; project mode uses `<project>/.dotagents-install.tsv`.

## Verify

```bash
bash -n tooling/scripts/install.sh
bash -n tooling/scripts/uninstall.sh
bash -n tooling/scripts/check.sh
bash -n tooling/scripts/workflow.sh
./tooling/scripts/install.sh --dry-run
./tooling/scripts/uninstall.sh --dry-run
./tooling/scripts/check.sh
./tooling/scripts/check-sources.sh
./tooling/tests/install_test.sh
./tooling/tests/structure_test.sh
./tooling/tests/workflow_test.sh
./tooling/tests/sources_test.sh
```

`check.sh` verifies required structure, Korean-English README pairs, skill format, broken links, shell syntax, hardcoded repository paths, suspicious secret patterns/names, thin adapters, registry basics, the workflow contract, and installation dry-run. `check-sources.sh` is a separate network check and requires authenticated GitHub CLI access. Neither command prints detected secret values.

## Add assets

- Shared rule: `agents/rules/<topic>.md`
- Workflow: `agents/workflows/<name>/WORKFLOW.md`, `WORKFLOW.en.md`, `workflow.toml`
- Owned skill: `agents/skills/owned/<name>/SKILL.md`
- External wrapper: `agents/skills/wrappers/<name>/SKILL.md`
- Prompt: `agents/prompts/<name>.md`
- Hook: `agents/hooks/<name>/`
- External integration: `agents/integrations/<kind>/<name>/`
- Host behavior: `agents/adapters/<host>/`
- Project template: `agents/templates/<profile>/`

When adding human-facing Korean documentation, add a sibling `<name>.en.md`. The English sibling for `README.md` is `README.en.md`. Keep executable contracts such as `SKILL.md`, `AGENTS.md`, and TOML single-source to prevent semantic divergence.

New assets must not contain project-specific paths, secrets, private organization information, or unnecessarily fixed tool versions.

## Secrets

Do not commit API keys, tokens, cookies, sessions, private keys, real MCP credentials, or private organization information. Example files must use placeholders such as `OPENAI_API_KEY=<your-api-key>`. `.gitignore` and `check.sh` reduce mistakes but do not replace reviewing the diff before commit.

## Restore on a new computer

```bash
git clone <your-dotagents-repository-url> ~/Documents/GitHub/dotagents
cd ~/Documents/GitHub/dotagents
./tooling/scripts/check.sh
./tooling/scripts/install.sh --dry-run --global
./tooling/scripts/install.sh --global
```

Absolute symlinks may still point at an old clone after a repository move or internal adapter change. Rerunning the same install command from the new clone repairs manifest-owned links and does not automatically change unrelated files.

## Known limitations

- Hosts include Markdown files differently. Thin adapters tell the agent where common rules live; some agents may need an explicit instruction to read them.
- Existing configuration files are not structurally merged. Installation either stops on conflict or uses an explicit `--force` backup.
- Windows is not supported.
- Configuration examples are not installed automatically. Review and merge real settings and secrets yourself.
- The skill registry is a reviewed list/lock, not an external-asset installer. Profiles, hooks, MCP, and `dist/` are not yet composed by the installer.

## License

MIT License. See `LICENSE`.
