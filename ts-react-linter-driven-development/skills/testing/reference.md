# Testing Reference (Jest + React Testing Library)

## Core Philosophy

**"The more your tests resemble the way your software is used, the more confidence they can give you."** - Kent C. Dodds

### Test user behavior, not implementation details

**Implementation detail**: Internal state, methods, component lifecycle
**User behavior**: What users see, click, type, and read

## Query Priority

Always use queries in this priority order:

### 1. Accessible queries (Preferred)

**getByRole** - Most preferred, tests accessibility
```typescript
// Buttons
screen.getByRole('button', { name: /submit/i })
screen.getByRole('button', { name: /cancel/i })

// Links
screen.getByRole('link', { name: /home/i })

// Inputs
screen.getByRole('textbox', { name: /email/i })
screen.getByRole('textbox', { name: /password/i })

// Checkboxes
screen.getByRole('checkbox', { name: /remember me/i })

// Headings
screen.getByRole('heading', { name: /welcome/i, level: 1 })

// Lists
screen.getByRole('list')
screen.getAllByRole('listitem')

// Dialogs/Modals
screen.getByRole('dialog')
screen.getByRole('alertdialog')
```

**getByLabelText** - Great for forms
```typescript
screen.getByLabelText(/email address/i)
screen.getByLabelText(/password/i)

// With exact match
screen.getByLabelText('Email Address', { exact: false })
```

### 2. Semantic queries

**getByPlaceholderText**
```typescript
screen.getByPlaceholderText(/enter your email/i)
```

**getByText**
```typescript
screen.getByText(/welcome back/i)
screen.getByText(/loading/i)

// Partial match
screen.getByText(/welcome/i) // Matches "Welcome back!"
```

**getByDisplayValue** - For form fields with values
```typescript
screen.getByDisplayValue(/john@example.com/i)
```

### 3. Test IDs (Last resort)

Only use when accessibility queries don't work:
```typescript
screen.getByTestId('custom-complex-component')
```

## Query Variants

### get* - Element must exist
```typescript
// Throws if not found
const button = screen.getByRole('button')
```

### query* - Element may not exist
```typescript
// Returns null if not found
const button = screen.queryByRole('button')
expect(button).not.toBeInTheDocument()
```

### find* - Element appears asynchronously
```typescript
// Returns promise, waits up to 1000ms by default
const button = await screen.findByRole('button')
```

### getAll*, queryAll*, findAll* - Multiple elements
```typescript
const items = screen.getAllByRole('listitem')
expect(items).toHaveLength(5)
```

## User Interactions (user-event)

Always use `@testing-library/user-event` over fireEvent:

```typescript
import userEvent from '@testing-library/user-event'

// Setup user (required in v14+)
const user = userEvent.setup()

// Click
await user.click(element)
await user.dblClick(element)
await user.tripleClick(element)

// Type
await user.type(input, 'Hello World')
await user.clear(input)

// Keyboard
await user.keyboard('{Enter}')
await user.keyboard('{Escape}')
await user.tab()

// Hover
await user.hover(element)
await user.unhover(element)

// Select
await user.selectOptions(select, 'option1')

// Upload file
const file = new File(['hello'], 'hello.txt', { type: 'text/plain' })
await user.upload(input, file)

// Copy/paste
await user.copy()
await user.paste('clipboard content')
```

## Async Testing

### waitFor - Wait for condition

```typescript
import { waitFor } from '@testing-library/react'

// Wait for element to appear
await waitFor(() => {
  expect(screen.getByText(/success/i)).toBeInTheDocument()
})

// Wait for element to disappear
await waitFor(() => {
  expect(screen.queryByText(/loading/i)).not.toBeInTheDocument()
})

// Custom timeout (default: 1000ms)
await waitFor(
  () => {
    expect(screen.getByText(/loaded/i)).toBeInTheDocument()
  },
  { timeout: 3000 }
)

// Custom interval (default: 50ms)
await waitFor(
  () => {
    expect(screen.getByText(/loaded/i)).toBeInTheDocument()
  },
  { interval: 100 }
)
```

### findBy - Shorthand for waitFor + getBy

```typescript
// Instead of:
await waitFor(() => {
  expect(screen.getByText(/loaded/i)).toBeInTheDocument()
})

// Use:
await screen.findByText(/loaded/i)

// They're equivalent, but findBy is more concise
```

