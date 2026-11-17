#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fail() { echo "error: $*" >&2; exit 1; }
sha256_file() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
[[ $# -eq 1 && -d "$1" ]] || fail 'Usage: score.sh OUTPUT_DIR'
input_dir="$1"
for file in cases.json decision.schema.json prompt.md grade.jq; do
  [[ "$(sha256_file "$SCRIPT_DIR/$file")" == "$(jq -r --arg name "$file" '.files[$name]' "$input_dir/result.json")" ]] || fail 'result uses a different evaluation contract'
done
while IFS=$'\t' read -r name expected; do
  [[ "$name" =~ ^[a-zA-Z0-9.-]+$ ]] || fail 'unsafe input name'
  [[ "$(sha256_file "$input_dir/inputs/$name")" == "$expected" ]] || fail "snapshot changed: $name"
done < <(jq -r '.files | to_entries[] | [.key, .value] | @tsv' "$input_dir/result.json")
jq --slurpfile cases "$input_dir/inputs/cases.json" --slurpfile schema "$input_dir/inputs/decision.schema.json" \
  -f "$SCRIPT_DIR/grade.jq" "$input_dir/result.json" > "$input_dir/score.json"
cat "$input_dir/score.json"
jq -e '.passed' "$input_dir/score.json" >/dev/null
