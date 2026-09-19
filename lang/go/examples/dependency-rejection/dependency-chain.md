```
main()
  └─ HTTP handlers (entry points)
       ├─ OrderService.ProcessOrder()      [USES env.Configs.DBHost]
       │    └─ messaging.PublishEvent()    [USES env.Configs.NATsAddress]
       │    └─ messaging.PublishBatch()    [USES env.Configs.NATsAddress]
       └─ UserService.CreateUser()
            └─ messaging.PublishEvent()    [USES env.Configs.NATsAddress]
```

The deepest usage — furthest from `main()` — is `messaging.PublishEvent`/
`PublishBatch`. **Start there.** Bottom-up matters: extracting the leaf first means
each iteration produces a finished, testable island; top-down would thread
parameters through layers that still read globals underneath.
