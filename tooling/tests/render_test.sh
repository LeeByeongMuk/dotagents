#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotagents-render-test.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
trap 'rm -r "$TEST_ROOT"' EXIT

fail() { echo "test failed: $*" >&2; exit 1; }

bin="$TEST_ROOT/stub tools"
out_dir="$TEST_ROOT/output with spaces"
tmp_dir="$TEST_ROOT/temporary files"
mkdir -p "$bin" "$out_dir" "$tmp_dir"
source_html="$TEST_ROOT/source guide.html"
printf '%s\n' '<html><head></head><body>new guide</body></html>' > "$source_html"
printf '%s\n' 'test font' > "$TEST_ROOT/test font.woff2"
printf 'old HTML\nunchanged\n' > "$TEST_ROOT/old.html"
printf 'old PDF\nunchanged\n' > "$TEST_ROOT/old.pdf"
real_mv="$(command -v mv)"

cat > "$bin/stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
tool="${0##*/}"
printf '%s\n' "$tool" >> "$STUB_LOG"
case "$tool" in
  'chrome stub')
    pdf=""
    for arg in "$@"; do
      case "$arg" in --print-to-pdf=*) pdf="${arg#--print-to-pdf=}" ;; esac
    done
    [[ "$pdf" == "$RENDER_OUT_DIR"/.usage-guide-print.*/guide.pdf ]] || exit 90
    case "$STUB_FAILURE" in
      missing_pdf) exit 0 ;;
      empty_pdf) : > "$pdf"; exit 0 ;;
    esac
    printf '%s\n' 'new PDF' > "$pdf"
    [[ "$STUB_FAILURE" != chrome ]] || exit 12
    ;;
  pdftoppm)
    [[ "${4}" == "$RENDER_OUT_DIR"/.usage-guide-print.*/guide.pdf && -s "${4}" ]] || exit 91
    printf '%s\n' 'review PNG' > "${5}-1.png"
    [[ "$STUB_FAILURE" != pdftoppm ]] || exit 13
    ;;
  pdfinfo)
    [[ "$1" == "$RENDER_OUT_DIR"/.usage-guide-print.*/guide.pdf && -s "$1" ]] || exit 92
    [[ "$STUB_FAILURE" != pdfinfo ]] || exit 14
    printf '%s\n' 'Pages: 1' 'Page size: 960 x 540 pts'
    ;;
  pdffonts)
    [[ "$1" == "$RENDER_OUT_DIR"/.usage-guide-print.*/guide.pdf && -s "$1" ]] || exit 93
    [[ "$STUB_FAILURE" != pdffonts ]] || exit 15
    printf '%s\n' 'name type encoding emb sub uni object ID' '------------------------------------' 'ABCDEF+GuideFont TrueType Identity-H yes yes yes 1 0'
    ;;
  mv)
    if [[ "$STUB_FAILURE" == publish_pdf && "${3:-}" == "$RENDER_OUT_DIR/guide name.pdf" ]]; then
      exit 16
    fi
    if [[ "$STUB_FAILURE" == interrupt_publish && "${2:-}" == "$RENDER_OUT_DIR"/.usage-guide-print.*/standalone.html ]]; then
      "$RENDER_REAL_MV" "$@"
      kill -TERM "$PPID"
      exit 0
    fi
    exec "$RENDER_REAL_MV" "$@"
    ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$bin/stub"
for tool in 'chrome stub' pdftoppm pdfinfo pdffonts mv; do
  ln -s stub "$bin/$tool"
done

