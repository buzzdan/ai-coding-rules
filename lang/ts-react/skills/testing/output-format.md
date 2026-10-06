After writing tests:

```
TESTING COMPLETE

Unit Tests:
- src/domain/port.test.ts: 100% (4 test cases)
- src/pages/Devices/useDevices.test.tsx: 100% (4 test cases)
- src/pages/Devices/DeviceRow.test.tsx: 100% (6 test cases)

Integration Tests:
- src/pages/Devices/DevicesPage.test.tsx: 3 workflows tested
- Dependencies: devices MSW handlers, in-memory PreferencesStore, fake timers

System Tests:
- e2e/devices.spec.ts: 2 end-to-end workflows (routed API)
- e2e/login.spec.ts: 1 full sign-in workflow (real API process)
- e2e/export.spec.ts: 1 export workflow (test-containers)

Test Infrastructure:
- src/test-utils/mocks/handlers/devices.ts: devices handlers and named overrides
- src/test-utils/stores/memoryPreferencesStore.ts: in-memory PreferencesStore
- src/test-utils/renderWithProviders.tsx: QueryClientProvider + MemoryRouter wrapper

Test Execution:
$ npx vitest run                      # all tests (in-memory only)
$ npx vitest run --coverage           # with coverage
$ npx playwright test                 # system tests (where the repository has them)

All tests pass
100% coverage on leaf types

Next Steps:
1. Run linter: npx tsc --noEmit && npx eslint . --fix && npx prettier --write .
2. If linter fails → use @refactoring skill
3. If linter passes → use @pre-commit-review skill
```
