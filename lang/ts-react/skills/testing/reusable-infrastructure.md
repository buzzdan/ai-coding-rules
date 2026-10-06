Build shared test infrastructure in `src/test-utils/` (`setup.ts` starts MSW and
registers the jest-dom matchers; `mocks/server.ts` is the one `setupServer`;
`mocks/handlers/<domain>.ts` per API domain; `renderWithProviders.tsx`; `factories.ts`):
- MSW handlers per domain (`devicesHandlers` plus named overrides such as `devicesErrorHandler`, `emptyDevicesHandler`), in-memory stores, data factories (`makeDevice(overrides)`)
- Reusable across all test levels
- Test the infrastructure itself!
- Can serve the dev server as a mock backend (`msw/browser`) for manual testing

**Dependency Priority** (choose appropriate level):
1. **In-memory** (fastest): pure TypeScript, MSW handlers in the test process, an in-memory store, fake timers - use when testing your code's logic
2. **Binary** (isolated): the real API started as a child process (`child_process.spawn`), or its recorded exchange replayed by MSW - use when testing against a real service
3. **Test-containers** (realistic): programmatic Docker from the test (`testcontainers`) for the API and its database - use when you need real external services
4. **Docker-compose** (full stack): For complex multi-service scenarios, usually behind the Playwright run

Choose based on what you're testing, not dogmatically. In-memory is fastest but sometimes you need real services.

See reference.md for the Testing Library and MSW catalogue.
