#!/usr/bin/env bash
# autopilot-sms postcheck: the end-state assertions a transcript grader cannot
# make. Runs in the kept scaffold dir (cwd = $EVAL_DIR) after the agent finished;
# $EVAL_OUT holds trace.jsonl. Every check runs (no set -e) so postcheck.txt is
# a complete findings log; the exit code is the failure tally.
#
# Self-contained on purpose: evals/postcheck/lib.sh is a sibling deliverable
# whose helper names changed while this case was written, so only its DATA
# (assertion-counts.txt) and the black-box suite's contract (EVAL_DIR env,
# `go test -count=1 -v`, a SKIP means EVAL_DIR was not honoured) are used here.
#
# Checks, in order:
#   1-3  task build / task test / task lint are green on the working tree
#   4    hidden black-box heartbeat suite (evals/postcheck/heartbeat-blackbox), if present
#   5    GET /channels on the built binary returns 200 application/json listing sms + the 3 others
#   6    >= 3 commits on top of the scaffold base (prep commit(s) + feature)
#   7    prep before feature: the first commit whose Go code mentions sms is not the first commit
#   8    at least one new _test.go, and no `env.Config.<field> =` in any NEW test file
#   9    when-in-Rome: go.mod unchanged, no third-party imports, no golden/snapshot mechanism
#   10   no NEW //nolint in the diff; .golangci.yaml unchanged (lint-fixer hard limits)
#   11   one owner of the channel literals: "pagerduty" and switch/== on a.Channel appear
#        at most once each in non-test code (R11 refactor oracle; manifest count_max 1)
#   12   zero net new non-test files in internal/models (RED-zone package); the package-size
#        hook state is reported because the hook is opt-in since 9c9db61
#   13   fixture test assertion counts not weakened (baseline: evals/postcheck/assertion-counts.txt)
#   +    NOTES (never fail): DESIGN PLAN extracted to $EVAL_OUT/design-plan.txt, sms file
#        placement by `find`, dirty working tree, hook fired or not
set -u
case ":$PATH:" in *:/root/go/bin:*) ;; *) export PATH="$PATH:/root/go/bin" ;; esac

