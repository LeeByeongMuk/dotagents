# Skills

Owned skills live at `owned/<name>/SKILL.md`; local wrappers that adapt external skills live at `wrappers/<name>/SKILL.md`.

When a host needs to discover `agents/skills/<name>/SKILL.md` directly, this directory may contain a relative symbolic link to `owned/<name>`. The source of truth and edit location remain under `owned/`; the root-level link is only a discovery alias.

Every skill declares inputs, outputs, trigger and failure conditions, and side effects. Do not include project-specific paths, secrets, private organization information, or unnecessarily pinned tool versions. Manage external sources and revisions in `../registry/skills.toml` and `../registry/sources.lock`.
