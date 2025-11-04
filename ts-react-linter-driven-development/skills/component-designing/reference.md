# Component Designing Reference (TypeScript + React)

## Overview

This reference provides detailed principles for designing clean, maintainable React components and TypeScript types. Focus on composition, type safety, and feature-based architecture.

## 1. Primitive Obsession Prevention

### Problem

Using primitive types (string, number, boolean) for domain concepts loses:
- Type safety
- Validation guarantees
- Domain meaning
- Refactoring safety

**Bad example:**
```typescript
interface User {
  id: string          // What if empty? What if not UUID?
  email: string       // What if invalid format?
  age: number         // What if negative? What if 999?
}

function getUser(id: string): User {
  // No guarantee id is valid
  return api.fetchUser(id)
}
```

### Solution A: Zod Schemas (Runtime Validation)

**When to use**: Form validation, API parsing, user input

```typescript
import { z } from 'zod'

// Define schemas with validation
export const EmailSchema = z
  .string()
  .email('Invalid email format')
  .min(1, 'Email is required')

export const UserIdSchema = z
  .string()
  .uuid('UserId must be a valid UUID')

export const AgeSchema = z
  .number()
  .int()
  .min(0, 'Age cannot be negative')
  .max(150, 'Age must be realistic')

// Extract types from schemas
export type Email = z.infer<typeof EmailSchema>
export type UserId = z.infer<typeof UserIdSchema>
export type Age = z.infer<typeof AgeSchema>

// User schema composition
export const UserSchema = z.object({
  id: UserIdSchema,
  email: EmailSchema,
  age: AgeSchema,
  name: z.string().min(1)
})

export type User = z.infer<typeof UserSchema>

// Validation functions
export function parseUser(data: unknown): User {
  return UserSchema.parse(data) // Throws ZodError on invalid
}

export function validateUser(data: unknown): { success: true; data: User } | { success: false; error: z.ZodError } {
  return UserSchema.safeParse(data)
}
```

**Usage in components:**
```typescript
function UserForm() {
  const [email, setEmail] = useState('')
  const [error, setError] = useState('')

  const handleSubmit = () => {
    try {
      const validEmail = EmailSchema.parse(email)
      // validEmail is now Email type, guaranteed valid
      await api.createUser(validEmail)
    } catch (err) {
      if (err instanceof z.ZodError) {
        setError(err.errors[0].message)
      }
    }
  }
}
```

### Solution B: Branded Types (Compile-Time Safety)

**When to use**: Type safety without runtime overhead, internal APIs

```typescript
// Branding technique
declare const __brand: unique symbol
type Brand<T, TBrand> = T & { [__brand]: TBrand }

// Define branded types
export type Email = Brand<string, 'Email'>
export type UserId = Brand<string, 'UserId'>
export type Age = Brand<number, 'Age'>

// Validating constructors
export function createEmail(value: string): Email {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(value)) {
    throw new Error(`Invalid email: ${value}`)
  }
  return value as Email
}

export function createUserId(value: string): UserId {
  if (!value || value.trim().length === 0) {
    throw new Error('UserId cannot be empty')
  }
  return value as UserId
}

export function createAge(value: number): Age {
  if (value < 0 || value > 150) {
    throw new Error(`Invalid age: ${value}`)
  }
  return value as Age
}

// User interface
export interface User {
  id: UserId
  email: Email
  age: Age
  name: string
}
```

**Type safety:**
```typescript
// Compile-time error: Type 'string' is not assignable to type 'Email'
const email: Email = "test@example.com"  // ❌

// Must use constructor
const email = createEmail("test@example.com")  // ✅

// Cannot mix branded types
const userId: UserId = createEmail("test@example.com")  // ❌ Compile error
```

### Which to Choose?

