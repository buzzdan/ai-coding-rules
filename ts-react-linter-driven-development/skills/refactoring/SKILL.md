---
name: refactoring
description: Linter-driven refactoring patterns to reduce complexity and improve code quality in React/TypeScript. Use when ESLint fails with SonarJS complexity issues (cognitive, cyclomatic, expression) or when code feels hard to read/maintain. Applies component extraction, hook extraction, and simplification patterns.
---

# Refactoring (React/TypeScript)

Linter-driven refactoring patterns to reduce complexity and improve React code quality.

## When to Use
- ESLint fails with SonarJS complexity issues
- Code feels hard to read or maintain
- Components/functions are too long or deeply nested
- Automatically invoked by @linter-driven-development when linter fails

## Refactoring Signals

### SonarJS Linter Failures
- **sonarjs/cognitive-complexity** (max: 15) → Simplify logic, extract functions/hooks
- **sonarjs/cyclomatic-complexity** (max: 10) → Reduce branches, early returns
- **sonarjs/expression-complexity** (max: 5) → Extract variables, simplify conditions
- **sonarjs/max-lines-per-function** (max: 200) → Extract components/hooks
- **sonarjs/max-lines** (max: 600) → Split file into multiple files
- **sonarjs/nested-control-flow** (max: 4) → Early returns, guard clauses

### React-Specific Signals
- **react/no-unstable-nested-components** → Extract component definitions
- **react/no-multi-comp** → Split into separate files
- **react-hooks/exhaustive-deps** → Simplify dependencies, extract logic

### Code Smells
- Components > 200 LOC
- Functions with > 4 levels of nesting
- Mixed abstraction levels (UI + business logic)
- Inline complex logic in JSX
- Deeply nested conditionals

## Workflow

### 1. Interpret Linter Output

Run `npm run lintcheck` and analyze failures:
```
src/features/auth/LoginForm.tsx:45:1: Cognitive Complexity of 18 exceeds max of 15
src/features/users/UserList.tsx:120:5: Cyclomatic Complexity of 12 exceeds max of 10
src/components/DataTable.tsx:89:1: Function has 250 lines, max is 200
```

### 2. Diagnose Root Cause

For each failure, ask:
- **Mixed abstractions?** → Extract custom hooks, extract components
- **Complex conditionals?** → Early returns, guard clauses, extract conditions
- **Primitive obsession?** → Create Zod schemas or branded types
- **Long component?** → Split into smaller components
- **Nested components?** → Extract to separate components
- **Complex JSX logic?** → Extract to helper functions or hooks

### 3. Apply Refactoring Pattern

Choose appropriate pattern:
- **Extract Custom Hook**: Move logic out of component
- **Extract Component**: Break down large components
- **Extract Helper Function**: Simplify complex logic
- **Early Returns/Guard Clauses**: Reduce nesting
- **Simplify Conditions**: Extract to variables, use early returns
- **Extract Validation**: Move to Zod schemas or validation functions

### 4. Verify Improvement

- Re-run linter: `npm run lintcheck`
- Tests still pass: `npm test`
- Code more readable?

## Refactoring Patterns

### Pattern 1: Extract Custom Hook (Business Logic)

**Signal**: Component mixing UI with complex logic

```typescript
// ❌ Before - Complex logic in component (Cognitive Complexity: 18)
function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    const fetchUser = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const response = await fetch(`/api/users/${userId}`)
        if (!response.ok) {
          throw new Error('Failed to fetch user')
        }
        const data = await response.json()
        setUser(data)
      } catch (err) {
        setError(err as Error)
      } finally {
        setIsLoading(false)
      }
    }
    fetchUser()
  }, [userId])

  if (isLoading) return <Spinner />
  if (error) return <ErrorMessage error={error} />
  if (!user) return <NotFound />

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  )
}

// ✅ After - Logic extracted to hook (Component Complexity: 4)
function useUser(userId: string) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    const fetchUser = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const response = await fetch(`/api/users/${userId}`)
        if (!response.ok) throw new Error('Failed to fetch user')
        setUser(await response.json())
      } catch (err) {
        setError(err as Error)
      } finally {
        setIsLoading(false)
      }
    }
    fetchUser()
  }, [userId])

  return { user, isLoading, error }
}

function UserProfile({ userId }: { userId: string }) {
  const { user, isLoading, error } = useUser(userId)

  if (isLoading) return <Spinner />
  if (error) return <ErrorMessage error={error} />
  if (!user) return <NotFound />

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  )
}
```

### Pattern 2: Extract Component (Break Down Large Components)

**Signal**: Component > 200 lines, doing too much

