### Before — anti-patterns stacked

```text
# same module as the code under test — can reach privates
testValidateEmailInternal():                 # testing a private
    assert validateEmailInternal("test@example.com")

testCreateUser():                            # doubles instead of collaborators
    mockRepo = Mock()
    mockRepo.save.returns(ok)
    service = UserService(repo = mockRepo)   # literal construction, no constructor
    service.createUser("123", "test@example.com")
    mockRepo.save.assertCalled()             # asserts on the fake, not on behavior

testAsyncOperation():
    startAsyncWork()
    sleep(100 ms)                            # flaky
    assert workCompleted
```

### After — right rung, real collaborators, observable behavior

```text
# imported as a consumer would — public API only
testService_CreateUser():
    repo = user.newInMemoryRepository()      # real implementation, fake data
    emailer = user.newTestEmailer()
    service = user.newUserService(repo, emailer)   # fails → the test fails here

    service.createUser(testUser)
    retrieved = service.getUser(testUser.id) # verify via public API
    assert retrieved.email == testUser.email

testAsyncOperation():
    done = an event the work signals when it finishes
    startAsyncWork(then: done.set())
    assert done.wait(timeout = 1 s)          # a timeout, never a fixed pause
```

Email validation itself is a leaf behavior — it belongs one rung down, as a unit
test on `parseEmail` with literal strings, not inside the service test and not as a
private-function test.