run_render() {
  local failure="$1" expected="$2" actual=0 chrome="$bin/chrome stub"
  [[ "$failure" != missing_chrome ]] || chrome="$bin/missing chrome"
  : > "$TEST_ROOT/stub.log"
  PATH="$bin:$PATH" CHROME="$chrome" GUIDE_FONT="$TEST_ROOT/test font.woff2" \
    TMPDIR="$tmp_dir" STUB_FAILURE="$failure" STUB_LOG="$TEST_ROOT/stub.log" \
    RENDER_OUT_DIR="$out_dir" RENDER_REAL_MV="$real_mv" \
    "$REPO_ROOT/agents/skills/owned/usage-guide/scripts/render.sh" \
    "$source_html" "$out_dir" 'guide name' > "$TEST_ROOT/output" 2>&1 || actual=$?
  if [[ "$expected" == success ]]; then
    [[ "$actual" -eq 0 ]] || { cat "$TEST_ROOT/output" >&2; fail "render failed: $failure"; }
  elif [[ "$expected" == interrupted ]]; then
    [[ "$actual" -eq 143 ]] || fail "interrupted render returned $actual instead of 143"
  else
    [[ "$actual" -ne 0 ]] || fail "render unexpectedly succeeded: $failure"
  fi
  [[ -z "$(find "$out_dir" -name '.usage-guide-print.*' -print)" ]] || fail "staged files were not cleaned up: $failure"
}

for failure in missing_chrome chrome missing_pdf empty_pdf pdftoppm pdfinfo pdffonts publish_pdf; do
  echo "scenario: $failure preserves existing outputs"
  cp "$TEST_ROOT/old.html" "$out_dir/guide name.html"
  cp "$TEST_ROOT/old.pdf" "$out_dir/guide name.pdf"
  run_render "$failure" failure
  case "$failure" in
    missing_chrome) diagnostic='Chrome or Chromium is not executable' ;;
    chrome) diagnostic='Chrome failed to render the PDF' ;;
    missing_pdf|empty_pdf) diagnostic='Chrome did not write a nonempty PDF' ;;
    pdftoppm) diagnostic='PDF review rendering failed' ;;
    pdfinfo) diagnostic='PDF metadata validation failed' ;;
    pdffonts) diagnostic='PDF font validation failed' ;;
    publish_pdf) diagnostic='could not publish PDF:' ;;
  esac
  grep -Fq "$diagnostic" "$TEST_ROOT/output" || { cat "$TEST_ROOT/output" >&2; fail "unexpected failure: $failure"; }
  cmp -s "$TEST_ROOT/old.html" "$out_dir/guide name.html" || fail "HTML changed after $failure"
  cmp -s "$TEST_ROOT/old.pdf" "$out_dir/guide name.pdf" || fail "PDF changed after $failure"
  [[ -z "$(find "$tmp_dir" -name 'usage-guide-review.*' -print)" ]] || fail "failed review files were not cleaned up: $failure"
done

echo "scenario: TERM after publishing HTML restores the previous pair"
run_render interrupt_publish interrupted
cmp -s "$TEST_ROOT/old.html" "$out_dir/guide name.html" || fail "HTML changed after TERM"
cmp -s "$TEST_ROOT/old.pdf" "$out_dir/guide name.pdf" || fail "PDF changed after TERM"
[[ -z "$(find "$tmp_dir" -name 'usage-guide-review.*' -print)" ]] || fail "interrupted review files were not cleaned up"

echo "scenario: failed publication removes new HTML when no prior output existed"
rm "$out_dir/guide name.html" "$out_dir/guide name.pdf"
run_render publish_pdf failure
[[ ! -e "$out_dir/guide name.html" && ! -e "$out_dir/guide name.pdf" ]] || fail "failed first publication left outputs"

echo "scenario: success replaces both files and retains review PNGs"
cp "$TEST_ROOT/old.html" "$out_dir/guide name.html"
cp "$TEST_ROOT/old.pdf" "$out_dir/guide name.pdf"
run_render none success
cmp -s "$source_html" "$out_dir/guide name.html" || fail "new standalone HTML was not published"
[[ "$(cat "$out_dir/guide name.pdf")" == 'new PDF' ]] || fail "new PDF was not published"
review="$(sed -n 's/^review: //p' "$TEST_ROOT/output")"
[[ -s "$review/page-1.png" ]] || fail "successful review PNGs were not retained"
grep -q '^Pages: 1$' "$TEST_ROOT/output" || fail "page count was not reported"
grep -q '^  GuideFont (1)$' "$TEST_ROOT/output" || fail "embedded font was not reported"
for tool in 'chrome stub' pdftoppm pdfinfo pdffonts; do
  grep -Fxq "$tool" "$TEST_ROOT/stub.log" || fail "$tool was not run"
done

echo "Usage guide render scenarios passed."