```typescript
// ❌ Before - Large component (250 lines, Cognitive Complexity: 22)
function UserDashboard() {
  const [users, setUsers] = useState([])
  const [selectedUser, setSelectedUser] = useState(null)
  const [isEditing, setIsEditing] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')

  // ... 200+ lines of logic and JSX

  return (
    <div>
      {/* Search bar */}
      <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)} />

      {/* User list */}
      <ul>
        {users.filter(u => u.name.includes(searchTerm)).map(user => (
          <li key={user.id} onClick={() => setSelectedUser(user)}>
            {user.name} - {user.email}
            <button onClick={() => setIsEditing(true)}>Edit</button>
            <button onClick={() => deleteUser(user.id)}>Delete</button>
          </li>
        ))}
      </ul>

      {/* User detail */}
      {selectedUser && (
        <div>
          {isEditing ? (
            <form>...</form>
          ) : (
            <div>...</div>
          )}
        </div>
      )}
    </div>
  )
}

// ✅ After - Broken into focused components
function UserDashboard() {
  const [selectedUser, setSelectedUser] = useState<User | null>(null)

  return (
    <div>
      <UserSearch />
      <UserList onSelectUser={setSelectedUser} />
      {selectedUser && <UserDetail user={selectedUser} />}
    </div>
  )
}

function UserSearch() {
  const [searchTerm, setSearchTerm] = useState('')
  // Search logic
  return <input value={searchTerm} onChange={...} />
}

function UserList({ onSelectUser }: { onSelectUser: (user: User) => void }) {
  const { users } = useUsers()
  return (
    <ul>
      {users.map(user => (
        <UserListItem key={user.id} user={user} onSelect={onSelectUser} />
      ))}
    </ul>
  )
}

function UserListItem({ user, onSelect }: UserListItemProps) {
  return (
    <li onClick={() => onSelect(user)}>
      <span>{user.name}</span>
      <UserActions user={user} />
    </li>
  )
}
```

### Pattern 3: Early Returns / Guard Clauses (Reduce Nesting)

**Signal**: Deeply nested conditionals, cyclomatic complexity high

```typescript
// ❌ Before - Deep nesting (Cyclomatic Complexity: 12, Nesting: 5)
function validateAndSubmit(data: FormData) {
  if (data) {
    if (data.email) {
      if (isValidEmail(data.email)) {
        if (data.password) {
          if (data.password.length >= 8) {
            if (data.terms) {
              return submitForm(data)
            } else {
              return { error: 'Must accept terms' }
            }
          } else {
            return { error: 'Password too short' }
          }
        } else {
          return { error: 'Password required' }
        }
      } else {
        return { error: 'Invalid email' }
      }
    } else {
      return { error: 'Email required' }
    }
  }
  return { error: 'No data' }
}

// ✅ After - Early returns (Cyclomatic Complexity: 7, Nesting: 1)
function validateAndSubmit(data: FormData) {
  if (!data) return { error: 'No data' }
  if (!data.email) return { error: 'Email required' }
  if (!isValidEmail(data.email)) return { error: 'Invalid email' }
  if (!data.password) return { error: 'Password required' }
  if (data.password.length < 8) return { error: 'Password too short' }
  if (!data.terms) return { error: 'Must accept terms' }

  return submitForm(data)
}

// ✅ Even better - Use Zod schema
const FormDataSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  terms: z.boolean().refine(val => val === true, 'Must accept terms')
})

function validateAndSubmit(data: unknown) {
  const result = FormDataSchema.safeParse(data)
  if (!result.success) {
    return { error: result.error.errors[0].message }
  }
  return submitForm(result.data)
}
```

### Pattern 4: Extract Complex Conditions (Simplify Expression Complexity)

**Signal**: Complex boolean expressions, expression complexity > 5

```typescript
// ❌ Before - Complex condition (Expression Complexity: 8)
if (
  user &&
  user.isActive &&
  !user.isBanned &&
  user.subscription &&
  user.subscription.status === 'active' &&
  user.subscription.expiresAt > Date.now() &&
  (user.roles.includes('admin') || user.roles.includes('moderator'))
) {
  // Allow access
}

// ✅ After - Extracted to helper functions
function hasActiveSubscription(user: User): boolean {
  return (
    user.subscription?.status === 'active' &&
    user.subscription.expiresAt > Date.now()
  )
}

function hasModeratorAccess(user: User): boolean {
  return user.roles.includes('admin') || user.roles.includes('moderator')
}

function canAccessFeature(user: User): boolean {
  return (
    user.isActive &&
    !user.isBanned &&
    hasActiveSubscription(user) &&
    hasModeratorAccess(user)
  )
}

if (user && canAccessFeature(user)) {
  // Allow access
}

// ✅ Or extract to variables
const isUserValid = user.isActive && !user.isBanned
const hasSubscription = hasActiveSubscription(user)
const isModerator = hasModeratorAccess(user)

if (user && isUserValid && hasSubscription && isModerator) {
  // Allow access
}
```

### Pattern 5: Extract Unstable Nested Components

**Signal**: react/no-unstable-nested-components

