---
name: component-designing
description: Component and type design for TypeScript + React code. Use when planning new features, designing components and custom hooks, preventing primitive obsession, or when refactoring reveals need for new abstractions. Supports layer-based and hybrid architecture patterns with type safety.
---

# Component Designing

Component and type design for TypeScript + React applications.
Use when planning new features or identifying need for new abstractions during refactoring.

## When to Use
- Planning a new feature (before writing code)
- Refactoring reveals need for new components/hooks
- Linter failures suggest better abstractions
- When you need to think through component architecture
- Designing state management approach

## Purpose
Design clean, well-composed components and types that:
- Prevent primitive obsession (use branded types, Zod schemas)
- Ensure type safety with TypeScript
- Follow component composition patterns
- Implement feature-based architecture
- Create reusable custom hooks

## Workflow

### 0. Architecture Pattern Analysis (FIRST STEP)

**Default: Match existing codebase architecture** (consistency is key).

Scan codebase structure:
- **Layer-based**: `src/{components,hooks,contexts,types}/...` - Group by technical layer
- **Hybrid**: `src/{components,hooks}/...` + `src/pages/...` - Shared layers + page-specific code
- **Feature-based**: `src/features/[feature]/{components,hooks,types}` - Group by feature

**Decision Flow**:
1. **Pure layer-based** → Continue pattern, place code in appropriate technical layers
2. **Pure feature-based** → Continue pattern, implement as `src/features/[new-feature]/`
3. **Hybrid** → Follow existing conventions (e.g., shared in layers, page-specific co-located)

**Layer-Based Structure** (Recommended for most codebases):
```
src/
  components/        # Reusable components only
    Button.tsx
    Input.tsx
    Modal.tsx
    Card.tsx
  pages/            # Top-level views/pages (use components)
    LoginPage.tsx
    DashboardPage.tsx
    UserProfilePage.tsx
  hooks/            # Reusable hooks
    useAuth.ts
    useDebounce.ts
    useLocalStorage.ts
  contexts/         # Shared context providers
    AuthContext.tsx
    ThemeContext.tsx
  types/            # Shared type definitions
    auth.ts
    user.ts
  api/              # API client
    authApi.ts
    userApi.ts
```

**Key Distinction**:
- `components/` = **Reusable** UI components (Button, Input, Modal)
- `pages/` or `views/` = **Top-level** page components that compose reusable components

**Hybrid Structure** (Common in practice):
```
src/
  components/        # Truly shared UI components
    Button.tsx
    Input.tsx
  hooks/            # Truly shared hooks
    useDebounce.ts
  pages/            # Pages with co-located feature-specific code
    auth/
      LoginPage.tsx
      components/LoginForm.tsx
      hooks/useLoginForm.ts
    dashboard/
      DashboardPage.tsx
      components/StatsWidget.tsx
```

**Key Principle**: Consistency over dogma. Match the existing structure unless there's a compelling reason to change.

See reference.md section #2 for detailed patterns.

---

### 1. Understand Domain

- What is the problem domain?
- What are the main UI concepts/interactions?
- What state needs to be managed?
- What are the user flows?
- How does this fit into existing architecture?

### 2. Identify Core Abstractions

Ask for each concept:
- Is this currently a primitive (string, number, boolean)?
- Does it have validation rules?
- Is it a UI concept (component)?
- Is it reusable logic (custom hook)?
- Is it shared state (context)?
- Does it need type safety (branded type)?

### 3. Design Self-Validating Types

For primitives with validation (Email, UserId, Port):

**Option A: Zod Schemas (Recommended)**
```typescript
import { z } from 'zod'

// Schema definition with validation
export const EmailSchema = z.string().email().min(1)
export const UserIdSchema = z.string().uuid()

// Extract type from schema
export type Email = z.infer<typeof EmailSchema>
export type UserId = z.infer<typeof UserIdSchema>

// Validation function
export function validateEmail(value: unknown): Email {
  return EmailSchema.parse(value) // Throws on invalid
}
```

