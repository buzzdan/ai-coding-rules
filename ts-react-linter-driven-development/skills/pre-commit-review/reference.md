# Pre-Commit Review Reference (React/TypeScript)

## Review Philosophy

**Advisory, not blocking**: Inform decisions, don't prevent commits.

**Debt-based categories**: Focus on future maintainability cost.

**Context-aware**: Review changes plus broader file context.

## Complete Review Checklist

### 1. Architecture Patterns

#### ✅ Feature-Based Structure
```
src/features/auth/
├── components/        # Auth UI components
├── hooks/            # Auth custom hooks
├── context/          # Auth context
├── types.ts          # Auth types
└── index.ts          # Public API
```

#### 🔴 Technical Layer Structure (Design Debt)
```
src/
├── components/auth.tsx
├── hooks/auth.ts
├── contexts/auth.tsx
└── types/auth.ts
```

**Impact**: Features spread across directories, hard to find all related code.

### 2. Primitive Obsession

#### String Primitives

**🔴 Design Debt**:
```typescript
interface User {
  id: string          // Empty? Invalid format?
  email: string       // Validated? Format?
  phone: string       // Format? Country code?
}

function getUser(id: string): User  // Any string accepted
```

**✅ Better**:
```typescript
// Branded types
type UserId = Brand<string, 'UserId'>
type Email = Brand<string, 'Email'>

// Or Zod schemas
const UserIdSchema = z.string().uuid()
const EmailSchema = z.string().email()

type UserId = z.infer<typeof UserIdSchema>
type Email = z.infer<typeof EmailSchema>

interface User {
  id: UserId
  email: Email
  phone: PhoneNumber
}

function getUser(id: UserId): User  // Only valid IDs accepted
```

#### Re-Validating Composed Types

**🔴 Design Debt**: Re-validating after Zod parse or branded type construction
```typescript
// ❌ Re-validates composed types
function createUser(email: Email, id: UserId) {
  if (!email.includes('@')) { ... }  // EmailSchema already validated this
}

// ✅ Trusts validated types
function createUser(email: Email, id: UserId) {
  return { email, id, createdAt: new Date() }
}
```

Each type must own its validation — callers of validated types should trust them.

#### Relies on Upstream Validation

**🔴 Design Debt**: Type with no schema or constructor — relies on callers to validate
```typescript
// ❌ No validation — every caller must remember to check
interface UserInput {
  email: string
  age: number
}

// ✅ Owns its own validation
const UserInputSchema = z.object({
  email: z.string().email(),
  age: z.number().min(0).max(150),
})
type UserInput = z.infer<typeof UserInputSchema>
```

#### Number Primitives

**🔴 Design Debt**:
```typescript
interface Product {
  price: number       // Negative? Too large?
  quantity: number    // Negative? Zero?
  rating: number      // Range? Decimal places?
}
```

**✅ Better**:
```typescript
const PriceSchema = z.number().positive().max(1000000)
const QuantitySchema = z.number().int().nonnegative()
const RatingSchema = z.number().min(0).max(5)

type Price = z.infer<typeof PriceSchema>
type Quantity = z.infer<typeof QuantitySchema>
type Rating = z.infer<typeof RatingSchema>
```

#### Boolean State Machines

**🟡 Readability Debt**:
```typescript
const [isLoading, setIsLoading] = useState(false)
const [isSuccess, setIsSuccess] = useState(false)
const [isError, setIsError] = useState(false)

// Can have invalid states: isLoading && isSuccess
```

**✅ Better**: Discriminated union
```typescript
type State =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error }

// Impossible states are impossible
```

### 3. Component Design

#### Prop Drilling

**🔴 Design Debt**: State passed through 3+ levels
```typescript
<GrandParent user={user}>
  <Parent user={user} onUpdate={onUpdate}>
    <Child user={user} onUpdate={onUpdate}>
      <GrandChild user={user} onUpdate={onUpdate} />
    </Child>
  </Parent>
</GrandParent>
```