```typescript
// ❌ Before - Component defined inside component
function UserList() {
  const users = useUsers()

  // ❌ Recreated on every render
  const UserCard = ({ user }: { user: User }) => (
    <div>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  )

  return (
    <div>
      {users.map(user => <UserCard key={user.id} user={user} />)}
    </div>
  )
}

// ✅ After - Component extracted
function UserCard({ user }: { user: User }) {
  return (
    <div>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  )
}

function UserList() {
  const users = useUsers()
  return (
    <div>
      {users.map(user => <UserCard key={user.id} user={user} />)}
    </div>
  )
}
```

### Pattern 6: Simplify Hook Dependencies

**Signal**: react-hooks/exhaustive-deps warnings, complex useEffect

```typescript
// ❌ Before - Complex dependencies
function SearchResults({ initialQuery, filters, sortBy }: Props) {
  const [results, setResults] = useState([])

  useEffect(() => {
    const fetchResults = async () => {
      const response = await api.search({
        query: initialQuery,
        filters: filters,
        sort: sortBy,
        page: 1
      })
      setResults(response.data)
    }
    fetchResults()
  }, [initialQuery, filters, sortBy, filters.category, filters.price]) // ❌ Duplicates, object deps
}

// ✅ After - Simplified with custom hook
function useSearchResults(query: string, filters: Filters, sortBy: string) {
  const [results, setResults] = useState([])

  // Stable object reference
  const searchParams = useMemo(
    () => ({ query, filters, sort: sortBy, page: 1 }),
    [query, filters, sortBy]
  )

  useEffect(() => {
    api.search(searchParams).then(response => setResults(response.data))
  }, [searchParams])

  return results
}

function SearchResults({ initialQuery, filters, sortBy }: Props) {
  const results = useSearchResults(initialQuery, filters, sortBy)
  return <ResultsList results={results} />
}
```

### Pattern 7: Extract Form Validation Logic

**Signal**: Complex validation in components

```typescript
// ❌ Before - Validation scattered in component
function LoginForm() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [errors, setErrors] = useState({})

  const handleSubmit = () => {
    const newErrors = {}

    if (!email) {
      newErrors.email = 'Email required'
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      newErrors.email = 'Invalid email'
    }

    if (!password) {
      newErrors.password = 'Password required'
    } else if (password.length < 8) {
      newErrors.password = 'Password too short'
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors)
      return
    }

    submitLogin(email, password)
  }

  // ...JSX
}

// ✅ After - Validation with Zod
import { z } from 'zod'

const LoginSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(8, 'Password must be at least 8 characters')
})

function LoginForm() {
  const { values, errors, setValue, handleSubmit } = useFormValidation(
    LoginSchema,
    { email: '', password: '' },
    submitLogin
  )

  return (
    <form onSubmit={handleSubmit}>
      <Input
        label='Email'
        value={values.email}
        onChange={e => setValue('email', e.target.value)}
        error={errors.email}
      />
      <Input
        label='Password'
        type='password'
        value={values.password}
        onChange={e => setValue('password', e.target.value)}
        error={errors.password}
      />
      <button type='submit'>Login</button>
    </form>
  )
}
```

## Refactoring Decision Tree

When linter fails, follow this decision tree:

```
Linter Failure
    ├─ Cognitive Complexity > 15
    │   ├─ Mixed abstractions? → Extract custom hooks
    │   ├─ Complex conditions? → Extract to helper functions
    │   └─ Deep nesting? → Early returns, guard clauses
    │
    ├─ Cyclomatic Complexity > 10
    │   ├─ Many branches? → Early returns
    │   ├─ Complex switch? → Use object mapping or extract functions
    │   └─ Multiple &&/|| chains? → Extract conditions to variables
    │
    ├─ Expression Complexity > 5
    │   ├─ Long boolean expressions? → Extract to variables
    │   └─ Nested ternaries? → Extract to function or if statements
    │
    ├─ Max Lines Per Function > 200
    │   ├─ Large component? → Extract smaller components
    │   ├─ Complex logic? → Extract custom hooks
    │   └─ Mixed concerns? → Separate UI from business logic
    │
    ├─ Nested Control Flow > 4
    │   └─ Deep nesting? → Early returns, guard clauses
    │
    └─ React-specific
        ├─ no-unstable-nested-components → Extract component definition
        ├─ no-multi-comp → Split into separate files
        └─ exhaustive-deps → Simplify dependencies, extract logic
```

## Key Principles

See reference.md for detailed principles:
- Single Responsibility: Each component/hook does one thing
- Extract Early, Extract Often: Don't wait for linter to fail
- Composition Over Complexity: Combine simple pieces
- Guard Clauses: Exit early, reduce nesting
- Extract Helper Functions: Name complex logic
- Custom Hooks: Reusable logic outside components
- Zod for Validation: Move validation out of components

## After Refactoring

- [ ] Re-run linter: `npm run lintcheck`
- [ ] Run tests: `npm test`
- [ ] Verify behavior unchanged
- [ ] Check if more readable
- [ ] Consider broader refactoring if patterns repeat

See reference.md for complete refactoring patterns and decision trees.
