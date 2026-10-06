<unit_tests_checklist>
- [ ] All unit tests import the module as a consumer would (`import { parsePort } from './port'`)
- [ ] Testing exported API only (no helper exported so a test can reach it)
- [ ] `it.each` rows carry a `name` and named fields, never bare positional arrays
- [ ] No conditionals in test bodies (complexity = 1)
- [ ] Using in-memory implementations from `src/test-utils/`
- [ ] No `setTimeout` waits (`findBy*`, `waitFor`, fake timers advanced explicitly)
- [ ] Leaf types have 100% coverage
</unit_tests_checklist>

<integration_tests_checklist>
- [ ] Test seams between a page, its hooks and `apiClient`
- [ ] Use MSW handlers or the API as a child process (avoid Docker)
- [ ] A Vitest project or `include` pattern for optional execution when the repository splits them by name (`*.integration.test.tsx` in `vitest.config.*`)
- [ ] Cover happy path and error scenarios across boundaries (`server.use(<domain>ErrorHandler)`)
- [ ] Real or test-support implementations (no `vi.mock` of an internal hook or service)
</integration_tests_checklist>

<system_tests_checklist>
- [ ] Located in `e2e/` or `tests/` at project root, under the repository's Playwright (or Cypress) config
- [ ] Black box testing through the browser (`page.getByRole`, the URL), never through component internals
- [ ] Appropriate dependency level chosen (routed API, real API process, or test-containers)
- [ ] Tests critical end-to-end workflows
- [ ] Dependencies documented (what's needed to run tests)
- [ ] CI-compatible (either fast in-memory or containerized setup)
</system_tests_checklist>

<test_infrastructure_checklist>
- [ ] Reusable handlers, stores and factories live in `src/test-utils/`; `setup.ts` only starts MSW and registers the matchers
- [ ] Test infrastructure has its own tests
- [ ] Named handlers make test setup readable (`server.use(emptyDevicesHandler)`)
- [ ] Can serve the dev server as a mock backend for manual testing
</test_infrastructure_checklist>

See reference.md for the Testing Library and MSW catalogue.
