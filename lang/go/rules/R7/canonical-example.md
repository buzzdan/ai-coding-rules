### Before — anti-patterns stacked

```go
package user // same package — can reach privates

func TestValidateEmailInternal(t *testing.T) { // testing a private
    assert.True(t, validateEmailInternal("test@example.com"))
}

func TestCreateUser(t *testing.T) { // doubles instead of collaborators
    mockRepo := &MockRepository{}
    mockRepo.On("Save", mock.Anything).Return(nil)

    svc := &UserService{Repo: mockRepo} // literal construction, no constructor
    err := svc.CreateUser("123", "test@example.com")
    assert.NoError(t, err)
    mockRepo.AssertExpectations(t) // asserts on the fake, not on behavior
}

func TestAsyncOperation(t *testing.T) {
    go doAsyncWork()
    time.Sleep(100 * time.Millisecond) // flaky
    assert.True(t, workCompleted)
}
```

### After — right rung, real collaborators, observable behavior

```go
package user_test // external package — public API only

func TestService_CreateUser(t *testing.T) {
    repo := user.NewInMemoryRepository() // real implementation, fake data
    emailer := user.NewTestEmailer()

    svc, err := user.NewUserService(repo, emailer)
    require.NoError(t, err)

    err = svc.CreateUser(context.Background(), testUser)
    require.NoError(t, err)

    retrieved, err := svc.GetUser(context.Background(), testUser.ID) // verify via public API
    require.NoError(t, err)
    assert.Equal(t, testUser.Email, retrieved.Email)
}

func TestAsyncOperation(t *testing.T) {
    done := make(chan struct{})
    go func() { doAsyncWork(); close(done) }()

    select {
    case <-done:
    case <-time.After(1 * time.Second):
        t.Fatal("timeout waiting for async work")
    }
}
```

Email validation itself is a leaf behavior — it belongs one rung down, as a unit
test on `ParseEmail` with literal strings, not inside the service test and not as a
private-function test.
