#!/usr/bin/env bash
# Render a usage guide HTML into a standalone HTML, a PDF, and review PNGs.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: render.sh <guide.html> <output-dir> <name>
  Writes <output-dir>/<name>.html (CSS and images inlined) and <output-dir>/<name>.pdf,
  then prints the page count, page size, embedded fonts, and a new review PNG directory.
env:
  GUIDE_FONT  variable font file to embed (default: first Pretendard variable font found)
  CHROME      Chrome or Chromium binary (default: auto-detect)
  REVIEW_DPI  review PNG resolution (default: 60)
EOF
  exit 2
}

fail() { echo "error: $*" >&2; exit 1; }

[[ $# -eq 3 ]] || usage
src="$1"
name="$3"
[[ -f "$src" ]] || fail "missing source: $src"
[[ "$name" != */* ]] || fail "name must be a file name without a directory: $name"
mkdir -p "$2"
out_dir="$(cd "$2" && pwd -P)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

for tool in python3 pdfinfo pdffonts pdftoppm; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing tool: $tool (poppler provides pdfinfo, pdffonts, pdftoppm)"
done

find_chrome() {
  local candidate
  for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
    [[ -x "$candidate" ]] && { echo "$candidate"; return; }
  done
  for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
    command -v "$candidate" >/dev/null 2>&1 && { command -v "$candidate"; return; }
  done
  return 0
}

find_font() {
  local dir found
  for dir in "$HOME/Library/Fonts" /Library/Fonts "$HOME/.local/share/fonts" "$HOME/.fonts" /usr/local/share/fonts /usr/share/fonts; do
    [[ -d "$dir" ]] || continue
    found="$(find "$dir" -maxdepth 3 -type f -iname '*pretendard*variable*' \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff2' \) 2>/dev/null | head -n 1 || true)"
    [[ -n "$found" ]] && { echo "$found"; return; }
  done
  return 0
}

chrome="${CHROME:-$(find_chrome)}"
[[ -n "$chrome" ]] || fail "Chrome or Chromium not found; set CHROME to its binary"
font="${GUIDE_FONT:-$(find_font)}"

work="$(mktemp -d "${TMPDIR:-/tmp}/usage-guide-print.XXXXXX")"
trap 'rm -rf "$work"' EXIT

html_out="$out_dir/$name.html"
pdf_out="$out_dir/$name.pdf"
print_copy="$work/print.html"

python3 -I "$script_dir/inline_assets.py" "$src" "$work/standalone.html"
if [[ -n "$font" ]]; then
  python3 -I "$script_dir/inline_assets.py" "$work/standalone.html" "$print_copy" --font "$font"
else
  echo "warning: no font file found; headless Chrome may fall back to another system font. Set GUIDE_FONT." >&2
  cp "$work/standalone.html" "$print_copy"
fi
cp "$work/standalone.html" "$html_out"

rm -f "$pdf_out"
print_url="$(python3 -I -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$print_copy")"
"$chrome" --headless=new --disable-gpu --no-sandbox --allow-file-access-from-files \
  --user-data-dir="$work/profile" --no-pdf-header-footer --run-all-compositor-stages-before-draw \
  --virtual-time-budget=8000 --print-to-pdf="$pdf_out" "$print_url" >/dev/null 2>&1 || true
[[ -s "$pdf_out" ]] || fail "Chrome did not write the PDF: $pdf_out"

review="$(mktemp -d "${TMPDIR:-/tmp}/usage-guide-review.XXXXXX")"
pdftoppm -png -r "${REVIEW_DPI:-60}" "$pdf_out" "$review/page"

echo "html: $html_out"
echo "pdf: $pdf_out"
pdfinfo "$pdf_out" | grep -E '^(Pages|Page size):'
echo "font file: ${font:-none}"
echo "embedded fonts:"
pdffonts "$pdf_out" | tail -n +3 | awk '{print $1}' | sed 's/^[A-Z]\{6\}+//' | sort | uniq -c | awk '{print "  " $2 " (" $1 ")"}'
echo "review: $review"