**Option B: Branded Types (TypeScript)**
```typescript
// Brand for nominal typing
declare const __brand: unique symbol
type Brand<T, TBrand> = T & { [__brand]: TBrand }

export type Email = Brand<string, 'Email'>
export type UserId = Brand<string, 'UserId'>

// Validating constructor
export function createEmail(value: string): Email {
  if (!value.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
    throw new Error('Invalid email format')
  }
  return value as Email
}

export function createUserId(value: string): UserId {
  if (!value || value.length === 0) {
    throw new Error('UserId cannot be empty')
  }
  return value as UserId
}
```

**When to use which:**
- Zod: Form validation, API parsing, runtime validation
- Branded types: Type safety without runtime overhead

### 4. Design Component Structure

**Component Types:**

**A. Presentational Components (Pure UI)**
- No state management
- Props-driven
- Reusable across features
- 100% testable

```typescript
interface ButtonProps {
  readonly label: string
  readonly onClick: () => void
  readonly disabled?: boolean
  readonly variant?: 'primary' | 'secondary'
}

export function Button({
  label,
  onClick,
  variant = 'primary',
  disabled = false
}: ButtonProps) {
  return (
    <button
      className={`btn btn-${variant}`}
      disabled={disabled}
      onClick={onClick}
    >
      {label}
    </button>
  )
}
```

**B. Container Components (Logic + State)**
- Manage state
- Handle side effects
- Coordinate data fetching
- Compose presentational components

```typescript
import { EMPTY_STRING } from 'consts'

export function LoginContainer() {
  const { login, isLoading, error } = useAuth()
  const [email, setEmail] = useState(EMPTY_STRING)
  const [password, setPassword] = useState(EMPTY_STRING)

  const handleSubmit = async () => {
    try {
      const validEmail = EmailSchema.parse(email)
      await login(validEmail, password)
    } catch (error) {
      // Handle error
    }
  }

  return (
    <LoginForm
      email={email}
      error={error}
      isLoading={isLoading}
      password={password}
      onEmailChange={setEmail}
      onPasswordChange={setPassword}
      onSubmit={handleSubmit}
    />
  )
}
```

### 5. Design Custom Hooks

Extract reusable logic into custom hooks:

```typescript
// Single responsibility: Form state management
export function useFormState<T>(initialValues: T) {
  const [values, setValues] = useState<T>(initialValues)
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({})

  const setValue = <K extends keyof T>(key: K, value: T[K]) => {
    setValues(prev => ({ ...prev, [key]: value }))
    setErrors(prev => ({ ...prev, [key]: undefined }))
  }

  const reset = () => {
    setValues(initialValues)
    setErrors({})
  }

  return { values, errors, setValue, setErrors, reset }
}

// Single responsibility: Data fetching
export function useUsers() {
  const [users, setUsers] = useState<User[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    const fetchUsers = async () => {
      setIsLoading(true)
      try {
        const data = await api.getUsers()
        setUsers(data)
      } catch (err) {
        setError(err as Error)
      } finally {
        setIsLoading(false)
      }
    }
    fetchUsers()
  }, [])

  return { users, isLoading, error }
}
```

### 6. Design Context for Shared State

When state is needed across 3+ component levels:

```typescript
interface AuthContextValue {
  user: User | null
  login: (email: Email, password: string) => Promise<void>
  logout: () => Promise<void>
  isAuthenticated: boolean
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)

  const login = async (email: Email, password: string) => {
    const user = await api.login(email, password)
    setUser(user)
  }

  const logout = async () => {
    await api.logout()
    setUser(null)
  }

  const value = useMemo(
    () => ({ user, login, logout, isAuthenticated: !!user }),
    [user]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider')
  }
  return context
}
```

### 7. Plan Feature Structure

