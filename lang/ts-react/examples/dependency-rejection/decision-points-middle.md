2. **The endpoint is pragmatic, not zero.** Configuration at `main.tsx` and the
   provider at the root of the tree is acceptable — that is where it legitimately
   lives, read once from `import.meta.env` and `window.__RUNTIME_ENV__` into an
   `AppConfig`. Configuration in services, hooks and components is not. React context
   is the composition mechanism, not a second global: the provider sits at the root,
   the value is built once, consumers ask through `useServices()` and a test supplies
   its own. The goal is globals only where wiring happens.
3. **Don't "fix" the globals that aren't broken.** Constants, `as const` enums, types,
   pure functions, the `createContext` key and styles stay. Spending iterations
   pushing a constant through context is ceremony, not rejection.
