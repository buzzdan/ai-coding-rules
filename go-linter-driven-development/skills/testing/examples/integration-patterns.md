# Integration Test Patterns

## Purpose

Integration tests verify that components work together correctly. They test the seams between packages, ensure proper data flow, and validate that integrated components behave as expected.

**When to Write**: After unit testing individual components, test how they interact.

## File Organization

### Option 1: In Package with Build Tags (Preferred)

```go
//go:build integration

package user_test

import (
    "testing"
    "myproject/internal/testutils"
)

func TestUserService_Integration(t *testing.T) {
    // Integration test
}
```

### Option 2: Separate Package

```
user/
├── user.go
├── user_test.go              # Unit tests
└── integration/
    └── user_integration_test.go  # Integration tests
```

## Pattern 1: Service + Repository (In-Memory)

**Use when**: Testing service logic with data persistence

```go
//go:build integration

package user_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/require"
    "myproject/user"
)

func TestUserService_CreateAndRetrieve(t *testing.T) {
    // Setup: In-memory repository (Level 1)
    repo := user.NewInMemoryRepository()
    svc := user.NewUserService(repo, nil)

    ctx := context.Background()

    // Create user
    userID, _ := user.NewUserID("usr_123")
    email, _ := user.NewEmail("alice@example.com")
    newUser := user.User{
        ID:    userID,
        Name:  "Alice",
        Email: email,
    }

    err := svc.CreateUser(ctx, newUser)
    require.NoError(t, err)

    // Retrieve user
    retrieved, err := svc.GetUser(ctx, userID)
    require.NoError(t, err)
    require.Equal(t, "Alice", retrieved.Name)
    require.Equal(t, email, retrieved.Email)
}
```

## Pattern 2: Testing with Real External Service

**Use when**: Need to test against real service behavior (Victoria Metrics, NATS, etc.)

```go
//go:build integration

package metrics_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/require"
    "myproject/internal/testutils"
    "myproject/metrics"
)

func TestMetricsIngest_WithVictoriaMetrics(t *testing.T) {
    // Start real Victoria Metrics (Level 2 - binary)
    vmServer, err := testutils.RunVictoriaMetricsServer()
    require.NoError(t, err)
    defer vmServer.Shutdown()

    // Create service with real dependency
    svc := metrics.NewIngester(vmServer.WriteURL())

    // Test ingestion
    err = svc.IngestMetric(context.Background(), "test_metric", 42.0)
    require.NoError(t, err)

    // Force flush and verify
    vmServer.ForceFlush(context.Background())
    results, err := testutils.QueryVictoriaMetrics(vmServer.QueryURL(), "test_metric")
    require.NoError(t, err)
    require.Len(t, results, 1)
}
```

## Pattern 3: Multi-Component Workflow

**Use when**: Testing complete workflows across multiple components

```go
//go:build integration

package workflow_test

import (
    "context"
    "testing"
    "time"

    "github.com/stretchr/testify/suite"
    "myproject/internal/testutils"
    "myproject/user"
    "myproject/notification"
)

type UserWorkflowSuite struct {
    suite.Suite
    userRepo    *user.InMemoryRepository
    emailer     *user.TestEmailer
    natsServer  *nserver.Server
    userService *user.UserService
    notifSvc    *notification.NotificationService
}

func (s *UserWorkflowSuite) SetupSuite() {
    // Setup in-memory NATS (Level 1)
    natsServer, err := testutils.RunNATsServer()
    s.Require().NoError(err)
    s.natsServer = natsServer

    // Setup components
    s.userRepo = user.NewInMemoryRepository()
    s.emailer = user.NewTestEmailer()
    s.userService = user.NewUserService(s.userRepo, s.emailer)

    natsAddr := "nats://" + natsServer.Addr().String()
    s.notifSvc = notification.NewService(natsAddr)
}

func (s *UserWorkflowSuite) TearDownSuite() {
    s.natsServer.Shutdown()
}

func (s *UserWorkflowSuite) TestCreateUser_TriggersNotification() {
    ctx := context.Background()

    // Subscribe to notifications
    received := make(chan string, 1)
    s.notifSvc.Subscribe("user.created", func(msg string) {
        received <- msg
    })

    // Create user
    userID, _ := user.NewUserID("usr_123")
    email, _ := user.NewEmail("alice@example.com")
    newUser := user.User{ID: userID, Name: "Alice", Email: email}

    err := s.userService.CreateUser(ctx, newUser)
    s.Require().NoError(err)

    // Verify notification sent
    select {
    case msg := <-received:
        s.Contains(msg, "Alice")
    case <-time.After(2 * time.Second):
        s.Fail("timeout waiting for notification")
    }

    // Verify email sent
    emails := s.emailer.SentEmails()
    s.Contains(emails, "alice@example.com")
}

func TestUserWorkflowSuite(t *testing.T) {
    suite.Run(t, new(UserWorkflowSuite))
}
```

## Dependency Priority

1. **Level 1: In-Memory** (Preferred) - httptest, in-memory maps, NATS harness
2. **Level 2: Binary** (When needed) - Victoria Metrics, standalone services
3. **Level 3: Test-containers** (Last resort) - Docker containers, slow startup

## Best Practices

### DO:
- Test seams between components
- Use in-memory implementations when possible
- Test happy path and error scenarios
- Use testify suites for complex setup
- Focus on data flow and integration points

### DON'T:
- Don't test business logic (that's unit tests)
- Don't use heavy mocking (use real implementations)
- Don't require Docker unless absolutely necessary
- Don't duplicate unit test coverage
- Don't skip cleanup (always defer)

## Running Integration Tests

```bash
# Skip integration tests (default)
go test ./...

# Run with integration tests
go test -tags=integration ./...

# Run only integration tests
go test -tags=integration ./... -run Integration

# With coverage
go test -tags=integration -coverprofile=coverage.out ./...
```

## Key Takeaways

1. **Test component interactions** - Not individual units
2. **Prefer real implementations** - Over mocks when possible
3. **Use build tags** - Keep unit tests fast
4. **Reuse testutils** - Same infrastructure across tests
5. **Test workflows** - Not just individual operations
