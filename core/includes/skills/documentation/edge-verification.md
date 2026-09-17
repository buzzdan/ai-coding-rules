then confirm the file
   still builds or imports (the repository's compile, type-check or import step).
   The gate verifies edges only in the source files its language adapter knows, so
   an edge in another language is unverifiable; report such docs as unwired instead
   of improvising.