```text
# ❌ made public by the feature package only so the test can reach it
public parseCIDRList(raw)          # one caller, in this package

# ✅ rung 1: hidden where it is used, tested through the public API that calls it
parseCIDRList(raw)                 # private to the feature

# ✅ rung 3: networking vocabulary with three callers → its own package, named for the domain
networking.parsePrefixes(raw)      # public, with the Prefixes type beside it
```

> **Spelling:** rung 1 is the language's private form: a lower-case or underscored
> name, a symbol the module does not export, a file-local declaration. Rung 2 is a
> sub-package, sub-module or namespace under the feature; rung 3 a shared package
> under the source root. A test that has to reach a private name, through a friend
> module, a reflection helper or a test-only export, is a placement signal, never a
> reason to add the seam. The `"weka-api"` port name is feature policy and stays in
> the feature; `Port`, `Ports` and `firstNamed` are networking vocabulary and move.
