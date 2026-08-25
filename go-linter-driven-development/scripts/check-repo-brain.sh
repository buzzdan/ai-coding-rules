#!/usr/bin/env bash
# Repo-brain conformance gate for the go-linter-driven-development plugin.
#
# Runs R9's mechanical falsifying questions over every doc root so CI — and
# developers without the plugin — can hold the documentation network's
# invariants. What it enforces is the R9 profile: a strict superset of OKF
# v0.2 (rules/R9-repo-brain.md is normative; <docroot>/conventions.md is the
# in-repo copy). Installed into target repos by the documentation skill's
# BOOTSTRAP pass (/wire-repo-brain).
#
# Usage:  bash scripts/check-repo-brain.sh [repo-root]     (default: cwd)
# CI:     one line — bash scripts/check-repo-brain.sh
#
# Doc roots are discovered at the repo root AND at every sub-project (a
# directory holding go.mod), using R9's order: .ai/ -> .ainav/ -> docs/.
#
# Checks (numbering follows rules/R9-repo-brain.md's falsifying questions):
#   Q1  orphans        — every doc is reachable from its bundle's root index,
#                        transitively through sub-indexes
#   Q2  edges          — code→docs paths resolve; doc links resolve; doc-cited
#                        exported symbols grep in the repo; no file:line
#                        citations (URL spans stripped before the test)
#   Q3  root wiring    — CLAUDE.md or AGENTS.md in the root's owning project
#                        carries the exact <docroot>/index.md path (a monorepo
#                        sub-root may instead be linked from the repo-root
#                        index); AGENTS.md missing the reference is an advisory
#   Q7  bundle contract— content docs carry terminated frontmatter with
#                        type/description/generated; indexes carry NO
#                        frontmatter except the root index's lone okf_version
#                        (required there); no `related:` key; no log.md; every
#                        index line's text matches the target's `description`
#                        when it has one (⚠️ lines exempt)
#
# Heuristics (documented, deliberate):
#   - links are inline-markdown only (`[name](path.md)`, optional "title"
#     stripped); reference-style links are not checked.
#   - docs→code checks backticked tokens shaped like exported Go identifiers
#     (`Foo`, `Foo.Bar`) or package-qualified ones (`pkg.Foo`) that contain a
#     lowercase letter; other backticks (paths, flags, ALL-CAPS initialisms,
#     <placeholders>) are skipped. A bare token resolves against type/func/
#     var/const declarations, including `Foo =` inside var/const blocks.
#   - lines carrying the ⚠️ stale flag or a *(planned)* marker are exempt from
#     symbol resolution and the description copy check (R9 Q2/Q7 exemptions);
#     the file:line ban has no exemption beyond URL spans.
#   - fenced code blocks (``` or ~~~, indented up to 3 spaces; toggle, not
#     length-matched) are skipped for symbol resolution.
#
# Exit codes: 0 clean (or repo has no doc root yet — advisory no-op)
#             1 one or more violations (details on stderr, summary last)
#             2 usage error
#
# Uses only POSIX-portable tools: find, grep, sed, awk, head, sort, wc. No jq/python.

set -u

REPO_ROOT="${1:-$(pwd)}"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "check-repo-brain: not a directory: $REPO_ROOT" >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2

# ---------- doc-root discovery: repo root + every go.mod directory ----------
discover_docroot() { # <project-dir> -> docroot path or ''
  local base="$1" d p
  for d in .ai .ainav docs; do
    if [[ "$base" == "." ]]; then p="$d"; else p="$base/$d"; fi
    [[ -d "$p" ]] && { printf '%s\n' "$p"; return; }
  done
}

PROJS=()
ROOTS=()
seen_roots=" "
add_root() { # <project-dir>
  local r
  r=$(discover_docroot "$1")
  [[ -z "$r" ]] && return
  case "$seen_roots" in *" $r "*) return ;; esac
  seen_roots="$seen_roots$r "
  PROJS+=("$1")
  ROOTS+=("$r")
}
add_root "."
while IFS= read -r gm; do
  p=$(dirname "$gm"); p="${p#./}"
  [[ "$p" == "." || -z "$p" ]] && continue
  add_root "$p"
done < <(find . -name go.mod -not -path '*/vendor/*' -not -path './.git/*' 2>/dev/null | sort)

