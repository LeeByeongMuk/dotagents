#!/usr/bin/env bash
# One four-scenario batch; prepare-only unless --execute is explicitly passed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
fail() { echo "error: $*" >&2; exit 1; }
sha256_file() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
usage() {
  echo 'Usage: run.sh --label baseline|candidate --output-dir NEW_ABSOLUTE_DIR [--baseline-ref REF] [--project-ref REF] [--environment-ref REF] [--execute]'
  echo 'Default: prepare immutable inputs only. --execute consumes one gpt-6.1-sol/high batch.'
}
label='' output_dir='' execute=0
baseline_ref=3b6145f project_ref=f1ce976 environment_ref=3f48093
while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) execute=1; shift ;;
    --label|--output-dir|--baseline-ref|--project-ref|--environment-ref)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      case "$1" in
        --label) label="$2" ;; --output-dir) output_dir="$2" ;;
        --baseline-ref) baseline_ref="$2" ;; --project-ref) project_ref="$2" ;; --environment-ref) environment_ref="$2" ;;
      esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done
[[ "$label" == baseline || "$label" == candidate ]] || fail 'choose --label baseline|candidate'
[[ "$output_dir" == /* && "$output_dir" != / ]] || fail 'choose a new absolute output directory outside repositories'
[[ ! -e "$output_dir" && ! -L "$output_dir" ]] || fail 'output already exists; never overwrite evaluation evidence'
parent_dir="$(cd "$(dirname "$output_dir")" && pwd -P)"
if git -C "$parent_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail 'write eval output outside repositories'
fi
output_dir="$parent_dir/$(basename "$output_dir")"
command -v jq >/dev/null || fail 'jq is required'
baseline_revision="$(git -C "$REPO_ROOT" rev-parse --verify --end-of-options "$baseline_ref^{commit}")"
project_revision="$(git -C "$REPO_ROOT" rev-parse --verify --end-of-options "$project_ref^{commit}")"
environment_revision="$(git -C "$REPO_ROOT" rev-parse --verify --end-of-options "$environment_ref^{commit}")"
mkdir "$output_dir"
mkdir "$output_dir/inputs"
for file in cases.json decision.schema.json prompt.md grade.jq; do cp "$SCRIPT_DIR/$file" "$output_dir/inputs/$file"; done
git -C "$REPO_ROOT" show "$baseline_revision:README.md" > "$output_dir/inputs/base-readme.md"
git -C "$REPO_ROOT" show "$baseline_revision:agents/skills/owned/product-development-workflow/SKILL.md" > "$output_dir/inputs/workflow.md"
git -C "$REPO_ROOT" show "$baseline_revision:agents/skills/owned/product-development-workflow/references/codex-cli.md" > "$output_dir/inputs/host.md"
for name in workflow coding git documentation security; do
  git -C "$REPO_ROOT" show "$baseline_revision:agents/rules/$name.md"
done > "$output_dir/inputs/rules.md"
if [[ "$label" == candidate ]]; then
  git -C "$REPO_ROOT" show "$project_revision:docs/project-readiness.md" > "$output_dir/inputs/project.md"
  git -C "$REPO_ROOT" show "$environment_revision:environment/README.md" > "$output_dir/inputs/environment.md"
  git -C "$REPO_ROOT" show "$environment_revision:docs/designs/environment-profile.md" > "$output_dir/inputs/deployment.md"
fi
# Expected judgments are private grader inputs, never part of the model prompt.
jq 'map({id, context, request})' "$output_dir/inputs/cases.json" > "$output_dir/inputs/scenarios.json"
{
  cat "$output_dir/inputs/prompt.md"
  for name in rules workflow host base-readme project environment deployment; do
    if [[ -f "$output_dir/inputs/$name.md" ]]; then
      printf '\n--- SOURCE: %s.md ---\n' "$name"
      cat "$output_dir/inputs/$name.md"
    fi
  done
  printf '\n--- SCENARIOS ---\n'
  cat "$output_dir/inputs/scenarios.json"
} > "$output_dir/inputs/model-prompt.md"
hashes='{}'
for input in "$output_dir"/inputs/*; do
  hashes="$(jq -c --arg name "$(basename "$input")" --arg hash "$(sha256_file "$input")" '. + {($name): $hash}' <<< "$hashes")"
done
jq -n --arg label "$label" --arg baseline "$baseline_revision" --arg project "$project_revision" \
  --arg environment "$environment_revision" --argjson files "$hashes" \
  '{label: $label, requested_model: "gpt-6.1-sol", requested_effort: "high",
    source_revisions: {baseline: $baseline, project: $project, environment: $environment}, files: $files}' > "$output_dir/manifest.json"
if [[ "$execute" -eq 0 ]]; then echo "Prepared inputs only: $output_dir"; exit 0; fi
command -v codex >/dev/null || fail 'codex CLI is not installed; prepared evidence retained'
codex --version > "$output_dir/cli-version.txt"
args=(exec --ephemeral --ignore-user-config --ignore-rules --strict-config
  --disable image_generation --disable shell_tool --disable unified_exec --disable view_image
  --skip-git-repo-check --cd "$output_dir" --sandbox read-only --model gpt-6.1-sol
  --config 'agents.enabled=false' --config 'apps._default.enabled=false'
  --config 'model_reasoning_effort="high"' --config 'web_search="disabled"' --config 'project_doc_max_bytes=0'
  --output-schema "$output_dir/inputs/decision.schema.json" --output-last-message "$output_dir/decision.json" --json -)
printf '%s\n' "${args[@]}" | jq -Rs 'split("\n")[:-1]' > "$output_dir/cli-arguments.json"
started="$(date +%s)"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$output_dir/started-at.txt"
status=0
codex "${args[@]}" < "$output_dir/inputs/model-prompt.md" > "$output_dir/events.jsonl" 2> "$output_dir/stderr.txt" || status=$?
printf '%s\n' "$status" > "$output_dir/cli-exit.txt"
[[ "$status" -eq 0 ]] || fail "model call failed with exit $status; evidence retained in $output_dir"
elapsed="$(( $(date +%s) - started ))"
jq -n --slurpfile manifest "$output_dir/manifest.json" --slurpfile decision "$output_dir/decision.json" \
  --slurpfile events "$output_dir/events.jsonl" --argjson elapsed "$elapsed" \
  '$manifest[0] + {decision: $decision[0],
    telemetry: {host_elapsed_seconds: $elapsed,
      usage: ([$events[] | select(.usage? != null) | .usage] | last // null),
      observed_model_fields: ([$events[] | .. | objects | .model? // empty] | unique),
      observed_effort_fields: ([$events[] | .. | objects | (.reasoning_effort? // .model_reasoning_effort?) // empty] | unique),
      item_types: ([$events[] | .item.type? // empty] | unique)}}' > "$output_dir/result.json"
"$SCRIPT_DIR/score.sh" "$output_dir"
