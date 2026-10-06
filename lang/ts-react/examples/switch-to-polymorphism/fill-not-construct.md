Note the method signature: `fillUpdate(req: UpdateExportRequest): void`, not
`toUpdateRequest(): UpdateExportRequest`. The request carries fields the patch does
not own — `name`, `type`, TLS come from the surrounding argument. A constructor
method would either return a partial request the caller must spread together
(`{ ...base, ...patch.toUpdateRequest() }` re-creates the original mess one level up
and hides which side owns a colliding key) or need the rest of the argument passed in
(the patch learns about its container). Filling keeps ownership honest: the caller
owns the shared fields, each patch owns its own.
