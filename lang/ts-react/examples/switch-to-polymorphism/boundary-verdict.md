In that situation the `switch (patch.kind)` at the page's boundary is idiomatic
TypeScript — the honest tax of keeping the shared client transport-ignorant, and
precisely the boundary-adapter exemption in R11's falsifying questions. `Patch` stays
the discriminated union it was in the before; narrowing on `kind` is what the page
needs. Then, and only then, the "tempting wrong fix" above becomes the right ceiling:
shrink the page's `fillUpdate(req, patch)` to pure dispatch (one `fillKafka(req,
patch)`-style converter per case, zero inline field-fiddling), close it with
`default: assertNever(patch)`, and stop.