| Feature | Zod Schemas | Branded Types |
|---------|-------------|---------------|
| Runtime validation | ✅ Yes | ❌ No |
| Compile-time safety | ✅ Yes | ✅ Yes |
| Bundle size impact | ⚠️ Adds Zod | ✅ None |
| Form validation | ✅ Excellent | ⚠️ Manual |
| API parsing | ✅ Excellent | ⚠️ Manual |
| Internal APIs | ✅ Good | ✅ Excellent |
| Error messages | ✅ Built-in | ⚠️ Manual |

**Recommendation**: Use both!
- Zod for boundaries (forms, API)
- Branded types for internal type safety

## 2. Feature-Based Architecture

### Principle

Group code by **feature** (what it does), not by **technical layer** (how it works).

### Pattern Comparison

**❌ Bad: Technical Layers (Horizontal Slicing)**
```
src/
├── components/
│   ├── LoginForm.tsx
│   ├── RegisterForm.tsx
│   ├── UserProfile.tsx
│   └── UserList.tsx
├── hooks/
│   ├── useAuth.ts
│   ├── useUsers.ts
│   └── useProfile.ts
├── contexts/
│   ├── AuthContext.tsx
│   └── UserContext.tsx
├── types/
│   ├── auth.ts
│   └── user.ts
└── api/
    ├── auth.ts
    └── users.ts
```

**Problems:**
- Related code spread across directories
- Hard to find all code for a feature
- Changes require touching multiple folders
- Tight coupling between features
- Difficult to extract or delete features

**✅ Good: Feature-Based (Vertical Slicing)**
```
src/
├── features/
│   ├── auth/
│   │   ├── components/
│   │   │   ├── LoginForm.tsx
│   │   │   ├── LoginForm.test.tsx
│   │   │   ├── RegisterForm.tsx
│   │   │   └── RegisterForm.test.tsx
│   │   ├── hooks/
│   │   │   ├── useAuth.ts
│   │   │   ├── useAuth.test.ts
│   │   │   ├── useLogin.ts
│   │   │   └── useRegister.ts
│   │   ├── context/
│   │   │   ├── AuthContext.tsx
│   │   │   └── AuthContext.test.tsx
│   │   ├── types.ts
│   │   ├── api.ts
│   │   ├── utils.ts
│   │   └── index.ts         # Public exports
│   │
│   └── users/
│       ├── components/
│       │   ├── UserProfile.tsx
│       │   ├── UserProfile.test.tsx
│       │   ├── UserList.tsx
│       │   └── UserList.test.tsx
│       ├── hooks/
│       │   ├── useUsers.ts
│       │   ├── useUserProfile.ts
│       │   └── useUserSearch.ts
│       ├── types.ts
│       ├── api.ts
│       └── index.ts
│
└── shared/              # Truly shared code only
    ├── components/      # Shared UI components (Button, Input)
    ├── hooks/           # Shared hooks (useDebounce, useLocalStorage)
    ├── utils/           # Shared utilities (date formatting, string helpers)
    └── types/           # Shared types (ApiResponse, Pagination)
```

**Benefits:**
- All code for a feature in one place
- Easy to understand feature scope
- Easy to extract or delete features
- Clear dependencies between features
- Tests colocated with implementation

### Feature Index Files

Each feature should export its public API through `index.ts`:

```typescript
// src/features/auth/index.ts
export { LoginForm, RegisterForm } from './components/LoginForm'
export { useAuth } from './hooks/useAuth'
export { AuthProvider, useAuthContext } from './context/AuthContext'
export type { User, Email, UserId } from './types'

// Private implementation details stay unexported
// - Internal hooks
// - Utility functions
// - Implementation components
```

**Usage from other features:**
```typescript
// ✅ Good: Import from feature's public API
import { LoginForm, useAuth, type User } from '@/features/auth'

// ❌ Bad: Import internal implementation
import { LoginForm } from '@/features/auth/components/LoginForm'
import { useAuth } from '@/features/auth/hooks/useAuth'
```

## 3. Component Composition Patterns

### A. Presentational vs Container Components

**Presentational Components (Pure UI)**:
- No state management (or only local UI state)
- Props-driven behavior
- Reusable across features
- Easy to test (just props)
- No side effects

