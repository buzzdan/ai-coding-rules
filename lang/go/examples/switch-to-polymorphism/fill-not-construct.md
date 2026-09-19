Note the method signature: `fillUpdate(req *updateExportRequest)`, not
`ToUpdateRequest() updateExportRequest`. The request carries fields the patch does
not own — `Name`, `Type`, TLS come from the surrounding argument. A constructor
method would either return a partial request the caller must merge (field-by-field
merging re-creates the original mess) or need the rest of the argument passed in
(the patch learns about its container). Filling keeps ownership honest: the caller
owns the shared fields, each patch owns its own.
