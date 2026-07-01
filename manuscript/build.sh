#!/usr/bin/env bash
# build.sh -- reproducible manuscript build.
#
# Locates a pandoc and a xelatex without requiring either on PATH, then runs the
# Makefile. Resolution order:
#   pandoc  : repo-bundled .tools/pandoc-*/bin -> PATH
#   xelatex : TinyTeX (~/Library/TinyTeX or ~/.TinyTeX) -> /Library/TeX/texbin -> PATH
# so a checkout with the bundled .tools/ (gitignored) or a TinyTeX install builds
# with no extra setup. CI installs both fresh (see .github/workflows/manuscript.yml).
#
# Usage:
#   bash manuscript/build.sh                 # PDF, default style (apa)
#   bash manuscript/build.sh chicago-author-date
#   bash manuscript/build.sh vancouver docx  # style + target (pdf|docx|html)
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
STYLE="${1:-apa}"
TARGET="${2:-pdf}"

find_pandoc() {
  local p
  p="$(ls "$ROOT"/.tools/pandoc-*/bin/pandoc 2>/dev/null | head -1 || true)"
  [ -n "$p" ] && { dirname "$p"; return; }
  command -v pandoc >/dev/null 2>&1 && { dirname "$(command -v pandoc)"; return; }
  return 1
}
find_xelatex() {
  local x
  for d in "$HOME/Library/TinyTeX/bin"/* "$HOME/.TinyTeX/bin"/* /Library/TeX/texbin; do
    [ -x "$d/xelatex" ] && { echo "$d"; return; }
  done
  command -v xelatex >/dev/null 2>&1 && { dirname "$(command -v xelatex)"; return; }
  return 1
}

PANDOC_BIN="$(find_pandoc)" || { echo "ERROR: no pandoc found (bundle one in .tools/ or install pandoc)"; exit 1; }
export PATH="$PANDOC_BIN:$PATH"
if [ "$TARGET" = "pdf" ]; then
  XELATEX_BIN="$(find_xelatex)" || { echo "ERROR: no xelatex found (install TinyTeX: https://yihui.org/tinytex/)"; exit 1; }
  export PATH="$XELATEX_BIN:$PATH"
fi

echo "pandoc:  $(command -v pandoc)  ($(pandoc --version | head -1))"
[ "$TARGET" = "pdf" ] && echo "xelatex: $(command -v xelatex)"
echo "building: STYLE=$STYLE TARGET=$TARGET"
make "$TARGET" STYLE="$STYLE"
echo "done -> manuscript/manuscript.$TARGET"