### ❌ DON'T use arbitrary timeouts

```typescript
// ❌ Bad: Arbitrary wait
await new Promise(resolve => setTimeout(resolve, 1000))

// ✅ Good: Wait for specific condition
await waitFor(() => {
  expect(screen.getByText(/loaded/i)).toBeInTheDocument()
})
```

## MSW (Mock Service Worker)

### Setup

```typescript
// src/test/mocks/handlers.ts
import { rest } from 'msw'

export const handlers = [
  rest.get('/api/users', (req, res, ctx) => {
    return res(
      ctx.status(200),
      ctx.json([
        { id: '1', name: 'Alice', email: 'alice@example.com' },
        { id: '2', name: 'Bob', email: 'bob@example.com' }
      ])
    )
  }),

  rest.post('/api/users', (req, res, ctx) => {
    const newUser = req.body
    return res(
      ctx.status(201),
      ctx.json({ id: '3', ...newUser })
    )
  }),

  rest.get('/api/users/:id', (req, res, ctx) => {
    const { id } = req.params
    return res(
      ctx.status(200),
      ctx.json({ id, name: 'Alice', email: 'alice@example.com' })
    )
  })
]

// src/test/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)

// src/test/setup.ts (imported in Jest config)
import '@testing-library/jest-dom'
import { server } from './mocks/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

### Override handlers in tests

```typescript
import { rest } from 'msw'
import { server } from '@/test/mocks/server'

test('handles server error', async () => {
  // Override for this test only
  server.use(
    rest.get('/api/users', (req, res, ctx) => {
      return res(
        ctx.status(500),
        ctx.json({ message: 'Internal server error' })
      )
    })
  )

  render(<UserList />)

  expect(await screen.findByText(/error loading users/i)).toBeInTheDocument()
})
```

## Testing Patterns

### Pattern: Form Submission

```typescript
test('submits form with valid data', async () => {
  const user = userEvent.setup()
  const onSubmit = jest.fn()

  render(<ContactForm onSubmit={onSubmit} />)

  // Fill form
  await user.type(screen.getByLabelText(/name/i), 'John Doe')
  await user.type(screen.getByLabelText(/email/i), 'john@example.com')
  await user.type(screen.getByLabelText(/message/i), 'Hello world')

  // Submit
  await user.click(screen.getByRole('button', { name: /submit/i }))

  // Assert
  expect(onSubmit).toHaveBeenCalledWith({
    name: 'John Doe',
    email: 'john@example.com',
    message: 'Hello world'
  })
})

test('shows validation errors for invalid email', async () => {
  const user = userEvent.setup()

  render(<ContactForm onSubmit={jest.fn()} />)

  await user.type(screen.getByLabelText(/email/i), 'invalid-email')
  await user.click(screen.getByRole('button', { name: /submit/i }))

  expect(screen.getByText(/invalid email address/i)).toBeInTheDocument()
})
```

### Pattern: Data Fetching

```typescript
test('loads and displays user data', async () => {
  render(<UserProfile userId='123' />)

  // Loading state
  expect(screen.getByText(/loading/i)).toBeInTheDocument()

  // Wait for data to load
  expect(await screen.findByText(/alice/i)).toBeInTheDocument()

  // Loading indicator gone
  expect(screen.queryByText(/loading/i)).not.toBeInTheDocument()
})

test('handles loading error', async () => {
  server.use(
    rest.get('/api/users/:id', (req, res, ctx) => {
      return res(ctx.status(404), ctx.json({ message: 'User not found' }))
    })
  )

  render(<UserProfile userId='999' />)

  expect(await screen.findByText(/user not found/i)).toBeInTheDocument()
})
```

### Pattern: Component with Context

```typescript
// Test helper
function renderWithProviders(
  ui: React.ReactElement,
  {
    initialAuth = null,
    theme = 'light'
  } = {}
) {
  return render(
    <AuthProvider initialUser={initialAuth}>
      <ThemeProvider initialTheme={theme}>
        {ui}
      </ThemeProvider>
    </AuthProvider>
  )
}

test('shows user menu when authenticated', () => {
  const user = { id: '1', name: 'Alice', email: 'alice@example.com' }

  renderWithProviders(<Navigation />, { initialAuth: user })

  expect(screen.getByText(/alice/i)).toBeInTheDocument()
  expect(screen.getByRole('button', { name: /logout/i })).toBeInTheDocument()
})

