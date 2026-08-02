# Registry

TOML files provide machine-readable internal/external asset lists and source locks. `skills.toml` and `sources.lock` now register the product-development workflow and its reviewed optional providers. `tooling/scripts/check-sources.sh` uses the GitHub API to verify every source-relative path at its locked commit. The installer links the owned skill directly and does not automatically download external assets from this registry.

Entries should use stable IDs and record source, version or commit, license when applicable, supported hosts, profiles, and default activation. Store required environment-variable names instead of secret values.
