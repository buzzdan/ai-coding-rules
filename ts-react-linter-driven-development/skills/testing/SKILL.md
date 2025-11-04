---
name: testing
description: Principles and patterns for writing effective React tests with Jest and React Testing Library. Use during implementation for test structure guidance, choosing test patterns, and deciding testing strategies. Emphasizes testing user behavior, not implementation details.
---

# Testing Principles (Jest + React Testing Library)

Principles and patterns for writing effective TypeScript + React tests.

## When to Use
- During implementation (tests + code in parallel)
- When testing strategy is unclear
- When structuring component or hook tests
- When choosing between test patterns

## Testing Philosophy

**Test user behavior, not implementation details**
- Test what users see and do
- Use accessible queries (getByRole, getByLabelText)
- Avoid testing internal state or methods
- Focus on public API

**Prefer real implementations over mocks**
- Use MSW (Mock Service Worker) for API mocking
- Use real hooks and contexts
- Test components with actual dependencies
- Integration-style tests over unit tests

**Coverage targets**
- Pure components/hooks: 100% coverage
- Container components: Integration tests for user flows
- Custom hooks: Test all branches and edge cases

## Workflow

### 1. Identify What to Test

**Pure Components/Hooks (Leaf types)**:
- No external dependencies
- Predictable output for given input
- Test all branches, edge cases, errors
- Aim for 100% coverage

Examples:
- Button, Input, Card (presentational components)
- useDebounce, useLocalStorage (utility hooks)
- Validation functions, formatters

**Container Components (Orchestrating types)**:
- Coordinate multiple components
- Manage state and side effects
- Test user workflows, not implementation
- Integration tests with real dependencies

Examples:
- LoginContainer, UserProfileContainer
- Feature-level components with data fetching

### 2. Choose Test Structure

**test.each() - Use when:**
- Testing same logic with different inputs
- Each test case is simple (no conditionals)
- Type-safe with TypeScript

**describe/it blocks - Use when:**
- Testing complex user flows
- Need setup/teardown per test
- Testing different scenarios

**React Testing Library Suite - Always use:**
- render() for components
- screen queries (getByRole, getByText, etc.)
- user-event for interactions
- waitFor for async operations

### 3. Write Tests Next to Implementation

```typescript
// src/features/auth/components/LoginForm.tsx
// src/features/auth/components/LoginForm.test.tsx
```

### 4. Use Real Implementations

```typescript
// ✅ Good: Real implementations
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { AuthProvider } from '../context/AuthContext'
import { LoginForm } from './LoginForm'

// MSW for API mocking (real HTTP)
import { rest } from 'msw'
import { setupServer } from 'msw/node'

const server = setupServer(
  rest.post('/api/login', (req, res, ctx) => {
    return res(ctx.json({ token: 'fake-token' }))
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

test('user can log in', async () => {
  const user = userEvent.setup()

  render(
    <AuthProvider>
      <LoginForm />
    </AuthProvider>
  )

  // Real user interactions
  await user.type(screen.getByLabelText(/email/i), 'test@example.com')
  await user.type(screen.getByLabelText(/password/i), 'password123')
  await user.click(screen.getByRole('button', { name: /log in/i }))

  // Assert on user-visible changes
  expect(await screen.findByText(/welcome/i)).toBeInTheDocument()
})
```

### 5. Avoid Common Pitfalls

- ❌ No waitFor(() => {}, { timeout: 5000 }) with arbitrary delays
- ❌ No testing implementation details (state, internal methods)
- ❌ No shallow rendering (use full render)
- ❌ No excessive mocking (use MSW for APIs)
- ❌ No getByTestId unless absolutely necessary (use accessibility queries)

## Test Patterns

### Pattern 1: Table-Driven Tests (test.each)

```typescript
import { render, screen } from '@testing-library/react'
import { Button } from './Button'

describe('Button', () => {
  test.each([
    { variant: 'primary', expectedClass: 'btn-primary' },
    { variant: 'secondary', expectedClass: 'btn-secondary' },
    { variant: 'danger', expectedClass: 'btn-danger' }
  ])('renders $variant variant with class $expectedClass', ({ variant, expectedClass }) => {
    render(<Button variant={variant} label='Click me' onClick={() => {}} />)

    const button = screen.getByRole('button', { name: /click me/i })
    expect(button).toHaveClass(expectedClass)
  })

  test.each([
    { isDisabled: true, shouldBeDisabled: true },
    { isDisabled: false, shouldBeDisabled: false }
  ])('when isDisabled=$isDisabled, button is disabled=$shouldBeDisabled',
    ({ isDisabled, shouldBeDisabled }) => {
      render(<Button label='Click me' onClick={() => {}} isDisabled={isDisabled} />)

      const button = screen.getByRole('button')
      if (shouldBeDisabled) {
        expect(button).toBeDisabled()
      } else {
        expect(button).toBeEnabled()
      }
    }
  )
})
```