EVAL_DIR="${EVAL_DIR:-$PWD}"
EVAL_OUT="${EVAL_OUT:-$EVAL_DIR/.eval-out}"
mkdir -p "$EVAL_OUT"
cd "$EVAL_DIR" || { echo "FAIL  cannot cd to $EVAL_DIR"; exit 1; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
evals_dir=$(cd "$here/.." && pwd)
trace="$EVAL_OUT/trace.jsonl"

failures=0
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
ok()   { printf 'ok    %s\n' "$*"; }
note() { printf 'NOTE  %s\n' "$*"; }
indent() { sed 's/^/      /'; }
finish() {
  if (( failures > 0 )); then printf 'postcheck: %d failure(s)\n' "$failures"; exit 1; fi
  echo "postcheck: all assertions passed"; exit 0
}

base=$(git rev-list --max-parents=0 HEAD)
n_commits=$(git rev-list --count "$base..HEAD")
echo "autopilot-sms postcheck · base $(git rev-parse --short "$base") · HEAD $(git rev-parse --short HEAD) · $n_commits commit(s) since base"

# Files the agent added (committed or untracked), for the "new file" checks.
new_files() {
  { git diff --name-only --diff-filter=A "$base" HEAD -- "$@"
    git ls-files --others --exclude-standard -- "$@"; } | sort -u
}
# Added lines since base: committed + uncommitted diff, plus untracked files whole.
added_lines() {
  git diff "$base" -- "$@" | grep -E '^\+[^+]' | sed 's/^+//'
  local f
  while IFS= read -r f; do [[ -f "$f" ]] && cat "$f"; done < <(git ls-files --others --exclude-standard -- "$@")
}
prod_go() { find . -path ./.git -prune -o -type f -name '*.go' ! -name '*_test.go' -print; }
count_lines() { grep -c . || true; }

# ---------------------------------------------------------------- 1-3 build/test/lint
for t in build test lint; do
  if timeout 900 task "$t" > "$EVAL_OUT/postcheck-task-$t.txt" 2>&1; then
    ok "task $t green"
  else
    fail "task $t failed (see postcheck-task-$t.txt):"
    tail -n 12 "$EVAL_OUT/postcheck-task-$t.txt" | indent
  fi
done

# ---------------------------------------------------------------- 4 black-box suite
blackbox="$evals_dir/postcheck/heartbeat-blackbox"
if [[ -f "$blackbox/go.mod" ]]; then
  bb_rc=0
  (cd "$blackbox" && EVAL_DIR="$EVAL_DIR" timeout 900 go test -count=1 -v ./...) > "$EVAL_OUT/postcheck-blackbox.txt" 2>&1 || bb_rc=$?
  if (( bb_rc != 0 )); then
    fail "heartbeat black-box suite failed (exit $bb_rc) — POST /heartbeat behavior changed (see postcheck-blackbox.txt):"
    grep -E '^(--- FAIL|\s+blackbox_test|FAIL)' "$EVAL_OUT/postcheck-blackbox.txt" | head -n 15 | indent
  elif grep -q -- '--- SKIP' "$EVAL_OUT/postcheck-blackbox.txt"; then
    fail "heartbeat black-box suite skipped — EVAL_DIR was not honoured"
  else
    ok "heartbeat black-box suite green ($(grep -c '^--- PASS' "$EVAL_OUT/postcheck-blackbox.txt") subtests)"
  fi
else
  note "heartbeat black-box suite not present at $blackbox — skipped"
fi

# ---------------------------------------------------------------- 5 GET /channels smoke
free_port() {
  local p
  for p in $(seq 18080 18180); do
    (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null || { echo "$p"; return 0; }
  done
  return 1
}
# http_get <url> → sets HTTP_CODE, HTTP_CTYPE, HTTP_BODY; returns curl's status
http_get() {
  local out
  out=$(curl -sS -o - -w '\n@@%{http_code}@@%{content_type}' "$1" 2>/dev/null) || return 1
  HTTP_CODE=${out##*@@*@@}; HTTP_CODE=$(printf '%s' "$out" | sed -n 's/.*@@\([0-9]*\)@@.*/\1/p' | tail -n 1)
  HTTP_CTYPE=$(printf '%s' "$out" | sed -n 's/.*@@[0-9]*@@//p' | tail -n 1)
  HTTP_BODY=${out%$'\n'@@*}
}
if ! command -v curl >/dev/null 2>&1; then
  fail "curl not available — cannot smoke GET /channels"
elif [[ ! -x bin/svc ]]; then
  fail "bin/svc missing — task build did not produce the binary"
else
  port=$(free_port) || port=18080
  PORT="$port" ./bin/svc --dry-run > "$EVAL_OUT/postcheck-svc.log" 2>&1 &
  svc_pid=$!
  ready=0
  for _ in $(seq 1 50); do
    if http_get "http://127.0.0.1:$port/healthz" && [[ "$HTTP_CODE" == 200 ]]; then ready=1; break; fi
    sleep 0.1
  done
  if (( ready )); then
    if http_get "http://127.0.0.1:$port/channels"; then
      printf '%s\n' "$HTTP_BODY" > "$EVAL_OUT/postcheck-channels.json"
      if [[ "$HTTP_CODE" != 200 ]]; then
        fail "GET /channels → HTTP $HTTP_CODE (want 200); body: $(printf '%s' "$HTTP_BODY" | head -c 120)"
      elif [[ "$HTTP_CTYPE" != application/json* ]]; then
        fail "GET /channels Content-Type '$HTTP_CTYPE' (want application/json)"
      else
        listed=""
        if command -v jq >/dev/null 2>&1; then
          listed=$(printf '%s' "$HTTP_BODY" | jq -r 'if type=="array" then .[] else (.channels // .)[] end | strings' 2>/dev/null | tr '\n' ' ')
        fi
        if [[ -z "${listed// /}" ]]; then # no jq, or a shape jq did not understand: any lowercase JSON string counts
          listed=$(printf '%s' "$HTTP_BODY" | grep -oE '"[a-z]+"' | tr -d '"' | tr '\n' ' ')
        fi
        missing=""
        for ch in email slack pagerduty sms; do [[ " $listed " == *" $ch "* ]] || missing="$missing $ch"; done
        if [[ -z "$missing" ]]; then ok "GET /channels → 200 application/json listing: $listed"
        else fail "GET /channels body lacks:$missing (listed: ${listed:-<none>}; body: $(printf '%s' "$HTTP_BODY" | head -c 160))"; fi
      fi
    else
      fail "GET /channels: request failed"
    fi
  else
    fail "bin/svc did not become ready on :$port within 5s (see postcheck-svc.log)"
  fi
  kill "$svc_pid" 2>/dev/null; wait "$svc_pid" 2>/dev/null
fi

# ---------------------------------------------------------------- 6 commit count
if (( n_commits >= 3 )); then ok "$n_commits commits since base (>= 3: prep + feature)"
else fail "only $n_commits commit(s) since base; want >= 3 (prep commit(s), then the feature)"; fi
if [[ -n "$(git status --porcelain)" ]]; then note "working tree not clean — uncommitted changes:"; git status --porcelain | head -n 20 | indent; fi

# ---------------------------------------------------------------- 7 prep before feature
# "Touches sms" = a commit whose ADDED Go code lines (// comments stripped) contain sms.
# Commit messages and SPEC.md are ignored so "prepare for SMS" prose does not count.
idx=0; first_sms=-1; sms_free_before=0
while IFS= read -r sha; do
  [[ -z "$sha" ]] && continue
  if git show --format= "$sha" -- '*.go' | grep -E '^\+[^+]' | sed -E 's#//.*$##' | grep -qi 'sms'; then
    (( first_sms < 0 )) && first_sms=$idx
  elif (( first_sms < 0 )); then
    sms_free_before=$((sms_free_before + 1))
  fi
  idx=$((idx + 1))
done < <(git rev-list --reverse "$base..HEAD")
if (( first_sms < 0 )); then fail "no commit adds sms code — the feature was never committed"
elif (( sms_free_before >= 1 )); then ok "first sms commit is #$((first_sms + 1)) of $idx; $sms_free_before sms-free commit(s) precede it (prep before feature)"
else fail "the very first commit already adds sms code — no preparatory commit landed before the feature"; fi

# ---------------------------------------------------------------- 8 new tests exist; no global mutation in them
new_tests=$(new_files '*_test.go')
if [[ -z "$new_tests" ]]; then
  fail "no new _test.go file was added (the feature's RED tests are missing)"
else
  hits=$(printf '%s\n' "$new_tests" | xargs -r grep -nE 'env\.Config\.\w+\s*=[^=]' 2>/dev/null || true)
  if [[ -z "$hits" ]]; then ok "no env.Config.<field> = in $(printf '%s\n' "$new_tests" | wc -l | tr -d ' ') new test file(s)"
  else fail "new test mutates the global config (RED friction should have become a prep move):"; printf '%s\n' "$hits" | indent; fi
fi

# ---------------------------------------------------------------- 9 when-in-Rome
if git diff --quiet "$base" -- go.mod && [[ ! -e go.sum && ! -d vendor ]]; then ok "go.mod unchanged; no go.sum/vendor"
else fail "dependencies changed: go.mod/go.sum/vendor differ from base"; fi
foreign=$(grep -rnE '^\s*(import\s+)?(_\s+|[a-z]+\s+)?"(github\.com|golang\.org/x|gopkg\.in|gotest\.tools)/' --include='*.go' . 2>/dev/null | grep -v '^./.git/' || true)
if [[ -z "$foreign" ]]; then ok "no third-party imports (testify/zerolog/cobra/...)"
else fail "third-party import(s) introduced:"; printf '%s\n' "$foreign" | head -n 10 | indent; fi
golden=$(find . -path ./.git -prune -o \( -type d -name testdata -o -type f -name '*.golden' -o -type f -name '*.snap' \) -print 2>/dev/null | head -n 5 | tr '\n' ' ')
if [[ -z "$golden" ]]; then ok "no golden/snapshot test mechanism introduced"
else fail "new test mechanism the repo does not use: $golden"; fi

# ---------------------------------------------------------------- 10 lint-fixer hard limits
new_nolint=$(added_lines '*.go' | grep '//nolint' | count_lines)
if (( new_nolint == 0 )); then ok "no new //nolint directive since base"
else fail "$new_nolint new //nolint line(s) added since base:"; added_lines '*.go' | grep '//nolint' | head -n 5 | indent; fi
if git diff --quiet "$base" -- .golangci.yaml; then ok ".golangci.yaml unchanged"
else fail ".golangci.yaml was edited (lint-fixer hard limit; an adoption decision for the repo owner)"; fi

# ---------------------------------------------------------------- 11 one owner of the channel literals
pd=$(prod_go | xargs -r grep -nE '"pagerduty"' 2>/dev/null || true); pd_n=$(printf '%s\n' "$pd" | count_lines)
if (( pd_n <= 1 )); then ok "\"pagerduty\" literal: $pd_n owner(s) in non-test code (<= 1: the enum or its parser)"
else fail "\"pagerduty\" literal still has $pd_n owners in non-test code — the channel enum is not named once:"; printf '%s\n' "$pd" | indent; fi
sw=$(prod_go | xargs -r grep -nE 'switch a\.Channel|a\.Channel == "' 2>/dev/null || true); sw_n=$(printf '%s\n' "$sw" | count_lines)
if (( sw_n <= 1 )); then ok "switch/== on a.Channel: $sw_n site(s) in non-test code (manifest count_max 1)"
else fail "a.Channel still dispatched at $sw_n sites (R11.Q1 triplicated switch unresolved):"; printf '%s\n' "$sw" | indent; fi

# ---------------------------------------------------------------- 12 RED-zone package + hook state
models_base=$(git ls-tree --name-only "$base" internal/models/ | grep -E '\.go$' | grep -vE '_test\.go$' | count_lines)
models_now=$(find internal/models -maxdepth 1 -type f -name '*.go' ! -name '*_test.go' 2>/dev/null | count_lines)
hook_fired=0; [[ -f "$trace" ]] && grep -q 'Package size gate' "$trace" && hook_fired=1
hook_wired=0; grep -qs 'check-package-sizes' .claude/settings.json .claude/settings.local.json && hook_wired=1
if (( hook_fired )); then note "package-size hook fired during the run (trace contains 'Package size gate')"
else note "package-size hook did not fire: hooks/hooks.json is empty since 9c9db61 (opt-in); project wiring=$hook_wired — the RED-zone gate is unobservable in this eval"; fi
if (( models_now <= models_base )); then ok "internal/models: $models_now non-test files (base $models_base) — no net new file in the RED-zone package"
else fail "internal/models grew from $models_base to $models_now non-test files — new code landed in the RED-zone package (hook fired=$hook_fired)"; fi

# ---------------------------------------------------------------- 13 assertions not weakened
baseline="$evals_dir/postcheck/assertion-counts.txt"   # lines: "<count> <path>" as produced by grep -c 't\.\(Fatal\|Error\)'
if [[ -f "$baseline" ]]; then
  weakened=0
  while read -r want path; do
    [[ -z "${path:-}" ]] && continue
    if [[ ! -f "$path" ]]; then fail "fixture test file removed: $path (had $want assertion lines)"; weakened=1; continue; fi
    have=$(grep -c 't\.\(Fatal\|Error\)' "$path" 2>/dev/null || true)
    if (( have < want )); then fail "assertions weakened in $path: $have < $want"; weakened=1; fi
  done < "$baseline"
  (( weakened )) || ok "no fixture test lost assertion lines ($(count_lines < "$baseline") files vs assertion-counts.txt)"
else
  note "assertion baseline $baseline not available — skipped"
fi

# ---------------------------------------------------------------- NOTES
note "sms files by find (placement, any depth): $(find internal cmd -type f -iname '*sms*.go' 2>/dev/null | tr '\n' ' ')"
if [[ -f "$trace" ]] && command -v python3 >/dev/null 2>&1; then
  python3 - "$trace" "$EVAL_OUT/design-plan.txt" <<'PY' && note "DESIGN PLAN block(s) extracted to $EVAL_OUT/design-plan.txt (human review only: postcheck runs after the llm graders)"
import json, sys
src, dst = sys.argv[1], sys.argv[2]
plans = []
with open(src, encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") != "assistant":
            continue
        for block in (ev.get("message") or {}).get("content") or []:
            text = block.get("text") if isinstance(block, dict) else None
            if text and "DESIGN PLAN" in text:
                plans.append(text)
with open(dst, "w", encoding="utf-8") as out:
    out.write("\n\n=====\n\n".join(plans) if plans else "(no assistant text block contains 'DESIGN PLAN')\n")
PY
fi

finish
