# Refactoring Examples

> **Source**: Linter-driven development patterns and best practices for TypeScript + React

## Table of Contents
1. [Avoid IIFE (Immediately Invoked Function Expressions)](#avoid-iife)
2. [No Empty Blocks or Workarounds](#no-empty-blocks-or-workarounds)
3. [Magic Numbers](#magic-numbers)
4. [Comments Philosophy](#comments-philosophy)
   - [Where Comments Are Acceptable](#where-comments-are-acceptable)
   - [Where Comments Are NOT Acceptable](#where-comments-are-not-acceptable)
5. [Complex Conditionals to Early Returns](#complex-conditionals-to-early-returns)

---

## Avoid IIFE

### Rule: Don't create and immediately invoke functions. Use lookup objects or helper functions instead.

```typescript
// ❌ Bad - IIFE pattern
const value = (() => {
  switch (type) {
    case 'a': return 1
    case 'b': return 2
    default: return 0
  }
})()

// ✅ Good - Lookup object
const TYPE_VALUES: Record<string, number> = {
  a: 1,
  b: 2
}
const value = TYPE_VALUES[type] ?? 0

// ✅ Good - Helper function
function getValueForType(type: string): number {
  const TYPE_VALUES: Record<string, number> = {
    a: 1,
    b: 2
  }
  return TYPE_VALUES[type] ?? 0
}

const value = getValueForType(type)
```

**Why avoid IIFE:**
- Less readable and harder to understand
- Adds unnecessary complexity
- Lookup objects are clearer and more maintainable
- Named functions are better for debugging

### More Complex Example

```typescript
// ❌ Bad - IIFE with complex logic
const userStatus = (() => {
  if (user.isPremium) {
    if (user.subscriptionActive) {
      return 'premium-active'
    } else {
      return 'premium-expired'
    }
  } else if (user.isTrial) {
    if (user.trialExpired) {
      return 'trial-expired'
    } else {
      return 'trial-active'
    }
  }
  return 'free'
})()

// ✅ Good - Extracted function with clear name
function getUserStatus(user: User): UserStatus {
  if (user.isPremium) {
    return user.subscriptionActive ? 'premium-active' : 'premium-expired'
  }
  if (user.isTrial) {
    return user.trialExpired ? 'trial-expired' : 'trial-active'
  }
  return 'free'
}

const userStatus = getUserStatus(user)
```

---

## No Empty Blocks or Workarounds

### Rule: Don't create empty blocks or comment-only blocks just to satisfy linter rules. Refactor instead.

```typescript
// ❌ Bad - Empty else block just for the rule
if (value !== undefined && value !== null) {
  process(value)
} else {
  // Do nothing
}

// ❌ Bad - If-else-if without meaningful final else
if (status === 'active') {
  return 'green'
} else if (status === 'pending') {
  return 'yellow'
} else {
  // Default case - do nothing
}

// ✅ Good - Early returns, no empty blocks
if (value === undefined || value === null) {
  return
}
process(value)

// ✅ Good - All branches have meaning
if (status === 'active') {
  return 'green'
} else if (status === 'pending') {
  return 'yellow'
} else {
  return 'gray' // Actual default value
}

// ✅ Better - Avoid if-else chains entirely
const STATUS_COLORS: Record<string, string> = {
  active: 'green',
  pending: 'yellow'
}
const color = STATUS_COLORS[status] ?? 'gray'
```

### Philosophy

**Code should have meaning, not just satisfy rules**

- Code should have meaning, not just satisfy rules
- Refactor to avoid needing workarounds
- Use early returns, lookup objects, or helper functions
- Every line of code should serve a purpose

### Common Refactoring Strategies

1. **Early returns** - Check edge cases first, return early
2. **Lookup objects** - Replace if-else chains with objects + nullish coalescing
3. **Helper functions** - Extract complex conditions
4. **Guard clauses** - Filter out invalid cases at the start

#### Strategy 1: Early Returns

```typescript
// ❌ Bad - Unnecessary else block
function processUser(user: User | null) {
  if (user && user.isActive) {
    updateUser(user)
  } else {
    // Do nothing
  }
}

// ✅ Good - Early return
function processUser(user: User | null) {
  if (!user || !user.isActive) {
    return
  }
  updateUser(user)
}
```

#### Strategy 2: Lookup Objects

```typescript
// ❌ Bad - Long if-else chain
function getStatusColor(status: string): string {
  if (status === 'success') {
    return 'green'
  } else if (status === 'error') {
    return 'red'
  } else if (status === 'warning') {
    return 'yellow'
  } else if (status === 'info') {
    return 'blue'
  } else {
    return 'gray'
  }
}

// ✅ Good - Lookup object
const STATUS_COLORS: Record<string, string> = {
  success: 'green',
  error: 'red',
  warning: 'yellow',
  info: 'blue'
}

function getStatusColor(status: string): string {
  return STATUS_COLORS[status] ?? 'gray'
}
```

#### Strategy 3: Helper Functions

```typescript
// ❌ Bad - Complex nested conditions
function shouldShowFeature(user: User, feature: Feature) {
  if (user) {
    if (user.isActive) {
      if (user.hasPermission(feature.requiredPermission)) {
        if (feature.isEnabled) {
          return true
        } else {
          return false
        }
      } else {
        return false
      }
    } else {
      return false
    }
  } else {
    return false
  }
}

// ✅ Good - Helper function with early returns
function shouldShowFeature(user: User | null, feature: Feature): boolean {
  if (!user || !user.isActive) return false
  if (!user.hasPermission(feature.requiredPermission)) return false
  if (!feature.isEnabled) return false
  return true
}

// ✅ Even better - Descriptive helper functions
function isUserEligible(user: User | null): boolean {
  return user !== null && user.isActive
}

function hasFeatureAccess(user: User, feature: Feature): boolean {
  return user.hasPermission(feature.requiredPermission) && feature.isEnabled
}

function shouldShowFeature(user: User | null, feature: Feature): boolean {
  return isUserEligible(user) && hasFeatureAccess(user!, feature)
}
```

#### Strategy 4: Guard Clauses

```typescript
// ❌ Bad - Deeply nested
function processOrder(order: Order) {
  if (order) {
    if (order.items.length > 0) {
      if (order.isPaid) {
        if (order.shippingAddress) {
          shipOrder(order)
        }
      }
    }
  }
}

// ✅ Good - Guard clauses
function processOrder(order: Order | null) {
  if (!order) return
  if (order.items.length === 0) return
  if (!order.isPaid) return
  if (!order.shippingAddress) return

  shipOrder(order)
}
```

---

## Magic Numbers

### Rule: Extract unexplained numeric literals to named constants

```typescript
// ❌ Bad - Unclear meaning
setTimeout(callback, 300000)
const discount = price * 0.85
if (retries > 5) { }

// ✅ Good - Named constants
const FIVE_MINUTES_MS = 300000
const STANDARD_DISCOUNT_RATE = 0.85
const MAX_RETRIES = 5

setTimeout(callback, FIVE_MINUTES_MS)
const discount = price * STANDARD_DISCOUNT_RATE
if (retries > MAX_RETRIES) { }
```

### When Numbers Are Allowed

✅ **Auto-ignored by config:**
- `-1, 0, 1, 2, 10, 100` - Common values (eslint config)
- Array indexes: `items[5]`, `array.slice(0, 10)`
- Default parameters: `function getData(limit = 100)`
- Type literals: `type Status = 1 | 2 | 3`
- Tuple indexes: `const [first, second] = tuple`

✅ **Use existing constants for capacity/time:**
- `1000` for bytes → use `BYTE_METRIC_BASE` (capacity conversions)
- `1000` for time → use `MILLISECS_IN_SECOND`, `NANOSECS_IN_MICROSEC`, etc.
- `1024` → use `BYTE_METRIC_BASE2` (binary capacity conversions)
- Check `utils/consts.ts` for existing constants before creating new ones

❌ **Must extract to named constants:**
```typescript
// ❌ Bad
const timeout = 5000
const maxRetries = 3
const bufferSize = 8192
const discountRate = 0.15

// ✅ Good
const DEFAULT_TIMEOUT_MS = 5000
const MAX_RETRY_ATTEMPTS = 3
const BUFFER_SIZE_BYTES = 8192
const EARLY_BIRD_DISCOUNT_RATE = 0.15
```

### Rule of Thumb

- If the number needs explanation → extract it
- If naming doesn't add clarity → use inline disable or add to ignore list
- Don't create `FIVE = 5` - that's ridiculous

### Real-World Examples

```typescript
// ❌ Bad - What do these numbers mean?
function validatePassword(password: string): boolean {
  return password.length >= 8 && password.length <= 128
}

function retryRequest(attempt: number): boolean {
  return attempt < 3
}

// ✅ Good - Clear meaning
const MIN_PASSWORD_LENGTH = 8
const MAX_PASSWORD_LENGTH = 128
const MAX_REQUEST_ATTEMPTS = 3

function validatePassword(password: string): boolean {
  return password.length >= MIN_PASSWORD_LENGTH &&
         password.length <= MAX_PASSWORD_LENGTH
}

function retryRequest(attempt: number): boolean {
  return attempt < MAX_REQUEST_ATTEMPTS
}
```

```typescript
// ❌ Bad - Timeout with magic number
useEffect(() => {
  const timer = setTimeout(() => {
    showNotification()
  }, 3000)
  return () => clearTimeout(timer)
}, [])

// ✅ Good - Named constant
const NOTIFICATION_DISPLAY_DURATION_MS = 3000

useEffect(() => {
  const timer = setTimeout(() => {
    showNotification()
  }, NOTIFICATION_DISPLAY_DURATION_MS)
  return () => clearTimeout(timer)
}, [])
```

---

## Comments Philosophy

### Rule: Avoid unnecessary comments. Code should be self-explanatory.

### Where Comments Are Acceptable

Comments MAY be used at the **file level** to explain:
- A custom hook's overall purpose and usage pattern
- Complex architectural decisions
- Non-obvious module responsibilities

```typescript
// ✅ Good - File-level comment for a complex hook
/**
 * useVirtualizedList - Manages virtualized rendering for large lists.
 *
 * Handles scroll position tracking, visible item calculation, and
 * dynamic height measurement. Uses IntersectionObserver for performance.
 *
 * @example
 * const { visibleItems, containerProps } = useVirtualizedList(items, { itemHeight: 50 })
 */
export function useVirtualizedList<T>(items: T[], options: VirtualizedOptions) {
  // Implementation...
}
```

### Where Comments Are NOT Acceptable

**Never comment:**
- Functions (use descriptive names)
- Variables (name should explain purpose)
- Individual code lines (refactor if unclear)

```typescript
// ❌ Bad - Comment on function
// Gets the user's full name
function getName(user: User) {
  return `${user.firstName} ${user.lastName}`
}

// ✅ Good - Self-explanatory name
function getUserFullName(user: User) {
  return `${user.firstName} ${user.lastName}`
}

// ❌ Bad - Comment on variable
// The maximum number of retries
const max = 3

// ✅ Good - Self-explanatory name
const MAX_RETRY_ATTEMPTS = 3

// ❌ Bad - Comment on code line
const filtered = items.filter(item => item.isActive) // Filter to active items only

// ✅ Good - No comment needed, code is clear
const activeItems = items.filter(item => item.isActive)
```

### When NOT to Comment

```typescript
// ❌ Bad - Comment states the obvious
const userName = user.name

// ❌ Bad - Comment repeats the code
items.forEach(item => process(item))

// ❌ Bad - Comment explains what's clear from name
interface ButtonProps {
  label: string
  onClick: () => void
}
```

### When TO Comment (WHY, not WHAT)

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

### Guidelines

1. **Name things well** - Good names eliminate need for comments
2. **Extract functions** - Instead of commenting a code block, extract it to a well-named function
3. **Use types** - TypeScript types document better than comments
4. **Explain WHY, not WHAT** - Code shows what, comments explain why
5. **Keep comments updated** - Outdated comments are worse than no comments
6. **File-level only** - If you must comment, do it at the file/module level, not inline

### Examples of Good Naming vs Comments

```typescript
// ❌ Bad - Comment needed because name is poor
// Gets active users who logged in within last 30 days
function getUsers() {
  // ...
}

// ✅ Good - Name is self-documenting
function getActiveUsersFromLast30Days() {
  // ...
}

// ❌ Bad - Comment explains what code does
// Loop through items and calculate total price
let total = 0
for (const item of items) {
  total += item.price * item.quantity
}

// ✅ Good - Extract to well-named function
function calculateTotalPrice(items: CartItem[]): number {
  return items.reduce((total, item) => total + item.price * item.quantity, 0)
}
```

---

## Complex Conditionals to Early Returns

### Pattern: Deep nesting → Early returns

```typescript
// ❌ Bad - Deep nesting (Cyclomatic Complexity: 12, Nesting: 5)
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

### Pattern: Extract Complex Conditions

```typescript
// ❌ Bad - Complex condition (Expression Complexity: 8)
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

// ✅ Good - Extracted to helper functions
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

### Pattern: Replace Switch with Lookup

```typescript
// ❌ Bad - Long switch (Cyclomatic Complexity: 12)
function getStatusColor(status: string): string {
  switch (status) {
    case 'success': return 'green'
    case 'error': return 'red'
    case 'warning': return 'yellow'
    case 'info': return 'blue'
    case 'pending': return 'orange'
    case 'cancelled': return 'gray'
    case 'draft': return 'lightgray'
    default: return 'black'
  }
}

// ✅ Good - Object mapping (Cyclomatic Complexity: 1)
const STATUS_COLORS: Record<string, string> = {
  success: 'green',
  error: 'red',
  warning: 'yellow',
  info: 'blue',
  pending: 'orange',
  cancelled: 'gray',
  draft: 'lightgray'
}

function getStatusColor(status: string): string {
  return STATUS_COLORS[status] ?? 'black'
}
```