```typescript
// ✅ Good: Presentational
interface UserCardProps {
  user: User
  onEdit: (id: UserId) => void
  onDelete: (id: UserId) => void
}

export function UserCard({ user, onEdit, onDelete }: UserCardProps) {
  return (
    <div className='user-card'>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
      <button onClick={() => onEdit(user.id)}>Edit</button>
      <button onClick={() => onDelete(user.id)}>Delete</button>
    </div>
  )
}

// Test: Just pass props, assert rendering
test('UserCard renders user info', () => {
  const user = createMockUser()
  render(<UserCard user={user} onEdit={jest.fn()} onDelete={jest.fn()} />)
  expect(screen.getByText(user.name)).toBeInTheDocument()
})
```

**Container Components (Logic + Orchestration)**:
- Manage state
- Handle side effects
- Data fetching
- Compose presentational components

```typescript
// ✅ Good: Container
export function UserCardContainer({ userId }: { userId: UserId }) {
  const { user, isLoading, error } = useUser(userId)
  const { deleteUser } = useUsers()
  const navigate = useNavigate()

  if (isLoading) return <Spinner />
  if (error) return <ErrorMessage error={error} />
  if (!user) return <NotFound />

  const handleEdit = (id: UserId) => {
    navigate(`/users/${id}/edit`)
  }

  const handleDelete = async (id: UserId) => {
    if (confirm('Delete user?')) {
      await deleteUser(id)
    }
  }

  return <UserCard user={user} onEdit={handleEdit} onDelete={handleDelete} />
}
```

### B. Compound Components Pattern

For components with multiple related parts:

```typescript
// ✅ Good: Compound components with context
interface CardContextValue {
  isExpanded: boolean
  toggle: () => void
}

const CardContext = createContext<CardContextValue | null>(null)

function useCardContext() {
  const context = useContext(CardContext)
  if (!context) throw new Error('Must be used within Card')
  return context
}

// Main component
export function Card({ children }: { children: ReactNode }) {
  const [isExpanded, setIsExpanded] = useState(false)
  const toggle = () => setIsExpanded(prev => !prev)

  return (
    <CardContext.Provider value={{ isExpanded, toggle }}>
      <div className='card'>{children}</div>
    </CardContext.Provider>
  )
}

// Sub-components
Card.Header = function CardHeader({ children }: { children: ReactNode }) {
  return <div className='card-header'>{children}</div>
}

Card.Toggle = function CardToggle({ children }: { children: ReactNode }) {
  const { toggle } = useCardContext()
  return <button onClick={toggle}>{children}</button>
}

Card.Body = function CardBody({ children }: { children: ReactNode }) {
  const { isExpanded } = useCardContext()
  if (!isExpanded) return null
  return <div className='card-body'>{children}</div>
}

// Usage
<Card>
  <Card.Header>
    <h3>Title</h3>
    <Card.Toggle>Expand</Card.Toggle>
  </Card.Header>
  <Card.Body>
    <p>Content here</p>
  </Card.Body>
</Card>
```

### C. Render Props Pattern (Advanced)

For maximum flexibility:

```typescript
interface DataLoaderProps<T> {
  fetchData: () => Promise<T>
  children: (data: {
    data: T | null
    isLoading: boolean
    error: Error | null
  }) => ReactNode
}

function DataLoader<T>({ fetchData, children }: DataLoaderProps<T>) {
  const [data, setData] = useState<T | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    setIsLoading(true)
    fetchData()
      .then(setData)
      .catch(setError)
      .finally(() => setIsLoading(false))
  }, [fetchData])

  return <>{children({ data, isLoading, error })}</>
}

// Usage
<DataLoader fetchData={() => api.getUsers()}>
  {({ data, isLoading, error }) => {
    if (isLoading) return <Spinner />
    if (error) return <Error error={error} />
    return <UserList users={data} />
  }}
</DataLoader>
```

## 4. Custom Hooks Design

### Single Responsibility Principle