if (( ${#ROOTS[@]} == 0 )); then
  echo "check-repo-brain: no doc root (.ai/, .ainav/, docs/) at the repo root or any go.mod sub-project — nothing to check yet; run /wire-repo-brain to bootstrap"
  exit 0
fi
ROOT_BUNDLE=""
for i in "${!PROJS[@]}"; do
  [[ "${PROJS[$i]}" == "." ]] && ROOT_BUNDLE="${ROOTS[$i]}"
done

violations=0
CUR_DOCROOT="${ROOTS[0]}"
fail() {
  echo "  $1 — see $CUR_DOCROOT/conventions.md" >&2
  violations=$((violations + 1))
}
note() { echo "  advisory: $1"; }

# canon <path> -> physical path with .. resolved (empty if parent dir missing)
canon() {
  local dir base
  dir=$(dirname "$1")
  base=$(basename "$1")
  (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$base")
}

# resolve_link <containing-file> <target> <docroot> -> absolute path ('' for URLs/anchors)
resolve_link() {
  local from="$1" target="$2" docroot="$3"
  target="${target%%#*}"
  target="${target%% *}"                              # strip optional "title"
  [[ -z "$target" || "$target" == *"://"* ]] && return 0
  if [[ "$target" == /* ]]; then
    printf '%s\n' "$(canon "$docroot/${target#/}")"   # bundle-relative (OKF)
  else
    printf '%s\n' "$(canon "$(dirname "$from")/$target")"
  fi
}

# frontmatter helpers -----------------------------------------------------
fm_close_line() { # <file> -> line number of closing --- (or '')
  awk 'NR > 1 && /^---$/ { print NR; exit }' "$1"
}
fm_block() { # <file> <close-line> -> frontmatter body
  sed -n "2,$(( $2 - 1 ))p" "$1"
}
desc_of() { # <file> -> description value ('' if none)
  local close
  [[ "$(head -1 "$1" 2>/dev/null)" == "---" ]] || return 0
  close=$(fm_close_line "$1")
  [[ -z "$close" ]] && return 0
  fm_block "$1" "$close" | grep -m1 '^description:' \
    | sed -e 's/^description:[[:space:]]*//' -e 's/[[:space:]]*$//'
}

have_go=0
if find . -name '*.go' -not -path './vendor/*' -not -path '*/vendor/*' -not -path './.git/*' -print -quit 2>/dev/null | grep -q .; then
  have_go=1
fi

# ---------- Q2: code→docs edges (repo-wide; resolved from repo root, then the
# citing file's own sub-project) ----------
docroot_for_file() { # <file> -> docroot of the longest matching project dir
  local f="${1#./}" best="" i
  for i in "${!PROJS[@]}"; do
    local p="${PROJS[$i]}"
    [[ "$p" == "." ]] && { [[ -z "$best" ]] && best="${ROOTS[$i]}"; continue; }
    case "$f" in "$p"/*) best="${ROOTS[$i]}" ;; esac
  done
  printf '%s\n' "${best:-${ROOTS[0]}}"
}

if (( have_go )); then
  while IFS= read -r hit; do
    file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"; target="${rest#*:}"
    [[ -f "$target" ]] && continue
    proj_ok=0
    for i in "${!PROJS[@]}"; do
      p="${PROJS[$i]}"; [[ "$p" == "." ]] && continue
      case "${file#./}" in "$p"/*) [[ -f "$p/$target" ]] && proj_ok=1 ;; esac
    done
    if (( ! proj_ok )); then
      CUR_DOCROOT=$(docroot_for_file "$file")
      fail "[Q2] $file:$line — code edge points at missing $target"
    fi
  done < <(grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' \
             --include='*.go' --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null)
fi

# ---------- per-bundle checks ----------
check_bundle() { # <project-dir> <docroot>
  local proj="$1" docroot="$2"
  CUR_DOCROOT="$docroot"
  local root_index="$docroot/index.md"
  local root_index_c
  root_index_c=$(canon "$root_index")

  # --- Q1: transitive reachability from the bundle's root index ---
  local reachable="" visited="" queue=("$root_index")
  while (( ${#queue[@]} > 0 )); do
    local idx="${queue[0]}"; queue=("${queue[@]:1}")
    local idx_c; idx_c=$(canon "$idx")
    case "$visited" in *"$idx_c"$'\n'*) continue ;; esac
    visited="$visited$idx_c"$'\n'
    [[ -f "$idx" ]] || continue
    while IFS= read -r raw; do
      local t="${raw#](}"; t="${t%)}"
      [[ "$t" == *.md* ]] || continue
      local resolved; resolved=$(resolve_link "$idx" "$t" "$docroot")
      [[ -z "$resolved" ]] && continue
      reachable="$reachable$resolved"$'\n'
      [[ "$(basename "$resolved")" == "index.md" ]] && queue+=("$resolved")
    done < <(grep -oE '\]\([^)]+\)' "$idx" 2>/dev/null)
  done
  if [[ ! -f "$root_index" ]]; then
    fail "[Q1] $docroot — no index.md: the bundle has no map"
  fi
  while IFS= read -r doc; do
    [[ "$(basename "$doc")" == "log.md" ]] && continue   # its own Q7 ban reports it
    local c; c=$(canon "$doc")
    [[ "$c" == "$root_index_c" ]] && continue
    case "$reachable" in *"$c"$'\n'*) ;; *)
      fail "[Q1] $doc — orphan: not reachable from $root_index" ;;
    esac
  done < <(find "$docroot" -type f -name '*.md')

  # --- Q2: every doc link resolves ---
  while IFS= read -r md; do
    while IFS= read -r raw; do
      local t="${raw#](}"; t="${t%)}"
      [[ "$t" == *.md* ]] || continue
      local resolved; resolved=$(resolve_link "$md" "$t" "$docroot")
      [[ -z "$resolved" ]] && continue
      [[ -f "$resolved" ]] || fail "[Q2] $md — link target does not exist: $t"
    done < <(grep -oE '\]\([^)]+\)' "$md" 2>/dev/null)
  done < <(find "$docroot" -type f -name '*.md')

  # --- Q2: docs→code — backticked exported symbols must grep ---
  if (( have_go )); then
    while IFS= read -r md; do
      local in_fence=0 lineno=0 line
      while IFS= read -r line; do
        lineno=$((lineno + 1))
        if printf '%s' "$line" | grep -qE '^ {0,3}(```|~~~)'; then
          in_fence=$((1 - in_fence)); continue
        fi
        (( in_fence )) && continue
        case "$line" in *'⚠️'*|*'*(planned)*'*) continue ;; esac
        local tok
        while IFS= read -r tok; do
          tok="${tok#\`}"; tok="${tok%\`}"
          printf '%s' "$tok" | grep -qE '^[A-Z][A-Za-z0-9]*$|^[A-Za-z][A-Za-z0-9_]*\.[A-Z][A-Za-z0-9]*$' || continue
          printf '%s' "$tok" | grep -q '[a-z]' || continue
          if [[ "$tok" == *.* ]]; then
            local prefix="${tok%%.*}" member="${tok#*.}"
            if printf '%s' "$prefix" | grep -qE '^[A-Z]'; then
              # Type.Method — resolve the method
              grep -rqE "func .*\) ${member}\(|func ${member}\(" \
                --include='*.go' --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null && continue
              fail "[Q2] $md:$lineno — backticked \`$tok\` does not resolve (method ${member} not found)"
            else
              # pkg.Symbol — resolve the symbol's declaration
              grep -rqE "(type|func|var|const) ${member}\b|^[[:space:]]*${member}[[:space:]]*=" \
                --include='*.go' --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null && continue
              fail "[Q2] $md:$lineno — backticked \`$tok\` does not resolve (no declaration of ${member})"
            fi
          else
            grep -rqE "(type|func|var|const) ${tok}\b|^[[:space:]]*${tok}[[:space:]]*=" \
              --include='*.go' --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null && continue
            fail "[Q2] $md:$lineno — backticked \`$tok\` does not resolve (no declaration of ${tok})"
          fi
        done < <(printf '%s\n' "$line" | grep -oE '`[^`]+`')
      done < "$md"
    done < <(find "$docroot" -type f -name '*.md')
  fi

  # --- Q2: file:line citation ban (URL spans stripped, not whole lines) ---
  while IFS= read -r hit; do
    local file="${hit%%:*}"; local rest="${hit#*:}"; local line="${rest%%:*}"
    local text="${rest#*:}"
    local stripped
    stripped=$(printf '%s' "$text" | sed -E 's#[A-Za-z][A-Za-z0-9+.-]*://[^ )>]*##g')
    if printf '%s' "$stripped" | grep -qE '\.go(:[0-9]+)?|line [0-9]+'; then
      fail "[Q2] $file:$line — cites a file path or line number (churn-prone coordinate)"
    fi
  done < <(grep -rnE '\.go(:[0-9]+)?|line [0-9]+' "$docroot" --include='*.md' 2>/dev/null)

  # --- Q3: root wiring (exact path; sub-roots may ride the repo-root index) ---
  local rel="$docroot"
  [[ "$proj" != "." ]] && rel="${docroot#$proj/}"
  local claude="CLAUDE.md" agents="AGENTS.md"
  [[ "$proj" != "." ]] && { claude="$proj/CLAUDE.md"; agents="$proj/AGENTS.md"; }
  local wired_claude=0 wired_agents=0
  [[ -f "$claude" ]] && grep -q "$rel/index.md" "$claude" && wired_claude=1
  [[ -f "$agents" ]] && grep -q "$rel/index.md" "$agents" && wired_agents=1
  if (( ! wired_claude && ! wired_agents )); then
    local via_root=0
    if [[ "$proj" != "." && -n "$ROOT_BUNDLE" ]]; then
      grep -rq "$docroot/index.md" "$ROOT_BUNDLE" --include='*.md' 2>/dev/null && via_root=1
    fi
    if (( ! via_root )); then
      fail "[Q3] $proj — neither $claude nor $agents references $rel/index.md"
    fi
  elif (( ! wired_agents )); then
    note "[Q3] $agents lacks the $rel/index.md routing reference — AGENTS.md-reading tools start blind"
  fi

  # --- Q7: bundle contract ---
  while IFS= read -r md; do
    local close fm key
    [[ "$(basename "$md")" == "log.md" ]] && continue    # its own Q7 ban reports it
    if [[ "$(basename "$md")" == "index.md" ]]; then
      local is_root=0
      [[ "$(canon "$md")" == "$root_index_c" ]] && is_root=1
      if [[ "$(head -1 "$md" 2>/dev/null)" != "---" ]]; then
        # bare index — conformant, except the root must carry okf_version
        (( is_root )) && fail "[Q7] $md — root index missing its okf_version frontmatter"
        continue
      fi
      close=$(fm_close_line "$md")
      if [[ -z "$close" ]]; then
        fail "[Q7] $md — unterminated frontmatter (no closing ---)"
        continue
      fi
      if (( ! is_root )); then
        fail "[Q7] $md — frontmatter on a sub-index (indexes stay bare; okf_version belongs to the root alone)"
        continue
      fi
      fm=$(fm_block "$md" "$close")
      printf '%s\n' "$fm" | grep -q '^okf_version:' \
        || fail "[Q7] $md — root index missing 'okf_version:'"
      local extra
      extra=$(printf '%s\n' "$fm" | grep -E '^[A-Za-z_-]+:' | grep -v '^okf_version:' | head -1)
      [[ -n "$extra" ]] \
        && fail "[Q7] $md — root index frontmatter carries '${extra%%:*}:' (okf_version is the only allowed key)"
      continue
    fi
    if [[ "$(head -1 "$md" 2>/dev/null)" != "---" ]]; then
      fail "[Q7] $md — no frontmatter block (first line must be ---)"
      continue
    fi
    close=$(fm_close_line "$md")
    if [[ -z "$close" ]]; then
      fail "[Q7] $md — unterminated frontmatter (no closing ---)"
      continue
    fi
    fm=$(fm_block "$md" "$close")
    if printf '%s\n' "$fm" | grep -q '^related:'; then
      fail "[Q7] $md — 'related:' frontmatter key (links live in the body)"
    fi
    for key in type description generated; do
      printf '%s\n' "$fm" | grep -q "^${key}:" \
        || fail "[Q7] $md — frontmatter missing '${key}:'"
    done
  done < <(find "$docroot" -type f -name '*.md')

  # --- Q7: drift check — index line text == target's description (⚠️ exempt) ---
  while IFS= read -r idx; do
    local lineno=0 line
    while IFS= read -r line; do
      lineno=$((lineno + 1))
      case "$line" in *'⚠️'*) continue ;; esac
      printf '%s' "$line" | grep -qE '^- \[[^]]*\]\([^)]*\.md[^)]*\) — ' || continue
      local t; t=$(printf '%s' "$line" | sed -E 's/^- \[[^]]*\]\(([^)]*)\).*/\1/')
      local tail="${line#* — }"
      tail=$(printf '%s' "$tail" | sed -e 's/[[:space:]]*$//')
      local resolved; resolved=$(resolve_link "$idx" "$t" "$docroot")
      [[ -n "$resolved" && -f "$resolved" ]] || continue
      local desc; desc=$(desc_of "$resolved")
      [[ -z "$desc" ]] && continue
      if [[ "$tail" != "$desc" ]]; then
        fail "[Q7] $idx:$lineno — index line drifted from $(basename "$resolved")'s description"
      fi
    done < "$idx"
  done < <(find "$docroot" -type f -name 'index.md')

  # --- Q7: no log.md ---
  while IFS= read -r lg; do
    fail "[Q7] $lg — log.md is reserved for change history; docs describe current behavior"
  done < <(find "$docroot" -type f -name 'log.md')
}

for i in "${!PROJS[@]}"; do
  check_bundle "${PROJS[$i]}" "${ROOTS[$i]}"
done

# ---------- summary ----------
if (( violations > 0 )); then
  echo "check-repo-brain: $violations violation(s) — rules: <docroot>/conventions.md" >&2
  exit 1
fi
echo "check-repo-brain: clean (${ROOTS[*]})"
exit 0