**Layer-based structure** (most common):
```
src/
├── components/
│   ├── LoginForm.tsx
│   ├── LoginForm.test.tsx
│   ├── RegisterForm.tsx
│   └── RegisterForm.test.tsx
├── hooks/
│   ├── useAuth.ts
│   ├── useAuth.test.ts
│   ├── useFormValidation.ts
│   └── useFormValidation.test.ts
├── contexts/
│   ├── AuthContext.tsx
│   └── AuthContext.test.tsx
├── types/
│   └── auth.ts               # Email, UserId, etc.
└── api/
    └── authApi.ts            # API calls
```

**Hybrid structure** (pages + shared layers):
```
src/
├── components/               # Shared components
│   ├── Button.tsx
│   └── Input.tsx
├── hooks/                   # Shared hooks
│   └── useDebounce.ts
├── pages/
│   └── auth/
│       ├── LoginPage.tsx
│       ├── components/
│       │   └── LoginForm.tsx    # Page-specific
│       └── hooks/
│           └── useLoginForm.ts  # Page-specific
└── types/
    └── auth.ts
```

**Feature-based structure** (alternative):
```
src/features/auth/
├── components/
│   ├── LoginForm.tsx
│   └── RegisterForm.tsx
├── hooks/
│   ├── useAuth.ts
│   └── useFormValidation.ts
├── context/
│   └── AuthContext.tsx
├── types.ts
└── api.ts
```

Choose the structure that matches your existing codebase.

### 8. Review Against Principles

Check design against (see reference.md):
- [ ] No primitive obsession (use Zod/branded types)
- [ ] Consistent architecture (match existing codebase structure)
- [ ] Component composition over prop drilling
- [ ] Custom hooks for reusable logic
- [ ] Context only when needed (3+ levels)
- [ ] Clear separation: presentational vs container
- [ ] Props interfaces well-defined

## Output Format

After design phase:

```
🎨 DESIGN PLAN

Feature: User Authentication

Core Domain Types:
✅ Email (Zod schema) - RFC 5322 validation, used in login/register
✅ UserId (branded type) - Non-empty string, prevents invalid IDs
✅ User (interface) - { id: UserId, email: Email, name: string }

Components:
✅ LoginForm (Presentational)
   Props: { email, password, onSubmit, isLoading, error }
   Responsibility: UI only, no state

✅ LoginContainer (Container)
   Responsibility: State management, form handling, validation
   Uses: LoginForm, useAuth hook

✅ RegisterForm (Presentational)
   Props: { formData, onSubmit, isLoading, errors }
   Responsibility: UI only, no state

Custom Hooks:
✅ useAuth
   Returns: { user, login, logout, isAuthenticated, isLoading }
   Responsibility: Auth operations and state

✅ useFormValidation
   Returns: { values, errors, setValue, validate, reset }
   Responsibility: Form state and validation logic

Context:
✅ AuthContext
   Provides: { user, login, logout, isAuthenticated }
   Used by: Protected routes, user menu, profile pages
   Reason: Auth state needed across entire app

Feature Structure:
📁 src/
  ├── components/          # Reusable components
  │   ├── LoginForm.tsx
  │   ├── LoginForm.test.tsx
  │   ├── RegisterForm.tsx
  │   └── RegisterForm.test.tsx
  ├── pages/              # Top-level pages
  │   ├── LoginPage.tsx
  │   └── RegisterPage.tsx
  ├── hooks/              # Reusable hooks
  │   ├── useAuth.ts
  │   ├── useAuth.test.ts
  │   ├── useFormValidation.ts
  │   └── useFormValidation.test.ts
  ├── contexts/           # Shared contexts
  │   ├── AuthContext.tsx
  │   └── AuthContext.test.tsx
  ├── types/              # Type definitions
  │   └── auth.ts
  └── api/                # API client
      └── authApi.ts

Design Decisions:
- Email and UserId as validated types prevent runtime errors
- Zod for Email (form validation), branded type for UserId (type safety)
- LoginForm is reusable component, LoginPage composes it
- useAuth hook encapsulates auth logic for reuse across components
- AuthContext provides auth state to avoid prop drilling
- Layer-based structure: components/ for reusable, pages/ for top-level views

Integration Points:
- Consumed by: App routes, protected route wrapper, user menu
- Depends on: API client, token storage
- Events: User login/logout events for analytics

Next Steps:
1. Create types with validation (Zod schemas + branded types)
2. Write tests for types and hooks (React Testing Library)
3. Implement presentational components (LoginForm)
4. Implement container components (LoginContainer)
5. Add context provider (AuthContext)
6. Integration tests for full flows

Ready to implement? Use @testing skill for test structure (works with Jest, Vitest, etc.).
```

