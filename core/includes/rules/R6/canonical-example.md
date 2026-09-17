### Before — a seam exists only for a test fake

```text
# service: one production collaborator (the worker store); the abstraction exists for the test
Leaves                       # an interface/protocol with one method: findLatest(id)
Service
    leaves: Leaves

# service test: the ONLY other implementer is a fake
FakeLeaves
    findLatest(id): return self.job
```

In a language with patching instead of interfaces the same smell reads as
`patch("service.Store.findLatest")` on a concrete class: a hand-written stand-in
substituted at the seam, and no production caller ever varies it.

### After — concrete dependency, tested by wiring the real collaborator

```text
# service: concrete; no cycle (the worker package does not import this one)
Service
    leaves: worker.Store

# service test: construct the REAL Store over an embedded database + a fake
# (in-process) external service
testRerun():
    service = newService(realStore, evaluator, ticketClient)   # real objects, fake data
    ... exercise the service's public method, assert on real state
```

The test now covers the seam it claims to cover: the real store's queries run against
a real database. The abstraction, its indirection, and the double are all deleted.