### Pattern 2: Component with User Interactions

```typescript
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { SearchBox } from './SearchBox'

describe('SearchBox', () => {
  test('calls onSearch when user types and submits', async () => {
    const user = userEvent.setup()
    const onSearch = jest.fn()

    render(<SearchBox onSearch={onSearch} />)

    // Type in search box
    const input = screen.getByRole('textbox', { name: /search/i })
    await user.type(input, 'react testing')

    // Submit form
    await user.click(screen.getByRole('button', { name: /search/i }))

    // Assert callback called
    expect(onSearch).toHaveBeenCalledWith('react testing')
    expect(onSearch).toHaveBeenCalledTimes(1)
  })

  test('shows validation error for empty search', async () => {
    const user = userEvent.setup()
    const onSearch = jest.fn()

    render(<SearchBox onSearch={onSearch} />)

    // Submit without typing
    await user.click(screen.getByRole('button', { name: /search/i }))

    // Assert error message
    expect(screen.getByText(/search cannot be empty/i)).toBeInTheDocument()
    expect(onSearch).not.toHaveBeenCalled()
  })
})
```

### Pattern 3: Testing Custom Hooks

```typescript
import { renderHook, waitFor } from '@testing-library/react'
import { useUsers } from './useUsers'

// MSW setup for API
import { rest } from 'msw'
import { setupServer } from 'msw/node'

const mockUsers = [
  { id: '1', name: 'Alice', email: 'alice@example.com' },
  { id: '2', name: 'Bob', email: 'bob@example.com' }
]

const server = setupServer(
  rest.get('/api/users', (req, res, ctx) => {
    return res(ctx.json(mockUsers))
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

describe('useUsers', () => {
  test('fetches users successfully', async () => {
    const { result } = renderHook(() => useUsers())

    // Initially loading
    expect(result.current.isLoading).toBe(true)
    expect(result.current.users).toEqual([])

    // Wait for data to load
    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    // Assert users loaded
    expect(result.current.users).toEqual(mockUsers)
    expect(result.current.error).toBeNull()
  })

  test('handles error when fetch fails', async () => {
    // Override handler to return error
    server.use(
      rest.get('/api/users', (req, res, ctx) => {
        return res(ctx.status(500), ctx.json({ message: 'Server error' }))
      })
    )

    const { result } = renderHook(() => useUsers())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.users).toEqual([])
    expect(result.current.error).toBeTruthy()
  })
})
```

### Pattern 4: Testing with Context

```typescript
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { AuthProvider } from '../context/AuthContext'
import { ProtectedRoute } from './ProtectedRoute'

// Helper to render with providers
function renderWithAuth(ui: React.ReactElement, { user = null } = {}) {
  return render(
    <AuthProvider initialUser={user}>
      {ui}
    </AuthProvider>
  )
}

describe('ProtectedRoute', () => {
  test('redirects to login when user is not authenticated', () => {
    renderWithAuth(<ProtectedRoute><div>Protected Content</div></ProtectedRoute>)

    expect(screen.queryByText(/protected content/i)).not.toBeInTheDocument()
    expect(screen.getByText(/please log in/i)).toBeInTheDocument()
  })

  test('shows content when user is authenticated', () => {
    const user = { id: '1', email: 'test@example.com', name: 'Test User' }

    renderWithAuth(
      <ProtectedRoute><div>Protected Content</div></ProtectedRoute>,
      { user }
    )

    expect(screen.getByText(/protected content/i)).toBeInTheDocument()
    expect(screen.queryByText(/please log in/i)).not.toBeInTheDocument()
  })
})
```

### Pattern 5: Async Operations (waitFor)

