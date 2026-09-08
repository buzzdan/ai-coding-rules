#!/usr/bin/env bash
# gen-review-graders.sh — derive the review-full case's recall and precision
# graders from violations.yaml, so the manifest stays the single source.
#
#   recall-<id>.md     one per distinct file set among plants that carry an
#                      expect.review: the report must mention at least one of
#                      the plant's files by basename. Plants sharing the same
#                      file set share one grader (a basename regex cannot tell
#                      them apart anyway); the covered ids are listed as a YAML
#                      comment inside the grader.
#   cluster-<slug>.md  one per distinct expect.review.cluster anchor: a
#                      🔗 CLUSTER line naming that anchor must appear.
#   precision-<id>.md  one per control WITHOUT `mention_ok: true`: the control's
#                      `symbol:` regex must not appear anywhere in the report.
#                      A control that a correct report legitimately mentions
#                      (ParseRegion as the reuse target, errors.Is as a fix, …)
#                      opts out with mention_ok; a control lacking `symbol:`
#                      fails the generator so the manifest stays complete.
#
# Usage: tools/gen-review-graders.sh [violations.yaml] [graders-dir]
# Re-runnable: previously generated recall-/cluster-/precision- files are
# removed first; hand-written graders in the same dir are left alone.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
manifest="${1:-$here/../violations.yaml}"
out="${2:-$here/../review-full/graders}"

[[ -f "$manifest" ]] || { echo "manifest not found: $manifest" >&2; exit 2; }
mkdir -p "$out"
find "$out" -maxdepth 1 -type f \( -name 'recall-*.md' -o -name 'cluster-*.md' -o -name 'precision-*.md' \) -delete

# One record per entry, fields joined by the ASCII unit separator (\x1f) — a
# non-whitespace IFS keeps empty fields in place, where tabs would collapse:
#   id  control  basenames(space-sep)  has_review  cluster  symbol  mention_ok
records=$(awk '
  function flush() {
    if (id != "") printf "%s\037%s\037%s\037%s\037%s\037%s\037%s\n", id, control, files, review, cluster, symbol, mok
    id = ""; control = "false"; files = ""; review = "0"; cluster = ""; symbol = ""; mok = "false"
  }
  /^- id:[[:space:]]*/ { flush(); id = $0; sub(/^- id:[[:space:]]*/, "", id); sub(/[[:space:]].*$/, "", id); next }
  id == "" { next }
  /^[[:space:]]+control:[[:space:]]*true/ { control = "true"; next }
  /^[[:space:]]+mention_ok:[[:space:]]*true/ { mok = "true"; next }
  /^[[:space:]]+files:[[:space:]]*\[/ {
    f = $0; sub(/^[[:space:]]+files:[[:space:]]*\[/, "", f); sub(/\].*$/, "", f)
    n = split(f, parts, /,[[:space:]]*/); files = ""
    for (i = 1; i <= n; i++) { b = parts[i]; gsub(/[[:space:]]/, "", b); sub(/.*\//, "", b); files = files (i > 1 ? " " : "") b }
    next
  }
  /^[[:space:]]+symbol:[[:space:]]*'\''/ {
    symbol = $0; sub(/^[[:space:]]+symbol:[[:space:]]*'\''/, "", symbol); sub(/'\''[[:space:]]*(#.*)?$/, "", symbol); next
  }
  /^[[:space:]]+review:/ || /^[[:space:]]+expect:[[:space:]]*\{[[:space:]]*review/ {
    review = "1"
    if (match($0, /cluster: "[^"]+"/)) { cluster = substr($0, RSTART + 10, RLENGTH - 11) }
    next
  }
  END { flush() }
' "$manifest")

# escape_re <basename> — a literal file name as an ERE fragment.
escape_re() { printf '%s' "$1" | sed -e 's/[.[\*^$+?(){}|\\]/\\&/g'; }
# slug <anchor> — a cluster anchor as a file-name fragment.
slug() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9]+/-/g' -e 's/[^a-z0-9]/-/g' -e 's/^-//' -e 's/-$//'; }

declare -A recall_ids recall_first
declare -A clusters
n_recall=0 n_cluster=0 n_precision=0 missing_symbol=0

while IFS=$'\x1f' read -r id control files review cluster symbol mok; do
  [[ -n "$id" ]] || continue
  if [[ "$control" == "true" ]]; then
    [[ "$mok" == "true" ]] && continue
    if [[ -z "$symbol" ]]; then
      echo "control $id has no symbol: (add symbol: '…' or mention_ok: true)" >&2
      missing_symbol=1
      continue
    fi
    cat > "$out/precision-$id.md" <<EOF
---
# control $id: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: '$symbol'
match: not_contains
target: last_message
---
EOF
    n_precision=$((n_precision + 1))
    continue
  fi
  [[ "$review" == "1" ]] || continue
  pat=""
  for b in $files; do
    pat="${pat}${pat:+|}$(escape_re "$b")"
  done
  [[ -n "$pat" ]] || continue
  if [[ -z "${recall_first[$pat]:-}" ]]; then
    recall_first[$pat]="$id"
    recall_ids[$pat]="$id"
  else
    recall_ids[$pat]="${recall_ids[$pat]}, $id"
  fi
  if [[ -n "$cluster" ]]; then
    clusters[$cluster]="${clusters[$cluster]:-}${clusters[$cluster]:+, }$id"
  fi
done <<< "$records"

(( missing_symbol == 0 )) || exit 1

for pat in "${!recall_first[@]}"; do
  id="${recall_first[$pat]}"
  ids="${recall_ids[$pat]}"
  case "$pat" in *'|'*) pattern="($pat)" ;; *) pattern="$pat" ;; esac
  cat > "$out/recall-$id.md" <<EOF
---
# recall: the report names at least one file of this plant by basename.
# ids: $ids
type: regex
pattern: '$pattern'
match: contains
target: last_message
---
EOF
  n_recall=$((n_recall + 1))
done

for anchor in "${!clusters[@]}"; do
  s=$(slug "$anchor")
  esc=$(escape_re "$anchor")
  cat > "$out/cluster-$s.md" <<EOF
---
# cluster: ≥2 hunters converge on "$anchor"; the report must render a
# 🔗 CLUSTER entry naming it. members: ${clusters[$anchor]}
type: regex
pattern: 'CLUSTER.*$esc'
match: contains
target: last_message
---
EOF
  n_cluster=$((n_cluster + 1))
done

echo "gen-review-graders: $n_recall recall, $n_cluster cluster, $n_precision precision graders → $out"