test('shows login button when not authenticated', () => {
  renderWithProviders(<Navigation />)

  expect(screen.getByRole('button', { name: /login/i })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: /logout/i })).not.toBeInTheDocument()
})
```

### Pattern: Custom Hooks

```typescript
import { renderHook, waitFor } from '@testing-library/react'

test('useDebounce delays value update', async () => {
  jest.useFakeTimers()

  const { result, rerender } = renderHook(
    ({ value, delay }) => useDebounce(value, delay),
    { initialProps: { value: 'initial', delay: 500 } }
  )

  expect(result.current).toBe('initial')

  // Update value
  rerender({ value: 'updated', delay: 500 })

  // Still old value
  expect(result.current).toBe('initial')

  // Fast-forward time
  jest.advanceTimersByTime(500)

  // Now updated
  await waitFor(() => {
    expect(result.current).toBe('updated')
  })

  jest.useRealTimers()
})
```

### Pattern: Testing Hooks with Dependencies

```typescript
function renderHookWithProviders<T>(
  hook: () => T,
  {
    initialAuth = null
  } = {}
) {
  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <AuthProvider initialUser={initialAuth}>
      {children}
    </AuthProvider>
  )

  return renderHook(hook, { wrapper })
}

test('useAuth returns current user', () => {
  const user = { id: '1', name: 'Alice' }

  const { result } = renderHookWithProviders(
    () => useAuth(),
    { initialAuth: user }
  )

  expect(result.current.user).toEqual(user)
  expect(result.current.isAuthenticated).toBe(true)
})
```

### Pattern: Modal/Dialog

```typescript
test('opens and closes modal', async () => {
  const user = userEvent.setup()

  render(<ModalExample />)

  // Modal not visible initially
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()

  // Open modal
  await user.click(screen.getByRole('button', { name: /open modal/i }))

  // Modal visible
  const modal = screen.getByRole('dialog')
  expect(modal).toBeInTheDocument()
  expect(within(modal).getByText(/modal content/i)).toBeInTheDocument()

  // Close modal (via close button)
  await user.click(within(modal).getByRole('button', { name: /close/i }))

  // Modal hidden
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})

test('closes modal on escape key', async () => {
  const user = userEvent.setup()

  render(<ModalExample />)

  await user.click(screen.getByRole('button', { name: /open modal/i }))
  expect(screen.getByRole('dialog')).toBeInTheDocument()

  // Press escape
  await user.keyboard('{Escape}')

  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})
```

### Pattern: Lists and Filtering

```typescript
test('filters users by search term', async () => {
  const user = userEvent.setup()

  render(<UserList />)

  // Wait for users to load
  await waitFor(() => {
    expect(screen.getAllByRole('listitem')).toHaveLength(10)
  })

  // Type in search
  await user.type(screen.getByRole('textbox', { name: /search/i }), 'alice')

  // Wait for filtered results
  await waitFor(() => {
    const items = screen.getAllByRole('listitem')
    expect(items).toHaveLength(1)
    expect(within(items[0]).getByText(/alice/i)).toBeInTheDocument()
  })
})
```

### Pattern: Navigation (React Router)

```typescript
import { MemoryRouter, Route, Routes } from 'react-router-dom'

function renderWithRouter(
  ui: React.ReactElement,
  { initialEntries = ['/'] } = {}
) {
  return render(
    <MemoryRouter initialEntries={initialEntries}>
      <Routes>
        <Route path='/' element={<HomePage />} />
        <Route path='/users/:id' element={ui} />
        <Route path='/login' element={<LoginPage />} />
      </Routes>
    </MemoryRouter>
  )
}