```typescript
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { UserProfile } from './UserProfile'

test('loads and displays user profile', async () => {
  render(<UserProfile userId='123' />)

  // Assert loading state
  expect(screen.getByText(/loading/i)).toBeInTheDocument()

  // Wait for content to appear
  await waitFor(() => {
    expect(screen.queryByText(/loading/i)).not.toBeInTheDocument()
  })

  // Assert loaded content
  expect(screen.getByText(/john doe/i)).toBeInTheDocument()
  expect(screen.getByText(/john@example.com/i)).toBeInTheDocument()
})

test('displays error when load fails', async () => {
  // Mock API to return error
  server.use(
    rest.get('/api/users/:id', (req, res, ctx) => {
      return res(ctx.status(404), ctx.json({ message: 'User not found' }))
    })
  )

  render(<UserProfile userId='999' />)

  // Wait for error message
  await waitFor(() => {
    expect(screen.getByText(/user not found/i)).toBeInTheDocument()
  })
})
```

## Testing Queries Priority

Use queries in this order (from most to least preferred):

1. **getByRole** - Best for accessibility
   ```typescript
   screen.getByRole('button', { name: /submit/i })
   screen.getByRole('textbox', { name: /email/i })
   ```

2. **getByLabelText** - Good for form fields
   ```typescript
   screen.getByLabelText(/email address/i)
   ```

3. **getByPlaceholderText** - When label isn't available
   ```typescript
   screen.getByPlaceholderText(/enter your email/i)
   ```

4. **getByText** - For non-interactive elements
   ```typescript
   screen.getByText(/welcome back/i)
   ```

5. **getByTestId** - Last resort only
   ```typescript
   screen.getByTestId('custom-component')
   ```

## MSW Setup

Mock Service Worker for realistic API mocking:

```typescript
// src/test/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)

// src/test/mocks/handlers.ts
import { rest } from 'msw'

export const handlers = [
  rest.get('/api/users', (req, res, ctx) => {
    return res(
      ctx.status(200),
      ctx.json([
        { id: '1', name: 'User 1' },
        { id: '2', name: 'User 2' }
      ])
    )
  }),

  rest.post('/api/login', (req, res, ctx) => {
    const { email, password } = req.body as any

    if (email === 'test@example.com' && password === 'password') {
      return res(
        ctx.status(200),
        ctx.json({ token: 'fake-token', user: { id: '1', email } })
      )
    }

    return res(
      ctx.status(401),
      ctx.json({ message: 'Invalid credentials' })
    )
  })
]

// src/test/setup.ts (in Jest config)
import { server } from './mocks/server'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

## Key Principles

See reference.md for detailed principles:
- Test user behavior, not implementation
- Use accessibility queries (getByRole)
- Prefer real implementations over mocks
- MSW for API mocking
- waitFor for async, avoid arbitrary timeouts
- 100% coverage for pure components/hooks
- Integration tests for user flows

## Coverage Strategy

**Pure components (100% coverage)**:
- All prop combinations
- All user interactions
- All conditional renders
- Error states

**Container components (integration tests)**:
- Complete user flows
- Error scenarios
- Loading states
- Success paths

**Custom hooks (100% coverage)**:
- All return values
- All branches
- Error handling
- Edge cases

## Common Testing Patterns

### Testing Forms
```typescript
// Fill form fields
await user.type(screen.getByLabelText(/email/i), 'test@example.com')

// Submit form
await user.click(screen.getByRole('button', { name: /submit/i }))

// Assert success
expect(await screen.findByText(/success/i)).toBeInTheDocument()
```

### Testing Lists
```typescript
// Assert list items
const items = screen.getAllByRole('listitem')
expect(items).toHaveLength(3)

// Assert specific item
expect(screen.getByText(/item 1/i)).toBeInTheDocument()
```

### Testing Modals
```typescript
// Open modal
await user.click(screen.getByRole('button', { name: /open modal/i }))

// Assert modal visible
expect(screen.getByRole('dialog')).toBeInTheDocument()

// Close modal
await user.click(screen.getByRole('button', { name: /close/i }))

// Assert modal hidden
expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
```

### Testing Navigation
```typescript
import { MemoryRouter } from 'react-router-dom'

function renderWithRouter(ui: React.ReactElement, { initialEntries = ['/'] } = {}) {
  return render(
    <MemoryRouter initialEntries={initialEntries}>
      {ui}
    </MemoryRouter>
  )
}

test('navigates to user profile on click', async () => {
  const user = userEvent.setup()
  renderWithRouter(<UserList />)

  await user.click(screen.getByText(/john doe/i))

  expect(screen.getByText(/user profile/i)).toBeInTheDocument()
})
```

See reference.md for complete testing patterns and examples.