Each hook should do **one thing** well.

**❌ Bad: God Hook**
```typescript
function useUser(userId: UserId) {
  // Too many responsibilities!
  const [user, setUser] = useState<User | null>(null)
  const [posts, setPosts] = useState<Post[]>([])
  const [friends, setFriends] = useState<User[]>([])
  const [settings, setSettings] = useState<Settings | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    // Fetch everything...
  }, [userId])

  const updateProfile = async (data: Partial<User>) => { /* ... */ }
  const addPost = async (post: Post) => { /* ... */ }
  const addFriend = async (friendId: UserId) => { /* ... */ }
  const updateSettings = async (settings: Settings) => { /* ... */ }

  return {
    user, posts, friends, settings,
    isLoading, error,
    updateProfile, addPost, addFriend, updateSettings
  }
}
```

**✅ Good: Focused Hooks**
```typescript
// Fetch user data
function useUser(userId: UserId) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    const fetchUser = async () => {
      setIsLoading(true)
      try {
        const data = await api.getUser(userId)
        setUser(data)
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

// Fetch user posts
function useUserPosts(userId: UserId) {
  const [posts, setPosts] = useState<Post[]>([])
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    api.getUserPosts(userId).then(setPosts)
  }, [userId])

  return { posts, isLoading }
}

// Update user profile
function useUpdateUser() {
  const [isUpdating, setIsUpdating] = useState(false)

  const updateUser = async (userId: UserId, data: Partial<User>) => {
    setIsUpdating(true)
    try {
      await api.updateUser(userId, data)
    } finally {
      setIsUpdating(false)
    }
  }

  return { updateUser, isUpdating }
}

// Compose in component
function UserProfile({ userId }: { userId: UserId }) {
  const { user, isLoading, error } = useUser(userId)
  const { posts } = useUserPosts(userId)
  const { updateUser, isUpdating } = useUpdateUser()

  // ...
}
```

### Hook Naming Conventions

- `use` prefix (React requirement)
- Verb-noun pattern: `useFormState`, `useUserData`, `useClickOutside`
- Boolean returns: `useIsAuthenticated`, `useHasPermission`

## 5. Context Design

### When to Use Context

**Use context when:**
- State needed in 3+ component levels
- Truly global state (auth, theme, i18n)
- Avoiding prop drilling is worth complexity

**Don't use context for:**
- State needed in 1-2 levels (use props)
- Frequently changing state (causes rerenders)
- Can be solved with component composition

### Context Best Practices

**1. Separate context and provider:**
```typescript
// Context value type
interface ThemeContextValue {
  theme: 'light' | 'dark'
  setTheme: (theme: 'light' | 'dark') => void
}

// Context with null default
const ThemeContext = createContext<ThemeContextValue | null>(null)

// Custom hook with error handling
export function useTheme() {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider')
  }
  return context
}

// Provider component
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<'light' | 'dark'>('light')

  // Memoize value to prevent unnecessary rerenders
  const value = useMemo(() => ({ theme, setTheme }), [theme])

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}
```

**2. Split contexts by concern:**
```typescript
// ❌ Bad: One context for everything
interface AppContextValue {
  user: User | null
  theme: 'light' | 'dark'
  language: string
  notifications: Notification[]
  // ... everything else
}

// ✅ Good: Separate contexts
<AuthProvider>
  <ThemeProvider>
    <I18nProvider>
      <NotificationProvider>
        <App />
      </NotificationProvider>
    </I18nProvider>
  </ThemeProvider>
</AuthProvider>
```

