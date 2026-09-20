### H2 — Errors carry the context of the layer that saw them

Handle an error once: wrap it with the context of the boundary it crossed and its
cause, or handle it, never both log it and pass it on. Catch narrowly, the failure you
can handle, never everything. Failure vocabulary belongs to the package that raises
it: one named error per thing that can go wrong, made public only when a caller
decides on it.
