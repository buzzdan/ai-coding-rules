### Before — anti-patterns stacked

```tsx
import { validateEmailInternal } from './usersApi'          // exported only so a test can reach it
import { createUser } from '../../services/usersApi'

vi.mock('../../services/usersApi')                           // a double instead of the collaborator

it('validates an email', () => {                             // testing a private
  expect(validateEmailInternal('test@example.com')).toBe(true)
})

it('creates a user', async () => {
  const user = userEvent.setup()
  render(<CreateUserForm />)
  await user.type(screen.getByLabelText('Email'), 'test@example.com')
  await user.click(screen.getByRole('button', { name: 'Create' }))
  expect(vi.mocked(createUser)).toHaveBeenCalledTimes(1)     // asserts on the fake, not on behaviour
})

it.each([                                                    // success and error fused
  { raw: { attempts: 3, baseDelayMs: 100 }, expectError: false },
  { raw: { attempts: 0, baseDelayMs: 100 }, expectError: true },
])('parsePolicy($raw)', ({ raw, expectError }) => {
  if (expectError) {                                         // a conditional inside a case
    expect(() => parsePolicy(raw)).toThrow()
  } else {
    expect(parsePolicy(raw).attempts).toBe(3)
  }
})

it('shows the devices', async () => {
  render(<DeviceList />)
  await new Promise((resolve) => setTimeout(resolve, 100))  // flaky
  expect(screen.getByText('edge-01')).toBeInTheDocument()
})
```

### After — right rung, real collaborators, observable behaviour

```tsx
import { renderWithProviders } from '@/test-utils/renderWithProviders'
import { CreateUserForm } from './CreateUserForm'           // the page's public module, as a consumer would
import { DeviceList } from './DeviceList'
import { parsePolicy, PolicyError } from '@/retry/policy'

it('creates a user and shows it', async () => {
  const user = userEvent.setup()                             // MSW handlers answer the POST and the GET: real HTTP, fake data
  renderWithProviders(<CreateUserForm />)

  await user.type(screen.getByLabelText('Email'), TEST_USER.email)
  await user.click(screen.getByRole('button', { name: 'Create' }))

  expect(await screen.findByText(TEST_USER.email)).toBeInTheDocument()   // verify via what the user sees
})

describe('parsePolicy', () => {
  it.each([
    { name: 'plain', raw: { attempts: 3, baseDelayMs: 100 }, attempts: 3 },
    { name: 'single attempt', raw: { attempts: 1, baseDelayMs: 100 }, attempts: 1 },
  ])('accepts $name', ({ raw, attempts }) => {
    expect(parsePolicy(raw).attempts).toBe(attempts)
  })

  it.each([
    { name: 'zero attempts', raw: { attempts: 0, baseDelayMs: 100 } },
    { name: 'negative delay', raw: { attempts: 3, baseDelayMs: -1 } },
  ])('rejects $name', ({ raw }) => {
    expect(() => parsePolicy(raw)).toThrow(PolicyError)
  })
})

it('shows the devices', async () => {
  renderWithProviders(<DeviceList />)
  expect(await screen.findByText('edge-01')).toBeInTheDocument()   // waits for the real async, bounded by a timeout
})
```

Email validation itself is a leaf behaviour — it belongs one rung down, as a unit
test on `parseEmail` with literal strings, not inside the form test and not behind an
`export` added so a test could reach `validateEmailInternal`. The two `it.each`
tables are the split the rule asks for: one block asserts values, one asserts the
throw, and neither case body branches.