**3. Optimize performance:**
```typescript
// Split frequently and rarely changing state
interface UserContextValue {
  user: User | null  // Changes rarely
}

interface UserActionsContextValue {
  updateProfile: (data: Partial<User>) => Promise<void>  // Never changes
  logout: () => Promise<void>                             // Never changes
}

// Two contexts to prevent unnecessary rerenders
const UserContext = createContext<UserContextValue | null>(null)
const UserActionsContext = createContext<UserActionsContextValue | null>(null)

export function UserProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)

  // Actions memoized once
  const actions = useMemo(
    () => ({
      updateProfile: async (data: Partial<User>) => {
        const updated = await api.updateProfile(data)
        setUser(updated)
      },
      logout: async () => {
        await api.logout()
        setUser(null)
      }
    }),
    []
  )

  return (
    <UserContext.Provider value={{ user }}>
      <UserActionsContext.Provider value={actions}>
        {children}
      </UserActionsContext.Provider>
    </UserContext.Provider>
  )
}

// Components only rerender when they need to
export function UserName() {
  const { user } = useUserContext()  // Rerenders when user changes
  return <span>{user?.name}</span>
}

export function LogoutButton() {
  const { logout } = useUserActions()  // Never rerenders!
  return <button onClick={logout}>Logout</button>
}
```

## 6. Props Interface Design

### Props Naming

**Boolean props:**
```typescript
// ✅ Good: Use is/has/can/should prefix
interface ButtonProps {
  isLoading: boolean
  isDisabled: boolean
  hasIcon: boolean
  canSubmit: boolean
}

// ❌ Bad: No prefix
interface ButtonProps {
  loading: boolean
  disabled: boolean
  icon: boolean
}
```

**Event handlers:**
```typescript
// ✅ Good: Use on prefix
interface FormProps {
  onSubmit: (data: FormData) => void
  onChange: (field: string, value: string) => void
  onError: (error: Error) => void
}
```

### Props Destructuring

**Always destructure in function signature:**
```typescript
// ✅ Good: Clear, self-documenting
export function Button({ label, onClick, isDisabled = false }: ButtonProps) {
  return <button onClick={onClick} disabled={isDisabled}>{label}</button>
}

// ❌ Bad: Props object drilling
export function Button(props: ButtonProps) {
  return <button onClick={props.onClick} disabled={props.isDisabled}>{props.label}</button>
}
```

## 7. Type Safety Patterns

### Discriminated Unions

For state machines or variants:

```typescript
// ✅ Good: Discriminated union
type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error }

function DataComponent() {
  const [state, setState] = useState<AsyncState<User>>({ status: 'idle' })

  // TypeScript narrows types based on status
  if (state.status === 'loading') {
    return <Spinner />
  }

  if (state.status === 'error') {
    // state.error is available (type narrowing)
    return <Error error={state.error} />
  }

  if (state.status === 'success') {
    // state.data is available (type narrowing)
    return <UserProfile user={state.data} />
  }

  return <button onClick={() => loadData()}>Load</button>
}
```

### Utility Types

```typescript
// Make all fields optional
type PartialUser = Partial<User>

// Pick specific fields
type UserPreview = Pick<User, 'id' | 'name' | 'email'>

// Omit specific fields
type UserWithoutPassword = Omit<User, 'password'>

// Make fields required
type RequiredUser = Required<Partial<User>>

// Make fields readonly
type ImmutableUser = Readonly<User>
```

## Summary

### Key Principles

1. **Prevent Primitive Obsession**: Use Zod schemas and branded types
2. **Feature-Based Architecture**: Group by feature, not technical layer
3. **Component Composition**: Presentational vs container, compound components
4. **Single Responsibility Hooks**: Each hook does one thing
5. **Context Sparingly**: Only for 3+ levels, optimize for performance
6. **Type Safety**: Use discriminated unions, utility types, branded types
7. **Clear Props**: Descriptive names, always destructure
8. **Colocate Tests**: Tests next to implementation

### Design Checklist

Before writing code:
- [ ] Architecture pattern decided (feature-based)
- [ ] Primitives identified and types designed (Zod/branded)
- [ ] Component responsibilities clear (presentational vs container)
- [ ] Custom hooks extracted (single responsibility)
- [ ] Context usage justified (3+ levels, truly shared)
- [ ] Props interfaces defined (clear, typed)
- [ ] File structure planned (colocated tests)
- [ ] Integration points identified
