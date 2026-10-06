**Purpose**: Top rung — black box test the entire system, critical end-to-end workflows

1. **Place in the repository's `e2e/` or `tests/` folder** - At project root, separate from `src/`; run by its Playwright (or Cypress) config, never by Vitest
2. **Test via the browser** - Playwright drives the built app at a URL; assertions are on what the user sees (`getByRole`, the URL, a download)
3. **Choose dependency level** based on what you're testing:
   - **In-memory**: Fastest, the dev server with `msw/browser` handlers or Playwright's `page.route` - use when testing your code's behavior
   - **Binary**: the real API started as a child process (`webServer` in `playwright.config.ts`) behind the built bundle
   - **Test-containers**: When you need real external services (the API and its database in Docker)
4. **Test critical workflows** - User journeys, not every edge case
5. **Run only when asked** - the skill runs the repository's e2e suite on request and never writes a new e2e test by default; a behavior goes to the lowest rung that contains it

**Example with a routed API:**
```ts
// e2e/devices.spec.ts - the built app against a routed API
import { expect, test } from '@playwright/test'

test('lists the devices of the selected cluster', async ({ page }) => {
  await page.route('**/api/clusters/c-1/devices', (route) =>
    route.fulfill({ json: { data: [{ id: 'd-1', name: 'edge-01', status: 'READY' }] } }),
  )

  await page.goto('/clusters/c-1/devices')

  await expect(page.getByRole('row', { name: /edge-01/ })).toBeVisible()
})
```

**Example with a real service process:**
```ts
// e2e/login.spec.ts - against the real API process started by playwright.config.ts
test('signs in and lands on the dashboard', async ({ page }) => {
  // `webServer` in playwright.config.ts starts the API and the built app, polls
  // their `url` until they answer (never a fixed sleep), and stops them after the run
  await page.goto('/')
  await page.getByLabel(/email/i).fill('ops@example.com')
  await page.getByRole('button', { name: /sign in/i }).click()

  await expect(page).toHaveURL(/\/dashboard$/)
})
```

See reference.md for the handlers behind the dev server and for test-containers.
