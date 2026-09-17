- **Mechanics**: named struct fields in every table (the linter reorders fields);
  no `time.Sleep` — channels or wait groups; testify suites only for real
  infrastructure setup, not plain unit tests; `package foo_test` so privates are
  unreachable; success and error cases in separate `TestX_Success`/`TestX_Error`
  functions, never one table with a `wantErr bool`.
