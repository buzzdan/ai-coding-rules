# Pre-Commit Review Examples

> **Source**: Common code quality violations and design debt patterns for TypeScript + React

## Table of Contents
1. [Design Debt: IIFE Patterns](#design-debt-iife-patterns)
2. [Readability Debt: Empty Blocks](#readability-debt-empty-blocks)
3. [Readability Debt: Magic Numbers](#readability-debt-magic-numbers)
4. [Polish: Comment Quality](#polish-comment-quality)
5. [Polish: EMPTY_STRING Usage](#polish-empty_string-usage)
6. [Design Debt: Primitive Obsession](#design-debt-primitive-obsession)
7. [Design Debt: Prop Drilling](#design-debt-prop-drilling)

---

## Design Debt: IIFE Patterns

### Detection Pattern

Look for immediately invoked function expressions in code.

```typescript
// 🔴 Design Debt: IIFE pattern detected
const value = (() => {
  switch (type) {
    case 'a': return 1
    case 'b': return 2
    default: return 0
  }
})()

const status = (() => {
  if (user.isPremium) {
    return user.subscriptionActive ? 'active' : 'expired'
  }
  return 'free'
})()
```

### Review Finding Format

```
🔴 DESIGN DEBT: IIFE Pattern
Location: src/components/UserProfile.tsx:45
Current: const value = (() => { /* switch statement */ })()
Better:  Use lookup object or helper function
Why:     IIFEs are less readable, harder to debug, and add unnecessary complexity
Fix:     Replace with TYPE_VALUES lookup object or getValueForType() helper
```

### Suggested Fix

```typescript
// ✅ Good - Lookup object
const TYPE_VALUES: Record<string, number> = {
  a: 1,
  b: 2
}
const value = TYPE_VALUES[type] ?? 0

// ✅ Good - Helper function
function getUserStatus(user: User): UserStatus {
  if (user.isPremium) {
    return user.subscriptionActive ? 'active' : 'expired'
  }
  return 'free'
}
const status = getUserStatus(user)
```

---

## Readability Debt: Empty Blocks

### Detection Pattern

Look for empty else blocks, comment-only blocks, or "do nothing" blocks.

```typescript
// 🟡 Readability Debt: Empty else block
if (value !== undefined && value !== null) {
  process(value)
} else {
  // Do nothing
}

// 🟡 Readability Debt: Meaningless else
if (status === 'active') {
  return 'green'
} else if (status === 'pending') {
  return 'yellow'
} else {
  // Default case - do nothing
}

// 🟡 Readability Debt: Comment-only block
try {
  await riskyOperation()
} catch (error) {
  // Intentionally ignored
}
```

### Review Finding Format

```
🟡 READABILITY DEBT: Empty Block Workaround
Location: src/components/OrderProcessor.tsx:89
Current: Empty else block with "Do nothing" comment
Better:  Use early return or remove else entirely
Why:     Code should have meaning, not just satisfy linter rules
Fix:     Invert condition and use early return: if (!value) return; process(value)
```

### Suggested Fix

```typescript
// ✅ Good - Early return
if (value === undefined || value === null) {
  return
}
process(value)

// ✅ Good - All branches meaningful
if (status === 'active') {
  return 'green'
} else if (status === 'pending') {
  return 'yellow'
} else {
  return 'gray' // Actual default value
}

// ✅ Better - Lookup object
const STATUS_COLORS: Record<string, string> = {
  active: 'green',
  pending: 'yellow'
}
const color = STATUS_COLORS[status] ?? 'gray'

// ✅ Good - Handle error properly
try {
  await riskyOperation()
} catch (error) {
  logger.error('Operation failed', error)
  // Decide: rethrow, return default, or show user error
}
```

---

## Readability Debt: Magic Numbers

### Detection Pattern

Look for unexplained numeric literals (not in the auto-ignore list: -1, 0, 1, 2, 10, 100).

```typescript
// 🟡 Readability Debt: Magic numbers
setTimeout(callback, 300000)
const discount = price * 0.85
if (retries > 5) { }
const buffer = new Array(8192)

function validateAge(age: number): boolean {
  return age >= 18 && age <= 150
}
```

### Review Finding Format

```
🟡 READABILITY DEBT: Magic Number
Location: src/components/PaymentProcessor.tsx:123
Current: setTimeout(retryPayment, 300000)
Better:  const PAYMENT_RETRY_DELAY_MS = 300000; setTimeout(retryPayment, PAYMENT_RETRY_DELAY_MS)
Why:     Unclear what 300000 represents (5 minutes)
Fix:     Extract to named constant: PAYMENT_RETRY_DELAY_MS or FIVE_MINUTES_MS
```

### Suggested Fix

```typescript
// ✅ Good - Named constants
const FIVE_MINUTES_MS = 300000
const STANDARD_DISCOUNT_RATE = 0.85
const MAX_RETRIES = 5
const BUFFER_SIZE_BYTES = 8192
const MIN_LEGAL_AGE = 18
const MAX_REASONABLE_AGE = 150

setTimeout(callback, FIVE_MINUTES_MS)
const discount = price * STANDARD_DISCOUNT_RATE
if (retries > MAX_RETRIES) { }
const buffer = new Array(BUFFER_SIZE_BYTES)

function validateAge(age: number): boolean {
  return age >= MIN_LEGAL_AGE && age <= MAX_REASONABLE_AGE
}
```

### When to Skip

Don't flag these as magic numbers:
- Common values: -1, 0, 1, 2, 10, 100
- Array indexes: `items[5]`
- Default parameters: `function getData(limit = 100)`
- Type literals: `type Status = 1 | 2 | 3`
- Existing constants from `utils/consts.ts`: BYTE_METRIC_BASE, MILLISECS_IN_SECOND

---

## Polish: Comment Quality

### Detection Pattern

Look for comments that state the obvious or repeat the code.

```typescript
// 🟢 Polish: Unnecessary comment
// Set the user name
const userName = user.name

// 🟢 Polish: Comment repeats code
// Loop through items
items.forEach(item => process(item))

// 🟢 Polish: Comment explains what's clear from name
// Button props interface
interface ButtonProps {
  label: string
  onClick: () => void
}
```

### Review Finding Format

```
🟢 POLISH: Unnecessary Comment
Location: src/components/Button/Button.tsx:12
Current: // Button props interface
Better:  Remove comment - interface name is self-explanatory
Why:     Comment adds no value, code is self-documenting
Fix:     Delete comment or explain WHY if there's non-obvious reasoning
```

### When Comments Are Good

```typescript
// ✅ Good - Explains WHY, not WHAT
// Using String() instead of .toString() because value is unknown type
const stringValue = String(value)

// ✅ Good - Explains non-obvious business logic
// Discount only applies to enterprise customers with > 100 licenses
if (customer.type === 'enterprise' && customer.licenses > 100) {
  applyDiscount()
}

// ✅ Good - Documents intentional eslint disable
// eslint-disable-next-line react-hooks/exhaustive-deps
useEffect(() => {
  // Only run on mount, userId captured at initialization
  fetchData(initialUserId)
}, [])
```

---

## Polish: EMPTY_STRING Usage

### Detection Pattern

Look for empty string literals `''` that should use `EMPTY_STRING` constant.

```typescript
// 🟢 Polish: Should use EMPTY_STRING
const name = ''
const defaultValue = ''
const [email, setEmail] = useState('')

function formatName(firstName: string, lastName: string): string {
  if (!firstName && !lastName) {
    return ''
  }
  return `${firstName} ${lastName}`.trim()
}
```

### Review Finding Format

```
🟢 POLISH: Use EMPTY_STRING Constant
Location: src/components/UserForm.tsx:23
Current: const [email, setEmail] = useState('')
Better:  const [email, setEmail] = useState(EMPTY_STRING)
Why:     Consistent across codebase, semantic meaning, easier to search/replace
Fix:     Import EMPTY_STRING from utils/consts and use throughout file
```

### Suggested Fix

```typescript
// ✅ Good
import { EMPTY_STRING } from 'utils/consts'

const name = EMPTY_STRING
const defaultValue = EMPTY_STRING
const [email, setEmail] = useState(EMPTY_STRING)

function formatName(firstName: string, lastName: string): string {
  if (!firstName && !lastName) {
    return EMPTY_STRING
  }
  return `${firstName} ${lastName}`.trim()
}
```

### Note on EMPTY_OBJECT

**Don't use** `EMPTY_OBJECT` (if it exists) due to mutation risks. Use `{}` instead.

```typescript
// ✅ Good - Each call gets new object
function getData(options = {}) {
  // Safe to modify, new object every time
}

// ❌ Bad - Shared mutable reference
const EMPTY_OBJECT = {}
function getData(options = EMPTY_OBJECT) {
  options.foo = 'bar' // Mutates shared object!
}
```

---

## Design Debt: Primitive Obsession

### Detection Pattern

Look for primitive types representing domain concepts without validation.

```typescript
// 🔴 Design Debt: Primitive obsession
interface User {
  id: string  // What if empty? Not UUID?
  email: string  // What if invalid?
  age: number  // What if negative? 999?
}

function processUser(userId: string, email: string) {
  // No guarantee these are valid
  return api.updateUser(userId, email)
}

function validateEmail(email: string): boolean {
  return /\S+@\S+\.\S+/.test(email)
}
```

### Review Finding Format

```
🔴 DESIGN DEBT: Primitive Obsession
Location: src/types/user.ts:12
Current: email: string (no validation)
Better:  Use Zod EmailSchema or branded Email type
Why:     No type safety, validation not guaranteed, runtime errors possible
Fix:     Create self-validating types:
         - Zod: const EmailSchema = z.string().email(); type Email = z.infer<typeof EmailSchema>
         - Branded: type Email = Brand<string, 'Email'>; function createEmail(s: string): Email
```

### Suggested Fix

```typescript
// ✅ Good - Zod schema
import { z } from 'zod'

export const EmailSchema = z.string().email('Invalid email format')
export const UserIdSchema = z.string().uuid('UserId must be UUID')
export const AgeSchema = z.number().int().min(0).max(150)

export type Email = z.infer<typeof EmailSchema>
export type UserId = z.infer<typeof UserIdSchema>
export type Age = z.infer<typeof AgeSchema>

export const UserSchema = z.object({
  id: UserIdSchema,
  email: EmailSchema,
  age: AgeSchema
})

export type User = z.infer<typeof UserSchema>

// ✅ Good - Branded types
declare const __brand: unique symbol
type Brand<T, TBrand> = T & { [__brand]: TBrand }

export type Email = Brand<string, 'Email'>
export type UserId = Brand<string, 'UserId'>

export function createEmail(value: string): Email {
  if (!/\S+@\S+\.\S+/.test(value)) {
    throw new Error('Invalid email')
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

---

## Design Debt: Prop Drilling

### Detection Pattern

Look for props being passed through 3+ component levels.

```typescript
// 🔴 Design Debt: Prop drilling
function App() {
  const [user, setUser] = useState<User | null>(null)

  return <Dashboard user={user} onUserUpdate={setUser} />
}

function Dashboard({ user, onUserUpdate }: DashboardProps) {
  return (
    <div>
      <Sidebar user={user} onUserUpdate={onUserUpdate} />
      <Content user={user} onUserUpdate={onUserUpdate} />
    </div>
  )
}

function Sidebar({ user, onUserUpdate }: SidebarProps) {
  return (
    <div>
      <UserMenu user={user} onUserUpdate={onUserUpdate} />
    </div>
  )
}

function UserMenu({ user, onUserUpdate }: UserMenuProps) {
  // Finally used here, but passed through 3 levels!
  return <div>{user?.name}</div>
}
```

### Review Finding Format

```
🔴 DESIGN DEBT: Prop Drilling
Location: src/components/Dashboard.tsx:45
Current: user and onUserUpdate passed through App → Dashboard → Sidebar → UserMenu (3 levels)
Better:  Use UserContext or composition
Why:     Tight coupling, hard to maintain, intermediate components unnecessarily aware of user data
Fix:     Create UserContext: <UserProvider><Dashboard /></UserProvider>
         Or use composition: <Dashboard><UserMenu /></Dashboard>
```

### Suggested Fix Option 1: Context

```typescript
// ✅ Good - Context
interface UserContextValue {
  user: User | null
  updateUser: (user: User) => void
}

const UserContext = createContext<UserContextValue | null>(null)

export function UserProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)

  const value = useMemo(
    () => ({ user, updateUser: setUser }),
    [user]
  )

  return <UserContext.Provider value={value}>{children}</UserContext.Provider>
}

export function useUser() {
  const context = useContext(UserContext)
  if (!context) throw new Error('useUser must be within UserProvider')
  return context
}

// Usage - no prop drilling!
function App() {
  return (
    <UserProvider>
      <Dashboard />
    </UserProvider>
  )
}

function UserMenu() {
  const { user, updateUser } = useUser()
  return <div>{user?.name}</div>
}
```

### Suggested Fix Option 2: Composition

```typescript
// ✅ Good - Composition (when UserMenu is only place that needs user)
function App() {
  const [user, setUser] = useState<User | null>(null)

  return (
    <Dashboard>
      <UserMenu user={user} onUserUpdate={setUser} />
    </Dashboard>
  )
}

function Dashboard({ children }: { children: ReactNode }) {
  return (
    <div>
      <Sidebar />
      <Content />
      {children} {/* UserMenu rendered here */}
    </div>
  )
}
```

---

## Review Checklist

When reviewing code, check for:

### 🔴 Design Debt (Recommended to fix)
- [ ] IIFE patterns (use lookup objects or helpers)
- [ ] Primitive obsession (use Zod schemas or branded types)
- [ ] Prop drilling (3+ levels → use context)
- [ ] Missing type validation (runtime data not validated)
- [ ] No error boundaries (async operations need error handling)
- [ ] Wrong architecture (technical layers instead of feature-based)

### 🟡 Readability Debt (Consider fixing)
- [ ] Empty blocks or workarounds (use early returns, lookup objects)
- [ ] Magic numbers (extract to named constants)
- [ ] Mixed abstractions (business logic mixed with UI)
- [ ] Complex conditions (extract to helper functions)
- [ ] God components (doing too many things)
- [ ] Missing hook extraction (logic that should be custom hooks)

### 🟢 Polish Opportunities (Optional)
- [ ] Unnecessary comments (remove or explain WHY)
- [ ] EMPTY_STRING usage (consistency)
- [ ] Missing JSDoc (complex types/hooks)
- [ ] Accessibility enhancements (ARIA, semantic HTML)
- [ ] Type improvements (more specific than any/unknown)
- [ ] Performance (unnecessary rerenders)
