then confirm the module
   still imports (`python -c "import <module>"`) or the type check still passes
   (`ty check <file>`) — the edge is a docstring line, so the only way to break it is a
   quoting or indentation error. Python files only — the gate verifies edges in
   `.py` files alone, so an edge in another language is unverifiable; report such
   docs as unwired instead of improvising.