test('navigates to user profile on click', async () => {
  const user = userEvent.setup()

  renderWithRouter(<UserList />)

  // Click user link
  await user.click(screen.getByRole('link', { name: /alice/i }))

  // Assert navigation occurred (check URL-dependent content)
  expect(await screen.findByRole('heading', { name: /alice's profile/i })).toBeInTheDocument()
})
```

### Pattern: Error Boundaries

```typescript
test('error boundary catches component errors', () => {
  // Suppress console.error for this test
  const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

  const ThrowError = () => {
    throw new Error('Test error')
  }

  render(
    <ErrorBoundary fallback={<div>Something went wrong</div>}>
      <ThrowError />
    </ErrorBoundary>
  )

  expect(screen.getByText(/something went wrong/i)).toBeInTheDocument()

  consoleSpy.mockRestore()
})
```

## Coverage Targets

The architecture principle: **Push logic into leaf types for maximum testability**. Strive to have most of your business logic in small, focused, dependency-free leaf components/hooks/functions.

### Leaf Components/Hooks/Functions

**Definition**: Pure, self-contained units with **no external dependencies** (no API calls, database access, file system). They contain core business logic and can freely compose other leaf types.

**Key Characteristics**:
- ✅ **Can depend on other leaf types** - Domain types composing domain types (e.g., `Order` uses `Money`, `ShippingAddress`)
- ❌ **Cannot depend on external systems** - No API calls, database access, file system operations
- ✅ **Deterministic** - Same input always gives same output
- ✅ **No side effects** - Pure functions or immutable objects
- ✅ **Testable without mocks** - Just instantiate and test

**Examples**:
- **Branded types**: `Email`, `UserId`, `Price` with validation
- **Domain models**: `Order`, `Money`, `ShippingAddress` (can use other leaf types)
- **Validation functions**: `validateEmail()`, `parseDate()`
- **Custom hooks (pure)**: `useValidation()`, `useDebounce()`, `useLocalStorage()`
- **Utility functions**: `formatCurrency()`, `parseAddress()`
- **Presentational components**: `Button`, `Card`, `Input` (UI-only, no business logic)

**Coverage Target**: **100% unit test coverage**

**Why**:
- Leaf types contain core business logic and must be bulletproof
- No external dependencies means easy to test in isolation (no mocks needed)
- High confidence in these building blocks enables safe composition
- Most bugs happen in complex logic - leaf types isolate that complexity

**How to test**:
- Test only the public API (exports)
- Use real implementations, not mocks
- Cover happy path, edge cases, and error cases
- For hooks: Test with `@testing-library/react-hooks` or render in test component
- For components: Use React Testing Library with user-centric tests

**Example - Leaf Hook**:
```typescript
// useDebounce.ts - Pure hook with no dependencies
export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value)

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay)
    return () => clearTimeout(timer)
  }, [value, delay])

  return debouncedValue
}

// useDebounce.test.ts - 100% coverage
describe('useDebounce', () => {
  it('returns initial value immediately', () => {
    const { result } = renderHook(() => useDebounce('initial', 500))
    expect(result.current).toBe('initial')
  })

  it('updates value after delay', async () => {
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'initial', delay: 500 } }
    )

    rerender({ value: 'updated', delay: 500 })
    expect(result.current).toBe('initial') // Still old value

    await waitFor(() => {
      expect(result.current).toBe('updated') // Now updated
    }, { timeout: 600 })
  })

  it('cancels pending update on unmount', () => {
    const { result, unmount } = renderHook(() => useDebounce('value', 500))
    unmount()
    // No error should be thrown
  })
})
```

**Example - Leaf Types Composing Other Leaf Types**:
```typescript
// All leaf types - can freely compose each other
class Money {
  constructor(private readonly cents: number) {}

  add(other: Money): Money {
    return new Money(this.cents + other.cents)
  }

  multiply(factor: number): Money {
    return new Money(Math.round(this.cents * factor))
  }
}

class ShippingAddress {
  constructor(
    readonly street: string,
    readonly city: string
  ) {}

  isRemoteLocation(): boolean {
    return this.city === 'Remote'
  }
}

class Order {
  constructor(
    private items: CartItem[],
    private shipping: ShippingAddress  // ✅ Leaf using another leaf
  ) {}

  calculateTotal(): Money {  // ✅ Returns a leaf type
    const subtotal = this.items.reduce(
      (sum, item) => sum.add(Money.dollars(item.price)),
      Money.dollars(0)
    )

    const shippingCost = this.shipping.isRemoteLocation()
      ? Money.dollars(15)
      : Money.dollars(5)

    return subtotal.add(shippingCost)
  }
}

