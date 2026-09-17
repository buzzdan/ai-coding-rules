#### ✅ Inline Runnable Example
```text
# Create validated types — each constructor fails on invalid input,
# in the language's failure form (an error result, an exception)
id = user.NewUserID("usr_12345")
email = user.NewEmail("alice@example.com")

# Create and use the service
service = user.NewUserService(repo, notifier)
service.CreateUser(User(id, email, name="Alice"))
```