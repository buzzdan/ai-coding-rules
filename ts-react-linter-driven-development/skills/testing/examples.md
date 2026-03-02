# Testing Examples

> **Source**: Testing patterns for TypeScript + React with React Testing Library (Jest/Vitest)

## Table of Contents
1. [Testing Presentational Components](#testing-presentational-components)
2. [Testing Container Components](#testing-container-components)
3. [Testing Custom Hooks](#testing-custom-hooks)
4. [Testing with Readonly Props](#testing-with-readonly-props)
5. [Testing State Updates](#testing-state-updates)
6. [Testing Composition Patterns](#testing-composition-patterns)

---

## Testing Presentational Components

### Pattern: Pure UI, 100% Coverage

Presentational components are easy to test - just pass props and assert rendering.

```typescript
// Component: ClusterCard.tsx
interface ClusterCardProps {
  readonly name: string
  readonly status: 'healthy' | 'degraded' | 'critical'
  readonly capacity: number
  readonly usedCapacity: number
  readonly onViewDetails: () => void
}

export function ClusterCard({
  name,
  status,
  capacity,
  usedCapacity,
  onViewDetails
}: ClusterCardProps) {
  const utilizationPercent = (usedCapacity / capacity) * 100

  return (
    <div data-testid="cluster-card">
      <h3>{name}</h3>
      <span data-testid="status">{status}</span>
      <div data-testid="utilization">{utilizationPercent}%</div>
      <button onClick={onViewDetails}>View Details</button>
    </div>
  )
}

// Test: ClusterCard.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ClusterCard } from './ClusterCard'

describe('ClusterCard', () => {
  const defaultProps: ClusterCardProps = {
    name: 'Test Cluster',
    status: 'healthy',
    capacity: 100,
    usedCapacity: 50,
    onViewDetails: jest.fn()
  }

  test('renders cluster information correctly', () => {
    render(<ClusterCard {...defaultProps} />)

    expect(screen.getByText('Test Cluster')).toBeInTheDocument()
    expect(screen.getByTestId('status')).toHaveTextContent('healthy')
    expect(screen.getByTestId('utilization')).toHaveTextContent('50%')
  })

  test('calculates utilization percentage correctly', () => {
    render(
      <ClusterCard
        {...defaultProps}
        capacity={200}
        usedCapacity={75}
      />
    )

    expect(screen.getByTestId('utilization')).toHaveTextContent('37.5%')
  })

  test.each([
    { status: 'healthy' as const, expected: 'healthy' },
    { status: 'degraded' as const, expected: 'degraded' },
    { status: 'critical' as const, expected: 'critical' }
  ])('displays $status status correctly', ({ status, expected }) => {
    render(<ClusterCard {...defaultProps} status={status} />)

    expect(screen.getByTestId('status')).toHaveTextContent(expected)
  })

  test('calls onViewDetails when button is clicked', async () => {
    const user = userEvent.setup()
    const onViewDetails = jest.fn()

    render(<ClusterCard {...defaultProps} onViewDetails={onViewDetails} />)

    await user.click(screen.getByRole('button', { name: /view details/i }))

    expect(onViewDetails).toHaveBeenCalledTimes(1)
  })
})
```

**Benefits:**
- ✅ No mocking required
- ✅ Tests user-visible behavior
- ✅ Easy to achieve 100% coverage
- ✅ Fast execution

---

## Testing Container Components

### Pattern: Integration Tests with Real Dependencies

Container components coordinate logic and UI - test user workflows, not implementation.

```typescript
// Component: ClusterCardContainer.tsx
interface ClusterCardContainerProps {
  readonly clusterId: string
}

export function ClusterCardContainer({ clusterId }: ClusterCardContainerProps) {
  const { data: clusters, isLoading, error } = useClusters()
  const cluster = clusters?.find(c => c.id === clusterId)
  const navigate = useNavigate()
  const posthog = usePostHog()

  const handleViewDetails = useCallback(() => {
    posthog?.capture('cluster_details_viewed', {
      clusterId,
      clusterName: cluster?.name
    })
    navigate(`/cluster/${clusterId}`)
  }, [clusterId, cluster?.name, navigate, posthog])

  if (isLoading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>
  if (!cluster) return null

  const status = getHealthStatus(cluster)

  return (
    <ClusterCard
      name={cluster.name}
      status={status}
      capacity={cluster.capacity.total}
      usedCapacity={cluster.capacity.used}
      onViewDetails={handleViewDetails}
    />
  )
}

// Test: ClusterCardContainer.test.tsx
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { rest } from 'msw'
import { setupServer } from 'msw/node'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { ClusterCardContainer } from './ClusterCardContainer'

const mockClusters = [
  {
    id: 'cluster-1',
    name: 'Production Cluster',
    capacity: { total: 1000, used: 750 },
    health: 'healthy'
  }
]

const server = setupServer(
  rest.get('/api/clusters', (req, res, ctx) => {
    return res(ctx.json(mockClusters))
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

function renderWithRouter(ui: React.ReactElement) {
  return render(
    <MemoryRouter initialEntries={['/clusters']}>
      <Routes>
        <Route path="/clusters" element={ui} />
        <Route path="/cluster/:id" element={<div>Cluster Details</div>} />
      </Routes>
    </MemoryRouter>
  )
}

describe('ClusterCardContainer', () => {
  test('displays loading state initially', () => {
    renderWithRouter(<ClusterCardContainer clusterId="cluster-1" />)

    expect(screen.getByText(/loading/i)).toBeInTheDocument()
  })

  test('displays cluster data after loading', async () => {
    renderWithRouter(<ClusterCardContainer clusterId="cluster-1" />)

    await waitFor(() => {
      expect(screen.queryByText(/loading/i)).not.toBeInTheDocument()
    })

    expect(screen.getByText('Production Cluster')).toBeInTheDocument()
    expect(screen.getByTestId('status')).toHaveTextContent('healthy')
  })

  test('displays error message when fetch fails', async () => {
    server.use(
      rest.get('/api/clusters', (req, res, ctx) => {
        return res(ctx.status(500), ctx.json({ message: 'Server error' }))
      })
    )

    renderWithRouter(<ClusterCardContainer clusterId="cluster-1" />)

    await waitFor(() => {
      expect(screen.getByText(/error/i)).toBeInTheDocument()
    })
  })

  test('navigates to details page when view details is clicked', async () => {
    const user = userEvent.setup()
    renderWithRouter(<ClusterCardContainer clusterId="cluster-1" />)

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /view details/i })).toBeInTheDocument()
    })

    await user.click(screen.getByRole('button', { name: /view details/i }))

    expect(screen.getByText('Cluster Details')).toBeInTheDocument()
  })

  test('returns null when cluster is not found', async () => {
    renderWithRouter(<ClusterCardContainer clusterId="non-existent" />)

    await waitFor(() => {
      expect(screen.queryByText(/loading/i)).not.toBeInTheDocument()
    })

    expect(screen.queryByTestId('cluster-card')).not.toBeInTheDocument()
  })
})
```

**Benefits:**
- ✅ Tests real user workflows
- ✅ Uses network-level mocking for realistic API tests
- ✅ Tests integration points (navigation, analytics)
- ✅ Catches integration bugs

---

## Testing Custom Hooks

### Pattern: Test with renderHook and Real Dependencies

```typescript
// Hook: useClusterCard.ts
export function useClusterCard(clusterId: string) {
  const { data: clusters, isLoading } = useClusters()
  const cluster = clusters?.find(c => c.id === clusterId)
  const navigate = useNavigate()

  const handleViewDetails = useCallback(() => {
    navigate(`/cluster/${clusterId}`)
  }, [clusterId, navigate])

  return { cluster, isLoading, handleViewDetails }
}

// Test: useClusterCard.test.ts
import { renderHook, waitFor } from '@testing-library/react'
import { rest } from 'msw'
import { setupServer } from 'msw/node'
import { MemoryRouter } from 'react-router-dom'
import { useClusterCard } from './useClusterCard'

const mockClusters = [
  { id: 'cluster-1', name: 'Test Cluster', capacity: { total: 100, used: 50 } }
]

const server = setupServer(
  rest.get('/api/clusters', (req, res, ctx) => {
    return res(ctx.json(mockClusters))
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

function wrapper({ children }: { children: React.ReactNode }) {
  return <MemoryRouter>{children}</MemoryRouter>
}

describe('useClusterCard', () => {
  test('fetches and returns cluster data', async () => {
    const { result } = renderHook(() => useClusterCard('cluster-1'), { wrapper })

    expect(result.current.isLoading).toBe(true)
    expect(result.current.cluster).toBeUndefined()

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.cluster).toEqual(mockClusters[0])
  })

  test('returns undefined for non-existent cluster', async () => {
    const { result } = renderHook(() => useClusterCard('non-existent'), { wrapper })

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.cluster).toBeUndefined()
  })

  test('handleViewDetails navigates to cluster details', async () => {
    const { result } = renderHook(() => useClusterCard('cluster-1'), { wrapper })

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    // Call handleViewDetails - would need to test navigation separately
    expect(result.current.handleViewDetails).toBeDefined()
  })
})
```

---

## Testing with Readonly Props

### Pattern: Type-Safe Test Props

```typescript
// Component with Readonly props
interface ButtonProps {
  label: string
  onClick: () => void
  variant?: 'primary' | 'secondary'
  disabled?: boolean
}

export function Button({
  label,
  onClick,
  variant = 'primary',
  disabled = false
}: Readonly<ButtonProps>) {
  return (
    <button
      className={`btn btn-${variant}`}
      onClick={onClick}
      disabled={disabled}
    >
      {label}
    </button>
  )
}

// Test: Button.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Button } from './Button'

describe('Button', () => {
  // Create default props with correct typing
  const defaultProps: ButtonProps = {
    label: 'Click me',
    onClick: jest.fn()
  }

  test('renders with default variant', () => {
    render(<Button {...defaultProps} />)

    const button = screen.getByRole('button', { name: /click me/i })
    expect(button).toHaveClass('btn-primary')
  })

  test.each([
    { variant: 'primary' as const, expectedClass: 'btn-primary' },
    { variant: 'secondary' as const, expectedClass: 'btn-secondary' }
  ])('renders $variant variant', ({ variant, expectedClass }) => {
    render(<Button {...defaultProps} variant={variant} />)

    const button = screen.getByRole('button')
    expect(button).toHaveClass(expectedClass)
  })

  test('calls onClick when clicked', async () => {
    const user = userEvent.setup()
    const onClick = jest.fn()

    render(<Button {...defaultProps} onClick={onClick} />)

    await user.click(screen.getByRole('button'))

    expect(onClick).toHaveBeenCalledTimes(1)
  })

  test('does not call onClick when disabled', async () => {
    const user = userEvent.setup()
    const onClick = jest.fn()

    render(<Button {...defaultProps} onClick={onClick} disabled />)

    const button = screen.getByRole('button')
    expect(button).toBeDisabled()

    // Disabled buttons don't respond to clicks
    await user.click(button)
    expect(onClick).not.toHaveBeenCalled()
  })
})
```

---

## Testing State Updates

### Pattern: Test Functional vs Direct Updates

```typescript
// Component with state updates
export function Counter() {
  const [count, setCount] = useState(0)

  // Functional update - correct for increments
  const increment = () => setCount(prev => prev + 1)

  // Direct update - correct for setting new value
  const reset = () => setCount(0)

  // Functional update - correct for arrays
  const [items, setItems] = useState<string[]>([])
  const addItem = (item: string) => setItems(prev => [...prev, item])

  return (
    <div>
      <div data-testid="count">{count}</div>
      <button onClick={increment}>Increment</button>
      <button onClick={reset}>Reset</button>
      <div data-testid="items-count">{items.length}</div>
      <button onClick={() => addItem('new')}>Add Item</button>
    </div>
  )
}

// Test: Counter.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Counter } from './Counter'

describe('Counter', () => {
  test('increments count correctly with functional update', async () => {
    const user = userEvent.setup()
    render(<Counter />)

    expect(screen.getByTestId('count')).toHaveTextContent('0')

    // Click multiple times rapidly
    await user.click(screen.getByRole('button', { name: /increment/i }))
    await user.click(screen.getByRole('button', { name: /increment/i }))
    await user.click(screen.getByRole('button', { name: /increment/i }))

    // All clicks should be counted (functional update)
    expect(screen.getByTestId('count')).toHaveTextContent('3')
  })

  test('resets count with direct update', async () => {
    const user = userEvent.setup()
    render(<Counter />)

    await user.click(screen.getByRole('button', { name: /increment/i }))
    await user.click(screen.getByRole('button', { name: /increment/i }))

    expect(screen.getByTestId('count')).toHaveTextContent('2')

    await user.click(screen.getByRole('button', { name: /reset/i }))

    expect(screen.getByTestId('count')).toHaveTextContent('0')
  })

  test('adds items correctly with functional update', async () => {
    const user = userEvent.setup()
    render(<Counter />)

    expect(screen.getByTestId('items-count')).toHaveTextContent('0')

    await user.click(screen.getByRole('button', { name: /add item/i }))
    await user.click(screen.getByRole('button', { name: /add item/i }))

    expect(screen.getByTestId('items-count')).toHaveTextContent('2')
  })
})
```

---

## Testing Composition Patterns

### Pattern 1: Testing Compound Components

```typescript
// Compound component
function Card({ children }: { children: React.ReactNode }) {
  return <div data-testid="card">{children}</div>
}

Card.Header = function CardHeader({ children }: { children: React.ReactNode }) {
  return <div data-testid="card-header">{children}</div>
}

Card.Body = function CardBody({ children }: { children: React.ReactNode }) {
  return <div data-testid="card-body">{children}</div>
}

Card.Footer = function CardFooter({ children }: { children: React.ReactNode }) {
  return <div data-testid="card-footer">{children}</div>
}

// Test
import { render, screen } from '@testing-library/react'
import { Card } from './Card'

describe('Card', () => {
  test('renders all compound components', () => {
    render(
      <Card>
        <Card.Header>Header</Card.Header>
        <Card.Body>Body</Card.Body>
        <Card.Footer>Footer</Card.Footer>
      </Card>
    )

    expect(screen.getByTestId('card')).toBeInTheDocument()
    expect(screen.getByTestId('card-header')).toHaveTextContent('Header')
    expect(screen.getByTestId('card-body')).toHaveTextContent('Body')
    expect(screen.getByTestId('card-footer')).toHaveTextContent('Footer')
  })

  test('renders with only required components', () => {
    render(
      <Card>
        <Card.Body>Content</Card.Body>
      </Card>
    )

    expect(screen.getByTestId('card-body')).toHaveTextContent('Content')
    expect(screen.queryByTestId('card-header')).not.toBeInTheDocument()
    expect(screen.queryByTestId('card-footer')).not.toBeInTheDocument()
  })
})
```

### Pattern 2: Testing Custom Hook Composition

```typescript
// Hook that uses other hooks
function useFormWithValidation() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const { errors, validate } = useValidation()

  const handleSubmit = async () => {
    const isValid = validate({ email, password })
    if (!isValid) return

    await submitForm({ email, password })
  }

  return { email, setEmail, password, setPassword, errors, handleSubmit }
}

// Test
import { renderHook, act, waitFor } from '@testing-library/react'
import { useFormWithValidation } from './useFormWithValidation'

describe('useFormWithValidation', () => {
  test('validates email and password before submitting', async () => {
    const { result } = renderHook(() => useFormWithValidation())

    act(() => {
      result.current.setEmail('invalid')
      result.current.setPassword('short')
    })

    await act(async () => {
      await result.current.handleSubmit()
    })

    expect(result.current.errors.email).toBeDefined()
    expect(result.current.errors.password).toBeDefined()
  })

  test('submits when validation passes', async () => {
    const { result } = renderHook(() => useFormWithValidation())

    act(() => {
      result.current.setEmail('test@example.com')
      result.current.setPassword('password123')
    })

    await act(async () => {
      await result.current.handleSubmit()
    })

    expect(result.current.errors.email).toBeUndefined()
    expect(result.current.errors.password).toBeUndefined()
  })
})
```
