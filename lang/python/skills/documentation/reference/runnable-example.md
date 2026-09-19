#### ✅ Inline Runnable Example
```python
# Create validated types — each raises ValueError on invalid input
user_id = user.UserId.parse("usr_12345")
email = user.Email.parse("alice@example.com")

# Create and use the service
service = user.UserService(repo=repo, notifier=notifier)
service.create_user(user.User(id=user_id, email=email, name="Alice"))
```