// Testing is trivial - no mocks needed!
describe('Order', () => {
  it('calculates total with shipping', () => {
    const order = new Order(
      [{ price: 100 }],
      new ShippingAddress('123 Main', 'Springfield')
    )
    expect(order.calculateTotal()).toEqual(Money.dollars(105))
  })

  it('adds remote shipping for remote locations', () => {
    const order = new Order(
      [{ price: 100 }],
      new ShippingAddress('456 Main', 'Remote')
    )
    expect(order.calculateTotal()).toEqual(Money.dollars(115))
  })
})
```

**Example - NOT Leaf Types (External Dependencies)**:
```typescript
// NOT a leaf - depends on external API
class OrderService {
  constructor(private api: ApiClient) {}  // ❌ External dependency

  async fetchOrder(id: string): Promise<Order> {
    return this.api.get(`/orders/${id}`)  // ❌ API call
  }

  async saveOrder(order: Order): Promise<void> {
    await this.api.post('/orders', order)  // ❌ API call
  }
}

// NOT a leaf - depends on database
class OrderRepository {
  constructor(private db: Database) {}  // ❌ External dependency

  async findById(id: string): Promise<Order> {
    return this.db.query('SELECT * FROM orders WHERE id = ?', [id])  // ❌ DB access
  }
}

// NOT a leaf - custom hook that fetches data
function useOrder(orderId: string) {
  const [order, setOrder] = useState<Order | null>(null)

  useEffect(() => {
    fetch(`/api/orders/${orderId}`)  // ❌ API call
      .then(res => res.json())
      .then(setOrder)
  }, [orderId])

  return order
}

// Testing these requires mocks or test servers (integration tests)
```

**Key Insight**: Complex domain models like `Order`, `Money`, `ShippingAddress` are ALL leaf types because they're pure logic. They can compose each other freely. The boundary is **external systems**, not other application types.

### Orchestrating Components/Functions

**Definition**: Coordinate multiple leaf types, hooks, or services. They compose smaller pieces but contain minimal logic themselves.

**Examples**:
- **Feature components**: `UserProfile`, `LoginForm`, `CheckoutFlow`
- **Page components**: `HomePage`, `DashboardPage`
- **Context providers**: `AuthProvider`, `ThemeProvider`
- **Container components**: Connect data (hooks/APIs) to presentation
- **Coordinator functions**: `processCheckout()` that calls multiple services

**Coverage Target**: **Integration test coverage**

**Why**:
- Test seams and interactions between leaf types
- Verify correct composition and data flow
- Can have some overlap with leaf type coverage
- Focus on behavior from user perspective

**How to test**:
- Test entire feature flows
- Use MSW (Mock Service Worker) for API calls
- Test user interactions with `userEvent`
- Verify multiple components working together
- Test loading/error/success states

**Example - Orchestrating Component**:
```typescript
// LoginForm.tsx - Orchestrates multiple pieces
export function LoginForm() {
  const { login } = useAuth()  // Leaf hook
  const { validateEmail } = useValidation()  // Leaf hook
  const navigate = useNavigate()

  const handleSubmit = async (email: string, password: string) => {
    if (!validateEmail(email)) return
    await login(email, password)
    navigate('/dashboard')
  }

  return <LoginFormView onSubmit={handleSubmit} />
}

// LoginForm.test.tsx - Integration test (not 100% coverage required)
test('successful login navigates to dashboard', async () => {
  const user = userEvent.setup()

  // Mock API
  server.use(
    http.post('/api/login', () => {
      return HttpResponse.json({ token: 'abc123' })
    })
  )

  render(<LoginForm />)

  await user.type(screen.getByLabelText(/email/i), 'user@example.com')
  await user.type(screen.getByLabelText(/password/i), 'password123')
  await user.click(screen.getByRole('button', { name: /sign in/i }))

  // Verify navigation happened
  await waitFor(() => {
    expect(window.location.pathname).toBe('/dashboard')
  })
})
```

### Architectural Benefits

When you follow this pattern:
1. **Easier testing**: Leaf types are trivial to test (100% coverage achievable)
2. **Better composition**: Small, focused pieces are easier to combine
3. **Easier refactoring**: Changes isolated to leaf types
4. **Lower cognitive load**: Each piece has single responsibility
5. **Reusability**: Leaf types naturally reusable across features

**Anti-pattern**: Putting complex business logic directly in orchestrating components makes testing hard and coupling high. Always extract to leaf types.

### Coverage Strategy Summary

| Type | Coverage Target | Test Approach | Example |
|------|----------------|---------------|---------|
| Leaf | 100% unit tests | Isolated, no mocks | `useDebounce()`, `Email` type, `Button` |
| Orchestrating | Integration tests | User flows, MSW | `LoginForm`, `UserProfile`, `AuthProvider` |

## Jest Matchers (jest-dom)

Common assertions from `@testing-library/jest-dom`:

```typescript
// Presence
expect(element).toBeInTheDocument()
expect(element).not.toBeInTheDocument()

