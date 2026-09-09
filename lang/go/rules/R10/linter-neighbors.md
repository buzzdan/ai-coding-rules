- **The linter owns the mechanical neighbors.** Ignored errors (`errcheck`),
  unclosed response bodies (`bodyclose`), copied locks (`govet copylocks`) — enforce
  these in `.golangci.yaml`; do not re-hunt them here.
