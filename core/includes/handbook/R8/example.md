```text
# ❌ reached sideways from three layers; untestable without the environment
config = loadConfig()              # module level: runs at import, read from a leaf
Fleet.record(hb):
    if config.readOnly: ...

# ✅ read once at the composition root, pushed down as a value
main():
    config = loadConfig()
    run(device.newFleet(store, config.fleet))
```

> **Spelling:** silent everywhere: constants, enums, the module's logger, the
> error or exception types. Silent only at the composition root, the entry point,
> handler setup or application wiring: reading the environment, building the
> framework's app object, filling a registry by hand, starting the event loop.
> Reported elsewhere: an environment read, a module-level container that functions
> write into, an import-time or static initializer that writes state, library code
> that manufactures its own cancellation root. A test that mutates production
> configuration to run is evidence against the production code, not a fix for the
> test.
