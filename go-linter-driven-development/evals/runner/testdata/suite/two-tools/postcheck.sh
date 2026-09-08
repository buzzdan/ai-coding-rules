#!/usr/bin/env bash
set -euo pipefail
test -f "$EVAL_DIR/go.mod"
test -d "$EVAL_OUT"
test "$PWD" = "$EVAL_DIR"
echo "go.mod present in $EVAL_DIR"