// Visibility
expect(element).toBeVisible()
expect(element).not.toBeVisible()

// Enabled/Disabled
expect(button).toBeEnabled()
expect(button).toBeDisabled()

// Form values
expect(input).toHaveValue('text')
expect(checkbox).toBeChecked()
expect(checkbox).not.toBeChecked()

// Text content
expect(element).toHaveTextContent('Hello')
expect(element).toHaveTextContent(/hello/i)

// Attributes
expect(element).toHaveAttribute('href', '/home')
expect(element).toHaveClass('active')
expect(element).toHaveStyle({ color: 'red' })

// Focus
expect(input).toHaveFocus()

// Accessibility
expect(button).toHaveAccessibleName('Submit')
expect(button).toHaveAccessibleDescription('Submit the form')
```

## Coverage Configuration

**jest.config.js**:
```javascript
module.exports = {
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.tsx',
    '!src/test/**',
    '!src/index.tsx'
  ],
  coverageThresholds: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    },
    // Pure components/hooks: 100%
    './src/shared/components/**/*.{ts,tsx}': {
      branches: 100,
      functions: 100,
      lines: 100,
      statements: 100
    },
    './src/shared/hooks/**/*.{ts,tsx}': {
      branches: 100,
      functions: 100,
      lines: 100,
      statements: 100
    }
  }
}
```

## Best Practices Summary

### ✅ DO

- Test user behavior, not implementation
- Use accessible queries (getByRole, getByLabelText)
- Use user-event for interactions
- Use MSW for API mocking
- Wait for conditions with waitFor/findBy
- Colocate tests with components
- Write descriptive test names
- Test error scenarios
- Test loading states
- Test accessibility

### ❌ DON'T

- Test implementation details (state, lifecycle)
- Use shallow rendering
- Use arbitrary timeouts (setTimeout)
- Test private methods
- Mock everything (prefer real implementations)
- Use getByTestId unless necessary
- Rely on snapshots for critical logic
- Write tests that depend on each other
- Ignore console errors/warnings

## Common Pitfalls

### 1. Testing implementation details

```typescript
// ❌ Bad: Testing internal state
expect(component.state.isOpen).toBe(true)

// ✅ Good: Testing user-visible behavior
expect(screen.getByRole('dialog')).toBeInTheDocument()
```

### 2. Not cleaning up

```typescript
// ❌ Bad: No cleanup between tests
afterEach(() => {
  // Test state leaks to next test
})

// ✅ Good: Proper cleanup
afterEach(() => {
  server.resetHandlers()
  jest.clearAllMocks()
})
```

### 3. Arbitrary waits

```typescript
// ❌ Bad: Arbitrary timeout
await new Promise(r => setTimeout(r, 1000))

// ✅ Good: Wait for specific condition
await waitFor(() => expect(screen.getByText(/loaded/i)).toBeInTheDocument())
```

### 4. Overusing mocks

```typescript
// ❌ Bad: Mock everything
jest.mock('./useAuth', () => ({ useAuth: () => mockAuth }))
jest.mock('./api', () => ({ fetchUser: mockFetch }))

// ✅ Good: Use real implementations with MSW
// useAuth uses real context
// API calls intercepted by MSW
```

## Testing Checklist

Before committing tests:
- [ ] Tests use accessible queries (getByRole, getByLabelText)
- [ ] User interactions use user-event, not fireEvent
- [ ] Async operations use waitFor/findBy, not setTimeout
- [ ] API calls mocked with MSW, not jest.mock
- [ ] Tests are independent (no shared state)
- [ ] Error scenarios covered
- [ ] Loading states covered
- [ ] Tests read like user stories
- [ ] No implementation details tested
- [ ] Coverage meets targets
