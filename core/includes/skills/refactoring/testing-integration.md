**MANDATORY** after creating new types or extracting functions:
1. List created types: the type, class or struct declarations among the diff's added
   lines (`git diff -U0 -- '{{.SrcGlob}}'`, added lines that declare a new type).
2. Missing tests for any of them → STOP and invoke @testing.
3. Coverage: the repository's test command with its coverage flag — leaf types must
   show 100% (R7).