**✅ Fix options**:
1. Context for truly global state
2. Composition to avoid passing props
3. Accept prop drilling for 1-2 levels (it's fine!)

#### Mixed Concerns

**🟡 Readability Debt**: UI + business logic mixed
```typescript
function UserProfile() {
  // 50 lines of data fetching
  // 30 lines of validation
  // 40 lines of state management
  // 80 lines of JSX
  // Total: 200 lines, hard to test
}
```

**✅ Better**: Separated concerns
```typescript
// testable business logic
function useUserProfile(userId) {
  // fetch, validate, manage state
  return { user, isLoading, error, actions }
}

// testable UI
function UserProfile({ userId }) {
  const { user, isLoading, error, actions } = useUserProfile(userId)

  if (isLoading) return <Spinner />
  if (error) return <ErrorDisplay error={error} />
  return <UserDisplay user={user} actions={actions} />
}
```

#### God Components

**🔴 Design Debt**: Component doing too much (>200 lines)

**Signs**:
- Multiple state variables (5+)
- Many useEffect hooks
- Complex conditional rendering
- Mixed abstraction levels

**Fix**: Extract components and hooks

### 4. Hook Design

#### Hook Extraction

**🟡 Readability Debt**: Logic that should be a hook
```typescript
function Component() {
  // 50 lines of reusable logic
  // directly in component
}
```

**✅ Better**:
```typescript
function useFeature() {
  // extracted, testable, reusable
}

function Component() {
  const feature = useFeature()
  return <UI feature={feature} />
}
```

#### Hook Dependencies

**🟡 Readability Debt**: Complex dependencies
```typescript
useEffect(() => {
  fetchData(id, filters.category, filters.price, sort, page)
}, [id, filters, filters.category, filters.price, sort, page]) // Redundant, complex
```

**✅ Better**:
```typescript
const params = useMemo(
  () => ({ id, category: filters.category, price: filters.price, sort, page }),
  [id, filters.category, filters.price, sort, page]
)

useEffect(() => {
  fetchData(params)
}, [params])

// Or extract to custom hook
function useData(id, filters, sort, page) {
  useEffect(() => {
    fetchData(id, filters, sort, page)
  }, [id, filters, sort, page])
}
```

### 5. Accessibility Review

#### Semantic HTML

| ❌ Don't Use | ✅ Use Instead | Why |
|-------------|--------------|-----|
| `<div onClick>` | `<button>` | Keyboard accessible, screen reader friendly |
| `<div>` for text | `<p>`, `<span>` | Proper semantics |
| `<div>` for navigation | `<nav>` | Landmark for screen readers |
| `<div>` for lists | `<ul>`, `<ol>` | Proper list semantics |
| `<div>` for headings | `<h1>`-`<h6>` | Document outline |

#### Form Accessibility

**🔴 Design Debt**: Missing labels
```typescript
<input type="text" placeholder="Email" />
<input type="password" placeholder="Password" />
```

**✅ Better**:
```typescript
<label htmlFor="email">Email</label>
<input id="email" type="text" />

<label htmlFor="password">Password</label>
<input id="password" type="password" />
```

**🟢 Polish**: Enhanced with descriptions
```typescript
<label htmlFor="email">Email</label>
<input
  id="email"
  type="email"
  aria-describedby="email-hint"
  aria-required="true"
/>
<span id="email-hint">We'll never share your email.</span>
```

#### Interactive Elements

**🔴 Design Debt**: Non-semantic interactive elements
```typescript
<div onClick={handleClick}>
  Click me
</div>
```

**✅ Better**: Semantic button
```typescript
<button onClick={handleClick}>
  Click me
</button>
```

**If div required**:
```typescript
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      handleClick()
    }
  }}
>
  Click me
</div>
```

#### Images and Media

**🔴 Design Debt**: Missing alt text
```typescript
<img src="avatar.jpg" />
```

**🟢 Polish**: Generic alt text
```typescript
<img src="avatar.jpg" alt="avatar" />
```

**✅ Better**: Descriptive alt text
```typescript
<img src="avatar.jpg" alt="John Doe's profile picture" />
```

**Decorative images**:
```typescript
<img src="decoration.svg" alt="" role="presentation" />
```

#### Dynamic Content

**🟢 Polish**: Loading without announcement
```typescript
{isLoading && <Spinner />}
```

**✅ Better**: Announced loading
```typescript
{isLoading && (
  <div role="status" aria-live="polite">
    <span className="sr-only">Loading user data...</span>
    <Spinner aria-hidden="true" />
  </div>
)}
```

**Error announcements**:
```typescript
{error && (
  <div role="alert" aria-live="assertive">
    {error.message}
  </div>
)}
```

#### Modal Accessibility

**🔴 Design Debt**: Basic modal
```typescript
{isOpen && (
  <div className="modal">
    <div className="content">
      <h2>Title</h2>
      <p>Content</p>
      <button onClick={onClose}>Close</button>
    </div>
  </div>
)}
```

**✅ Better**: Accessible modal
```typescript
{isOpen && (
  <div
    role="dialog"
    aria-modal="true"
    aria-labelledby="modal-title"
    onKeyDown={(e) => e.key === 'Escape' && onClose()}
  >
    <div className="content">
      <h2 id="modal-title">Title</h2>
      <p>Content</p>
      <button onClick={onClose} aria-label="Close dialog">
        Close
      </button>
    </div>
  </div>
)}
```

**With focus management**:
```typescript
function Modal({ isOpen, onClose, children }) {
  const modalRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (isOpen && modalRef.current) {
      const previousActiveElement = document.activeElement
      modalRef.current.focus()

      return () => {
        previousActiveElement?.focus()
      }
    }
  }, [isOpen])

  // ... rest of modal
}
```

#### Color and Contrast

**🟡 Readability Debt**: Color-only indicators
```typescript
<span style={{ color: 'red' }}>Error</span>
<span style={{ color: 'green' }}>Success</span>
```

**✅ Better**: Multiple indicators
```typescript
<span style={{ color: 'red' }}>
  <ErrorIcon aria-hidden="true" />
  <span>Error</span>
</span>
```

**With ARIA**:
```typescript
<span
  style={{ color: 'red' }}
  role="alert"
  aria-label="Error"
>
  <ErrorIcon aria-hidden="true" />
  <span>Invalid email address</span>
</span>
```

### 6. TypeScript Usage

#### Type Safety

**🔴 Design Debt**: Using `any`
```typescript
function processData(data: any) {
  // No type safety
}
```

**✅ Better**: Proper types or `unknown` with validation
```typescript
const DataSchema = z.object({
  id: z.string(),
  name: z.string()
})

function processData(data: unknown) {
  const validated = DataSchema.parse(data) // Throws on invalid
  // validated is now typed
}
```

#### Props Interfaces

**🟡 Readability Debt**: Inline props type
```typescript
function Button(props: {
  label: string
  onClick: () => void
  variant?: 'primary' | 'secondary'
}) {
  // ...
}
```

**✅ Better**: Named interface
```typescript
interface ButtonProps {
  label: string
  onClick: () => void
  variant?: 'primary' | 'secondary'
}

function Button({ label, onClick, variant = 'primary' }: ButtonProps) {
  // ...
}
```

#### Discriminated Unions

**🟡 Readability Debt**: Multiple booleans for state
```typescript
interface State {
  isLoading: boolean
  isSuccess: boolean
  isError: boolean
  data?: Data
  error?: Error
}
```

**✅ Better**: Discriminated union
```typescript
type State =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: Data }
  | { status: 'error'; error: Error }

// Type narrowing works automatically
if (state.status === 'success') {
  state.data // Available, typed correctly
}
```

### 7. Testing Implications

#### Testability

**🔴 Design Debt**: Untestable component
```typescript
function Component() {
  // 200 lines of tightly coupled logic
  // Can't test without implementation details
}
```

**✅ Better**: Separated, testable
```typescript
// testable hook
function useLogic() {
  return { state, actions }
}

// testable component
function Component() {
  const { state, actions } = useLogic()
  return <UI state={state} actions={actions} />
}
```

### 8. Error Handling

#### Missing Error Boundaries

**🔴 Design Debt**: No error handling
```typescript
function AsyncComponent() {
  const data = useAsyncData() // Can throw
  return <Display data={data} />
}
```

**✅ Better**: Error boundary wrapper
```typescript
<ErrorBoundary fallback={<ErrorDisplay />}>
  <AsyncComponent />
</ErrorBoundary>
```

**Or component-level handling**:
```typescript
function AsyncComponent() {
  const { data, error, isLoading } = useAsyncData()

  if (isLoading) return <Spinner />
  if (error) return <ErrorDisplay error={error} />
  if (!data) return <NotFound />

  return <Display data={data} />
}
```

## Review Priority

### Must Review (🔴 Design Debt)
1. Primitive obsession
2. Prop drilling (3+ levels)
3. Missing error boundaries
4. Non-semantic interactive elements
5. Missing form labels
6. Using `any` without validation

### Should Review (🟡 Readability Debt)
1. Mixed abstractions
2. Complex conditions
3. God components (>200 lines)
4. Missing hook extraction
5. Inline complex logic

### Nice to Review (🟢 Polish)
1. Missing JSDoc
2. Accessibility enhancements
3. Type improvements
4. Performance optimizations

## Advisory Stance

**Remember**: This is advisory, not blocking.

**User decides**:
- Accept debt (with awareness)
- Fix critical (design debt)
- Fix all
- Expand scope

**Always acknowledge**:
- Time constraints are real
- Team decisions are valid
- Consistency matters
- Sometimes "good enough" is right choice

**Provide options, not mandates**.
