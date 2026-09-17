#### ✅ Inline Runnable Example
```go
// Create validated types
id, err := user.NewUserID("usr_12345")
if err != nil {
    panic(err) // invalid ID format
}

email, err := user.NewEmail("alice@example.com")
if err != nil {
    panic(err) // invalid email format
}

// Create and use the service
svc, _ := user.NewUserService(repo, notifier)
err = svc.CreateUser(ctx, user.User{ID: id, Email: email, Name: "Alice"})
```
