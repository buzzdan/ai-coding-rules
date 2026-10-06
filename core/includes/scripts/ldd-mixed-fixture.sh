# ---------- the mixed repository: D, Python, Go and TypeScript in one tree ----------
# residue-exempt: the fixture is the same four-language tree for every plugin.
# The same fixture for every plugin: a repository with setup.cfg and go.mod at
# its root, D under weka/, Python under qa/, Go under s3/mc/, TypeScript under
# web/, a Bazel build file and a doc. mk_mixed_repo commits it; mixed_change commits a change that
# touches one file of each language plus the build file, each with one added
# comment line, so --base HEAD~1 is the mixed diff; mixed_change_d commits a
# change to the D file alone.
#
# The cases that route a group to a sibling plugin need the siblings: the test
# looks for them beside this plugin's directory (the repository checkout) and
# writes an installed-plugins file naming the ones it finds. LDD_INSTALLED_PLUGINS
# points the scripts at that file — never at the user's own.
MIXED_D="weka/management/telemetry.d"
MIXED_D_TEST="weka/management/testing/telemetry_test.d"
MIXED_PY="qa/lib/s3_bucket.py"
MIXED_PY_TEST="qa/tests/test_telemetry.py"
MIXED_GO="s3/mc/main.go"
MIXED_GO_TEST="s3/mc/main_test.go"
MIXED_TS="web/src/App.tsx"
MIXED_TS_TEST="web/src/App.test.tsx"
MIXED_BAZEL="weka/management/BUILD.bazel"

mk_mixed_repo() {
  mkdir -p "$REPO/weka/management/testing" "$REPO/qa/lib" "$REPO/qa/tests" "$REPO/s3/mc" "$REPO/web/src"
  printf '{"name": "web", "private": true}\n' > "$REPO/web/package.json"
  printf '[metadata]\nname = fixture\n' > "$REPO/setup.cfg"
  printf 'module example.com/fixture\n\ngo 1.22\n' > "$REPO/go.mod"
  cat > "$REPO/$MIXED_D" <<'D'
module weka.management.telemetry;

/// Sends one telemetry record.
void send(string record) {
    // @suppress(dscanner.suspicious.unused_parameter)
    import core.thread : Thread;
    Thread.sleep(1.seconds);
}
D
  cat > "$REPO/$MIXED_D_TEST" <<'D'
module weka.management.testing.telemetry_test;

unittest {
    import core.thread : Thread;
    Thread.sleep(10.msecs);
}
D
  cat > "$REPO/$MIXED_PY" <<'PY'
"""S3 bucket helpers."""

import time

CACHE: dict[str, str] = {}  # noqa: PLW0603


def wait(deadline: float) -> None:
    """Poll until the deadline."""
    while time.monotonic() < deadline:
        time.sleep(1)
PY
  cat > "$REPO/$MIXED_PY_TEST" <<'PY'
import time


def test_wait() -> None:
    time.sleep(0.01)
PY
  cat > "$REPO/$MIXED_GO" <<'GO'
package main

import "time"

var cache = map[string]string{} //nolint:gochecknoglobals // TODO

// Run polls until the deadline.
func Run(deadline time.Time) {
	for time.Now().Before(deadline) {
		time.Sleep(time.Second)
	}
}

func main() {}
GO
  cat > "$REPO/$MIXED_GO_TEST" <<'GO'
package main

import (
	"testing"
	"time"
)

func TestRun(t *testing.T) {
	time.Sleep(10 * time.Millisecond)
}
GO
  cat > "$REPO/$MIXED_TS" <<'TS'
// The application shell.

// eslint-disable-next-line import/no-mutable-exports
export let cache: Map<string, string> = new Map()

export async function run(deadline: number): Promise<void> {
  while (Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }
}
TS
  cat > "$REPO/$MIXED_TS_TEST" <<'TS'
import { it } from 'vitest'

it('runs', async () => {
  await new Promise((resolve) => setTimeout(resolve, 10))
})
TS
  printf 'd_library(\n    name = "management",\n    srcs = glob(["*.d"]),\n)\n' > "$REPO/$MIXED_BAZEL"
  printf '# Fixture\n' > "$REPO/README.md"
  (cd "$REPO" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)
}

mixed_change() {
  printf '// added d comment\n' >> "$REPO/$MIXED_D"
  printf '# added py comment\n' >> "$REPO/$MIXED_PY"
  printf '// added go comment\n' >> "$REPO/$MIXED_GO"
  printf '// added ts comment\n' >> "$REPO/$MIXED_TS"
  printf '# added bazel line\n' >> "$REPO/$MIXED_BAZEL"
  (cd "$REPO" && git -c user.name=t -c user.email=t@t commit -qam change)
}

mixed_change_d() {
  printf '// added d comment\n' >> "$REPO/$MIXED_D"
  (cd "$REPO" && git -c user.name=t -c user.email=t@t commit -qam change-d)
}

# The sibling plugins beside this one in the repository checkout, as an
# installed-plugins file. SIBLINGS lists the names found; SIBLING_DIR_<name>
# is not needed: the file is what the scripts read.
SIBLINGS=""
write_installed_plugins() { # <file> [<plugin name>...] — names found beside this plugin
  local f="$1" name dir first=1; shift
  SIBLINGS=""
  printf '{\n  "version": 2,\n  "plugins": {\n' > "$f"
  for name in "$@"; do
    dir=$(cd "$HERE/../../$name" 2>/dev/null && pwd) || continue
    [[ -f "$dir/scripts/ldd-scope.sh" || -d "$dir/skills" ]] || continue
    (( first )) || printf ',\n' >> "$f"
    first=0
    printf '    "%s@ai-coding-rules": [\n      {\n        "scope": "user",\n        "installPath": "%s",\n        "version": "test"\n      }\n    ]' "$name" "$dir" >> "$f"
    SIBLINGS="$SIBLINGS $name"
  done
  printf '\n  }\n}\n' >> "$f"
  SIBLINGS="${SIBLINGS# }"
}
have_sibling() { case " $SIBLINGS " in *" $1 "*) return 0 ;; esac; return 1; }
