### Before — interface exists only for a test fake

```go
// service.go — one prod impl (*worker.Store); the interface exists for the test
type Leaves interface {
    FindLatest(ctx context.Context, id ID) (Job, error)
}

type Service struct { leaves Leaves }

// service_test.go — the ONLY other implementer is a mock
type fakeLeaves struct{ job Job }

func (f *fakeLeaves) FindLatest(context.Context, ID) (Job, error) { return f.job, nil }
```

### After — concrete dependency, tested by wiring the real collaborator

```go
// service.go — concrete; no cycle (the worker package does not import this one)
type Service struct { leaves *worker.Store }

// service_test.go — construct the REAL Store over embedded Postgres + a fake
// (httptest) external service
func (s *Suite) TestRerun() {
    svc, _ := NewService(s.store, s.evaluator, s.jiraClient) // real objects, fake data
    // ... exercise svc's public method, assert on real state
}
```

The test now covers the seam it claims to cover: the real `Store`'s queries run
against a real database. The interface, its indirection, and the double are all
deleted.
