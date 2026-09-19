```
main()
  └─ HTTP handlers (entry points)
       ├─ OrderService.process_order()      [USES env.CONFIG.db_host]
       │    └─ messaging.publish_event()    [USES env.CONFIG.nats_address]
       │    └─ messaging.publish_batch()    [USES env.CONFIG.nats_address]
       └─ UserService.create_user()
            └─ messaging.publish_event()    [USES env.CONFIG.nats_address]
```

The deepest usage — furthest from `main()` — is `messaging.publish_event`/
`publish_batch`. **Start there.** Bottom-up matters: extracting the leaf first means
each iteration produces a finished, testable island; top-down would thread
parameters through layers that still read globals underneath.