## Key Principles

See reference.md for detailed principles:
- Primitive obsession prevention (Zod schemas, branded types)
- Component composition patterns
- Consistent architecture (layer-based, hybrid, or feature-based)
- Custom hooks for reusable logic
- Context for shared state (use sparingly)
- Props interfaces and type safety

## Pre-Code Review Questions

Before writing code, ask:
- Can logic be moved into custom hooks?
- Is this component presentational or container?
- Should state be local or context?
- Have I avoided primitive obsession?
- Is validation in the right place?
- Does this follow the existing codebase architecture?
- Are components small and focused?

Only after satisfactory answers, proceed to implementation.

## Acceptance Criteria

**All criteria must be met before design is considered complete.**

### Mandatory Requirements (Must Pass)

1. **Architecture Consistency**
   - [ ] New code follows existing codebase architecture pattern
   - [ ] Layer-based, feature-based, or hybrid pattern identified and matched
   - [ ] File placement consistent with existing structure

2. **Type Safety**
   - [ ] No primitive obsession (domain concepts have dedicated types)
   - [ ] Zod schemas for runtime validation where needed
   - [ ] Branded types for type-safe identifiers
   - [ ] Props interfaces defined for all components
   - [ ] No `any` types in design

3. **Component Structure**
   - [ ] Clear separation: presentational vs container components
   - [ ] Single responsibility per component
   - [ ] Props interfaces use `readonly` where appropriate
   - [ ] No prop drilling (use context or composition for 3+ levels)

4. **Custom Hooks**
   - [ ] Reusable logic extracted to custom hooks
   - [ ] Hooks have single responsibility
   - [ ] Hook return types explicitly defined

5. **Design Documentation**
   - [ ] Design plan includes all components, hooks, types
   - [ ] Integration points identified
   - [ ] Dependencies documented

### Design Completion Checklist

```
✅ COMPONENT DESIGN ACCEPTANCE CRITERIA

Architecture:
[ ] Existing pattern identified (layer/feature/hybrid)
[ ] New code follows existing pattern
[ ] File structure planned consistently

Type Safety:
[ ] Domain types defined (no primitive obsession)
[ ] Zod schemas for validation
[ ] Branded types for IDs
[ ] No any types

Components:
[ ] Presentational vs container distinction clear
[ ] Single responsibility
[ ] Props interfaces defined
[ ] No prop drilling planned

Hooks:
[ ] Reusable logic identified for extraction
[ ] Single responsibility per hook
[ ] Return types defined

Documentation:
[ ] Design plan complete
[ ] Integration points documented
[ ] Ready for implementation

Design complete: All boxes checked ✅
```

### What Blocks Completion

The following will BLOCK design completion:
- Undefined architecture pattern
- Primitive obsession in type design
- Missing props interfaces
- Prop drilling in component hierarchy
- Unclear component responsibilities

### Design Output Requirements

Design must include:
1. **Core Domain Types** - All validated types with Zod or branded types
2. **Component List** - Each with props interface and responsibility
3. **Custom Hooks** - Each with parameters and return type
4. **Context** - If needed, with provider and consumer pattern
5. **Feature Structure** - File/folder organization
6. **Integration Points** - How feature connects to existing code

## Additional Resources

- **reference.md** - Complete design principles and patterns
- **examples.md** - Real-world examples from codebase standards:
  - Presentational vs Container components
  - Props management with Readonly pattern
  - State updates (functional vs direct)
  - Component composition patterns
  - Data test IDs and React best practices
