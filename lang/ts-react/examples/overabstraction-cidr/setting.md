During the refactor of the cluster network-settings parser (`alignCidrArgs`,
originally 60 lines mixing `URLSearchParams` string parsing, boolean flag tracking,
and triplicated `switch` arms), two booleans tracked related state:

```typescript
let isClusterCidrSet = false
let isServerCidrSet = false
// ... a parsing loop over the form's values sets them ...
if (isClusterCidrSet && isServerCidrSet) {
  return // both set, nothing to do
}
```
