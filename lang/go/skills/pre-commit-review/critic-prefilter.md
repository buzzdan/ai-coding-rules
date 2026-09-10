`git diff --cached -- '*.go' | grep -E '^\+.*//' | grep -vE '//(go:|nolint| Output:)'`
