```
main.tsx
  └─ <App /> routes and pages (entry points)
       ├─ useProcessOrder() → orderService.processOrder()   [USES CONFIG.apiBaseUrl]
       │    └─ natsClient.publishEvent()                    [USES CONFIG.natsUrl]
       │    └─ natsClient.publishBatch()                    [USES CONFIG.natsUrl]
       └─ useCreateUser() → userService.createUser()        [USES CONFIG.apiBaseUrl]
            └─ natsClient.publishEvent()                    [USES CONFIG.natsUrl]
```

The deepest usage — furthest from `main.tsx` — is `natsClient.publishEvent`/
`publishBatch`. **Start there.** Bottom-up matters: extracting the leaf first means
each iteration produces a finished, testable island; top-down — a `config` prop handed
down from `App` — would thread props through layers that still read the global
underneath.
