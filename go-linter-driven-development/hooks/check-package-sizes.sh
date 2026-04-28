#!/usr/bin/env bash
# Portable package-size gate for the go-linter-driven-development plugin.
#
# Fires as a PostToolUse hook after Write / Edit / MultiEdit. Scans Go source
# roots under $CLAUDE_PROJECT_DIR and counts non-test, non-generated .go files
# per directory at one level deep.
#
# Thresholds (also documented in the refactoring and pre-commit-review skills):
#   >=13 files = RED    -> exit 2, stderr is fed back to Claude as a blocking
#                          error so the violation is acknowledged before more
#                          code lands in the oversized package.
#   8-12 files = YELLOW -> exit 0 with stdout advisory, no block.
#   <=7 files  = GREEN  -> silent, exit 0.
#
# Guards:
#   - no-op unless $CLAUDE_PROJECT_DIR/go.mod exists (not a Go project)
#   - no-op if none of internal/, cmd/, pkg/ exist
#
# Uses only POSIX-portable tools: find, wc, tr, sort. No jq / python / task.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

[[ -f "$PROJECT_DIR/go.mod" ]] || exit 0

YELLOW_MIN=8
RED_MIN=13

roots=()
for d in internal cmd pkg; do
  [[ -d "$PROJECT_DIR/$d" ]] && roots+=("$PROJECT_DIR/$d")
done

(( ${#roots[@]} == 0 )) && exit 0

red_lines=()
yellow_lines=()

while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  count=$(find "$dir" -maxdepth 1 -type f -name '*.go' \
    -not -name '*_test.go' \
    -not -name '*_gen.go' \
    -not -name '*.pb.go' \
    2>/dev/null | wc -l | tr -d ' ')

  rel=${dir#$PROJECT_DIR/}
  if (( count >= RED_MIN )); then
    red_lines+=("  $rel: $count non-test .go files (RED zone, must decompose)")
  elif (( count >= YELLOW_MIN )); then
    yellow_lines+=("  $rel: $count non-test .go files (YELLOW zone, design review before next file)")
  fi
done < <(find "${roots[@]}" -type d \
  -not -path '*/vendor/*' \
  -not -path '*/testdata/*' \
  2>/dev/null | sort -u)

if (( ${#red_lines[@]} > 0 )); then
  {
    echo "⛔ Package size gate — RED zone detected:"
    printf '%s\n' "${red_lines[@]}"
    echo ""
    echo "These packages MUST be decomposed before more code lands."
    echo "Apply the 3-step design review (see refactoring skill <package_decomposition>):"
    echo "  1. Does the package name reflect a real-world domain concept (not a role/container)?"
    echo "  2. Are types well-scoped, or are there big structs hiding sub-types or primitive-obsession fields?"
    echo "  3. Only after the type review, decide: sub-packages, new leaf types, or both."
  } >&2
  exit 2
fi

if (( ${#yellow_lines[@]} > 0 )); then
  echo "⚠️  Package size gate — YELLOW zone:"
  printf '%s\n' "${yellow_lines[@]}"
  echo "Design review recommended before the next file lands in these packages."
fi

exit 0
