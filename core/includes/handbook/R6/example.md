```text
# ❌ one production implementer; the abstraction exists for the fake in the test
DeviceStore                        # an interface / protocol / trait with one method
    get(id)
newFleet(store: DeviceStore, config)
FakeDeviceStore                    # the ONLY other implementer, in the test file
    get(id): return self.device

# ✅ depend on the concrete type; the test wires a real store over an embedded database
newFleet(store: sqlite.DeviceStore, config)
testRecord():
    fleet = newFleet(sqlite.openDeviceStore(tempDir), config)
```

> **Spelling:** the seam is an interface, a protocol, a trait, an abstract base
> class or, in a language that patches, a `patch("service.Store")` on a concrete
> class with no declaration to search for; the one-implementer test transfers
> unchanged. An earned interface stays small and cohesive. A hand-written stand-in
> that satisfies a production abstraction only in a test file is a mock, whatever it
> is called. Faking the true external boundary is fine: the clock, a socket, the
> environment in an entry-point test.
