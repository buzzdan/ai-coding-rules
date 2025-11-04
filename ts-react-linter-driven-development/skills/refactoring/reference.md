# Refactoring Reference (React/TypeScript)

## Linter-Driven Refactoring Philosophy

Let complexity metrics guide refactoring decisions:
- **Cognitive Complexity**: How hard is it to understand?
- **Cyclomatic Complexity**: How many paths through the code?
- **Expression Complexity**: How many operators in one expression?
- **Nesting Level**: How deeply nested are control structures?

When these exceed thresholds, code becomes harder to maintain, test, and debug.

## SonarJS Complexity Metrics

### Cognitive Complexity (max: 15)

**What it measures**: Mental effort to understand code

**Increments for**:
- Nested structures (+1 per level)
- Breaks in linear flow (if, switch, loops)
- Recursion
- Logical operators in conditions

**Primary fix**: **Storifying** - See dedicated section below for detailed examples and techniques

**Fix strategies**:
- Storify the code (make it read like a story at single abstraction level)
- Extract custom hooks
- Extract helper functions at same conceptual level
- Early returns
- Guard clauses

### Cyclomatic Complexity (max: 10)

**What it measures**: Number of independent paths through code

**Increments for**:
- if, else, case
- &&, ||
- while, for, do-while
- catch
- Ternary operators

**Fix strategies**:
- Early returns
- Extract conditions to variables
- Replace complex switches with object mapping
- Simplify boolean logic

### Expression Complexity (max: 5)

**What it measures**: Number of operators in single expression

**Increments for**:
- &&, ||
- Ternary operators (? :)

**Fix strategies**:
- Extract to intermediate variables
- Extract to helper functions
- Use early returns instead of complex conditions

### Max Lines Per Function (max: 200)

**What it measures**: Function/component size

**Fix strategies**:
- Extract components
- Extract custom hooks
- Extract helper functions
- Split concerns (UI vs logic)

### Nesting Level (max: 4)

**What it measures**: Depth of nested control structures

**Fix strategies**:
- Early returns
- Guard clauses
- Invert conditions
- Extract nested logic to functions

## Storifying: Making Code Read Like a Story

**Core Principle**: Each function should operate at a single conceptual level. Don't mix high-level business logic with low-level implementation details in the same function.

**Why it matters**:
- Reduces cognitive complexity
- Makes code easier to understand at a glance
- Each abstraction level is testable independently
- Changes are isolated to appropriate levels

This is the PRIMARY technique for reducing cognitive complexity. When the linter flags high cognitive complexity, storifying is usually the solution.

### Bad Example - Mixed Abstraction Levels

```tsx
function processUserRegistration(userData: FormData) {
  // High-level step
  const user = {
    name: userData.get('name'),
    // Low-level validation detail (wrong level!)
    email: userData.get('email')?.toString().toLowerCase().trim() || '',
  }

  // More low-level details mixed with high-level logic
  if (!user.email.includes('@') || user.email.length < 5) {
    throw new Error('Invalid email')
  }

  // Database call (infrastructure detail)
  const existingUser = db.query('SELECT * FROM users WHERE email = ?', [user.email])
  if (existingUser) {
    throw new Error('User exists')
  }

  // More database details
  db.query('INSERT INTO users (name, email) VALUES (?, ?)', [user.name, user.email])

  // Email sending details
  const transporter = nodemailer.createTransport({...})
  transporter.sendMail({
    to: user.email,
    subject: 'Welcome',
    text: 'Welcome to our app!'
  })
}
```

**Problems**:
- Mixes 4 levels: parsing, validation, database, email
- Hard to test (requires mocking database and email)
- Hard to understand (what's the main flow?)
- Hard to change (modifications touch many concerns)

### Good Example - Storified (Single Abstraction Level)

```tsx
// Top-level function reads like a story - all at same conceptual level
function processUserRegistration(userData: FormData): void {
  const user = parseUserData(userData)
  validateUserDoesNotExist(user.email)
  saveUser(user)
  sendWelcomeEmail(user.email)
}

// Each helper function handles one level of abstraction
function parseUserData(formData: FormData): User {
  const rawEmail = formData.get('email')?.toString() || ''
  return {
    name: formData.get('name')?.toString() || '',
    email: Email.parse(rawEmail), // Email is a branded type with validation
  }
}

function validateUserDoesNotExist(email: Email): void {
  const exists = userRepository.existsByEmail(email)
  if (exists) {
    throw new UserAlreadyExistsError(email)
  }
}

function saveUser(user: User): void {
  userRepository.save(user)
}

function sendWelcomeEmail(email: Email): void {
  emailService.send({
    to: email,
    template: 'welcome',
  })
}
```

**Benefits**:
- Main function reads like a story: parse, validate, save, email
- Each step at same abstraction level
- Easy to test each function independently
- Easy to understand the flow
- Easy to change (each function isolated)

### React Component Example - Mixed vs Storified

**Bad - Mixed Levels**:
```tsx
function UserProfile({ userId }: Props) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Mixing: HTTP details + state management + error handling
    fetch(`/api/users/${userId}`)
      .then(res => {
        if (!res.ok) throw new Error('Failed')
        return res.json()
      })
      .then(data => {
        setUser(data)
        setLoading(false)
      })
      .catch(err => {
        console.error(err)
        setLoading(false)
      })
  }, [userId])

  // Mixing: loading logic + rendering + styling
  if (loading) return <div style={{ padding: 20 }}>Loading...</div>
  if (!user) return <div style={{ padding: 20 }}>Not found</div>

  return (
    <div style={{ padding: 20 }}>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  )
}
```

**Good - Storified**:
```tsx
// Component: High-level story of "display user profile"
function UserProfile({ userId }: Props) {
  const { user, loading, error } = useUser(userId)

  return (
    <UserProfileView
      user={user}
      loading={loading}
      error={error}
    />
  )
}

// Hook: Handles all data fetching concerns at one level
function useUser(userId: string) {
  const [state, setState] = useState<UserState>({ status: 'loading' })

  useEffect(() => {
    loadUser(userId).then(
      user => setState({ status: 'success', user }),
      error => setState({ status: 'error', error })
    )
  }, [userId])

  return {
    user: state.status === 'success' ? state.user : null,
    loading: state.status === 'loading',
    error: state.status === 'error' ? state.error : null,
  }
}

// API layer: Handles HTTP concerns at one level
async function loadUser(userId: string): Promise<User> {
  const response = await fetch(`/api/users/${userId}`)
  if (!response.ok) {
    throw new UserLoadError(userId)
  }
  return response.json()
}

// View: Handles rendering concerns at one level
function UserProfileView({ user, loading, error }: ViewProps) {
  if (loading) return <LoadingSpinner />
  if (error) return <ErrorMessage error={error} />
  if (!user) return <NotFound />

  return (
    <Card>
      <UserHeader name={user.name} />
      <UserContact email={user.email} />
    </Card>
  )
}
```

### Storifying with Types/Classes

Sometimes the best way to storify is to extract to a **new type or class** instead of functions. This creates an elegant API, organizes related logic, and makes testing trivial.

#### When to Extract to Types (Not Just Functions)

Extract to a type/class when:
- Function has many parameters (>3-4)
- Related data and behavior should be grouped together
- Type represents a domain concept (Order, User, Payment)
- Logic needs to be reusable and testable independently
- You're passing the same set of data through multiple functions

#### Bad - Many Parameters

```tsx
function processOrder(
  orderId: string,
  userId: string,
  items: CartItem[],
  shippingStreet: string,
  shippingCity: string,
  shippingZip: string,
  paymentMethod: string,
  cardNumber: string,
  discountCode: string,
  giftWrap: boolean
): Promise<OrderResult> {
  // Validate order ID
  if (!orderId || orderId.length < 10) {
    throw new Error('Invalid order ID')
  }

  // Calculate totals
  let total = 0
  for (const item of items) {
    total += item.price * item.quantity
  }

  // Apply discount
  if (discountCode === 'SAVE10') {
    total *= 0.9
  }

  // Add shipping
  if (shippingCity === 'Remote') {
    total += 15
  } else {
    total += 5
  }

  // Process payment
  // ... more logic

  return { success: true, total }
}

// Nightmare to call
await processOrder(
  'ORD-123456',
  'USR-789',
  cartItems,
  '123 Main St',
  'Springfield',
  '12345',
  'credit_card',
  '4111-1111-1111-1111',
  'SAVE10',
  true
)
```

**Problems**:
- 10 parameters (hard to remember order)
- Mixed abstraction levels
- Hard to test (need to mock everything)
- Hard to extend (adding parameter breaks all callers)
- No place for related behavior

#### Good - Extract to Order Type

```tsx
// Domain types with validation
type OrderId = string & { readonly __brand: 'OrderId' }
type UserId = string & { readonly __brand: 'UserId' }

class Money {
  constructor(private readonly cents: number) {}

  static dollars(amount: number): Money {
    return new Money(Math.round(amount * 100))
  }

  add(other: Money): Money {
    return new Money(this.cents + other.cents)
  }

  multiply(factor: number): Money {
    return new Money(Math.round(this.cents * factor))
  }

  toDollars(): number {
    return this.cents / 100
  }
}

class ShippingAddress {
  constructor(
    readonly street: string,
    readonly city: string,
    readonly zip: string
  ) {}

  isRemoteLocation(): boolean {
    return this.city === 'Remote'
  }
}

class Order {
  constructor(
    private readonly orderId: OrderId,
    private readonly userId: UserId,
    private readonly items: CartItem[],
    private readonly shipping: ShippingAddress,
    private readonly payment: PaymentMethod,
    private discount?: DiscountCode,
    private giftWrap: boolean = false
  ) {}

  // All logic organized into methods
  validate(): ValidationResult {
    if (this.items.length === 0) {
      return { valid: false, error: 'Cart is empty' }
    }
    return { valid: true }
  }

  calculateSubtotal(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(Money.dollars(item.price).multiply(item.quantity)),
      Money.dollars(0)
    )
  }

  calculateShipping(): Money {
    return this.shipping.isRemoteLocation()
      ? Money.dollars(15)
      : Money.dollars(5)
  }

  applyDiscount(code: DiscountCode): void {
    this.discount = code
  }

  calculateTotal(): Money {
    let total = this.calculateSubtotal()

    if (this.discount) {
      total = total.multiply(this.discount.factor)
    }

    total = total.add(this.calculateShipping())

    if (this.giftWrap) {
      total = total.add(Money.dollars(5))
    }

    return total
  }

  async process(): Promise<OrderResult> {
    const validation = this.validate()
    if (!validation.valid) {
      throw new OrderValidationError(validation.error)
    }

    const total = this.calculateTotal()
    await this.payment.charge(total)
    await this.sendConfirmation()

    return { success: true, total: total.toDollars() }
  }

  private async sendConfirmation(): Promise<void> {
    // Email logic
  }
}

// Usage - reads like a story, elegant API
const order = new Order(
  orderId,
  userId,
  cartItems,
  new ShippingAddress('123 Main St', 'Springfield', '12345'),
  new CreditCardPayment('4111-1111-1111-1111'),
  undefined,
  true
)

order.applyDiscount(DiscountCode.SAVE10)
await order.process()
```

**Benefits**:
- Fields instead of long parameter list
- Related logic organized into methods
- Each method does one thing (single abstraction level)
- Easy to test each method independently
- Natural place for domain behavior
- Type-safe, self-documenting

#### Testing Benefits

```tsx
// Testing a type is trivial - just instantiate and call methods
describe('Order', () => {
  const createTestOrder = () => new Order(
    OrderId.parse('ORD-123'),
    UserId.parse('USR-789'),
    [{ id: '1', price: 50, quantity: 2 }],
    new ShippingAddress('123 Main', 'Springfield', '12345'),
    new MockPayment()
  )

  it('calculates subtotal correctly', () => {
    const order = createTestOrder()
    expect(order.calculateSubtotal()).toEqual(Money.dollars(100))
  })

  it('applies discount correctly', () => {
    const order = createTestOrder()
    order.applyDiscount(DiscountCode.SAVE10)
    const total = order.calculateTotal()
    // 100 * 0.9 + 5 shipping = 95
    expect(total.toDollars()).toBe(95)
  })

  it('charges remote shipping for remote locations', () => {
    const order = new Order(
      orderId,
      userId,
      items,
      new ShippingAddress('123 Main', 'Remote', '12345'), // Remote city
      payment
    )
    expect(order.calculateShipping()).toEqual(Money.dollars(15))
  })

  it('validates empty cart', () => {
    const order = new Order(orderId, userId, [], shipping, payment)
    expect(order.validate()).toEqual({
      valid: false,
      error: 'Cart is empty'
    })
  })
})

// Compare to testing the function version - nightmare with 10 parameters!
```

#### React Hook Example with Type

**Bad - Complex hook with scattered logic**:
```tsx
function useFormValidation(initialValues: Record<string, string>) {
  const [values, setValues] = useState(initialValues)
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [touched, setTouched] = useState<Record<string, boolean>>({})
  const [isSubmitting, setIsSubmitting] = useState(false)

  const validateEmail = (email: string) => {
    return email.includes('@') && email.length > 5
  }

  const validatePassword = (password: string) => {
    return password.length >= 8
  }

  const handleChange = (field: string, value: string) => {
    setValues(prev => ({ ...prev, [field]: value }))

    // Validation logic mixed in
    if (field === 'email' && !validateEmail(value)) {
      setErrors(prev => ({ ...prev, email: 'Invalid email' }))
    } else if (field === 'password' && !validatePassword(value)) {
      setErrors(prev => ({ ...prev, password: 'Password too short' }))
    } else {
      setErrors(prev => {
        const newErrors = { ...prev }
        delete newErrors[field]
        return newErrors
      })
    }
  }

  const handleBlur = (field: string) => {
    setTouched(prev => ({ ...prev, [field]: true }))
  }

  return { values, errors, touched, isSubmitting, handleChange, handleBlur }
}
```

**Good - Extract to FormState type**:
```tsx
class FormState {
  constructor(
    private values: Record<string, string>,
    private errors: Record<string, string> = {},
    private touched: Record<string, boolean> = {}
  ) {}

  getValue(field: string): string {
    return this.values[field] || ''
  }

  getError(field: string): string | undefined {
    return this.touched[field] ? this.errors[field] : undefined
  }

  setValue(field: string, value: string): FormState {
    const newValues = { ...this.values, [field]: value }
    const validation = this.validateField(field, value)

    return new FormState(
      newValues,
      validation.valid
        ? this.removeError(field)
        : { ...this.errors, [field]: validation.error },
      this.touched
    )
  }

  markTouched(field: string): FormState {
    return new FormState(
      this.values,
      this.errors,
      { ...this.touched, [field]: true }
    )
  }

  private validateField(field: string, value: string): ValidationResult {
    switch (field) {
      case 'email':
        return this.validateEmail(value)
      case 'password':
        return this.validatePassword(value)
      default:
        return { valid: true }
    }
  }

  private validateEmail(email: string): ValidationResult {
    return email.includes('@') && email.length > 5
      ? { valid: true }
      : { valid: false, error: 'Invalid email' }
  }

  private validatePassword(password: string): ValidationResult {
    return password.length >= 8
      ? { valid: true }
      : { valid: false, error: 'Password must be at least 8 characters' }
  }

  private removeError(field: string): Record<string, string> {
    const { [field]: _, ...rest } = this.errors
    return rest
  }

  isValid(): boolean {
    return Object.keys(this.errors).length === 0
  }
}

// Hook is now trivial - just wraps the type
function useFormState(initialValues: Record<string, string>) {
  const [state, setState] = useState(() => new FormState(initialValues))

  const handleChange = (field: string, value: string) => {
    setState(prev => prev.setValue(field, value))
  }

  const handleBlur = (field: string) => {
    setState(prev => prev.markTouched(field))
  }

  return { state, handleChange, handleBlur }
}

// Usage in component - clean and elegant
function LoginForm() {
  const { state, handleChange, handleBlur } = useFormState({
    email: '',
    password: ''
  })

  return (
    <form>
      <Input
        value={state.getValue('email')}
        error={state.getError('email')}
        onChange={e => handleChange('email', e.target.value)}
        onBlur={() => handleBlur('email')}
      />
    </form>
  )
}

// Testing the FormState type is trivial
describe('FormState', () => {
  it('validates email correctly', () => {
    let state = new FormState({ email: 'invalid' })
    state = state.setValue('email', 'invalid')
    state = state.markTouched('email')
    expect(state.getError('email')).toBe('Invalid email')
  })
})
```

### Key Storifying Techniques

1. **Extract functions** - One responsibility per function
2. **Extract to types/classes** - Group related data and behavior, create elegant APIs
3. **Use custom hooks** - Separate stateful logic from presentation
4. **Create layers** - Component → Hook → Service → API
5. **Name descriptively** - Function names tell the story
6. **Early returns** - Reduce nesting, clarify flow
7. **Branded types** - Push validation to type level (Email, UserId)

### When to Apply Storifying

Apply storifying when:
- Linter reports cognitive complexity > 15
- Function mixes different levels of abstraction
- Hard to summarize what function does in one sentence
- Testing requires many mocks
- Making changes touches unrelated concerns

### Storifying Process

1. **Read the function** - What's the high-level story?
2. **Identify abstraction levels** - What's high-level? What's low-level?
3. **Extract low-level details** - Create helper functions with descriptive names
4. **Rewrite main function** - Use only extracted helpers
5. **Verify readability** - Main function should read like a story
6. **Test each piece** - Each extracted function is now testable

## React-Specific Refactoring Patterns

### 1. Extract Custom Hook

**When**: Component mixing UI with business logic

```typescript
// Pattern
function useFeature(input: Input): Output {
  const [state, setState] = useState(initialState)

  // Complex logic here
  useEffect(() => {
    // Side effects
  }, [dependencies])

  return { state, actions }
}

function Component() {
  const { state, actions } = useFeature(input)
  return <UI state={state} actions={actions} />
}
```

**Benefits**:
- Testable in isolation
- Reusable across components
- Clearer component responsibility
- Reduced component complexity

### 2. Extract Component

**When**: Large component (>200 lines) or doing multiple things

```typescript
// Pattern: Break down by responsibility
function FeatureComponent() {
  return (
    <Container>
      <FeatureHeader />
      <FeatureContent />
      <FeatureActions />
    </Container>
  )
}

// Each sub-component focuses on one thing
function FeatureHeader() { /* ... */ }
function FeatureContent() { /* ... */ }
function FeatureActions() { /* ... */ }
```

**Benefits**:
- Smaller, focused components
- Easier to test
- Reusable pieces
- Clear separation of concerns

### 3. Extract Helper Function

**When**: Complex logic inline in component/hook

```typescript
// Pattern
function determineUserAccess(user: User, resource: Resource): AccessLevel {
  // Complex logic extracted
  if (!user.isActive) return 'none'
  if (user.roles.includes('admin')) return 'full'
  if (isResourceOwner(user, resource)) return 'owner'
  return 'read'
}

function Component() {
  const access = determineUserAccess(user, resource)
  if (access === 'none') return <Unauthorized />
  return <Content access={access} />
}
```

**Benefits**:
- Named, understandable logic
- Testable independently
- Reusable
- Reduces component complexity

### 4. Extract Validation (Zod)

**When**: Complex validation logic in components

```typescript
// Pattern
import { z } from 'zod'

const UserSchema = z.object({
  email: z.string().email(),
  age: z.number().min(18).max(150),
  country: z.enum(['US', 'UK', 'CA'])
})

type User = z.infer<typeof UserSchema>

// Validation separated from component logic
function validateUser(data: unknown): User {
  return UserSchema.parse(data)
}
```

**Benefits**:
- Declarative validation
- Runtime type safety
- Reusable schemas
- Clear error messages

### 5. Compound Components

**When**: Component has multiple related parts

```typescript
// Pattern
function Card({ children }: { children: ReactNode }) {
  return <div className='card'>{children}</div>
}

Card.Header = function CardHeader({ children }) {
  return <div className='card-header'>{children}</div>
}

Card.Body = function CardBody({ children }) {
  return <div className='card-body'>{children}</div>
}

Card.Footer = function CardFooter({ children }) {
  return <div className='card-footer'>{children}</div>
}

// Usage
<Card>
  <Card.Header>Title</Card.Header>
  <Card.Body>Content</Card.Body>
  <Card.Footer>Actions</Card.Footer>
</Card>
```

**Benefits**:
- Flexible composition
- Related components grouped
- Clear API
- Prevents prop drilling

## Common Refactoring Scenarios

### Scenario 1: Form Component Too Complex

**Problem**: Large form component with validation

**Solution**:
```typescript
// Before: Everything in one component (300+ lines)
function RegistrationForm() {
  // validation, state, submission all mixed
}

// After: Extracted to multiple concerns
// 1. Validation schema
const RegistrationSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  confirmPassword: z.string()
}).refine(
  (data) => data.password === data.confirmPassword,
  { message: "Passwords don't match" }
)

// 2. Custom hook for form logic
function useRegistrationForm() {
  const { values, errors, setValue, handleSubmit } = useFormValidation(
    RegistrationSchema,
    { email: '', password: '', confirmPassword: '' },
    submitRegistration
  )
  return { values, errors, setValue, handleSubmit }
}

// 3. Small presentational component
function RegistrationForm() {
  const { values, errors, setValue, handleSubmit } = useRegistrationForm()

  return (
    <form onSubmit={handleSubmit}>
      <EmailInput value={values.email} onChange={v => setValue('email', v)} error={errors.email} />
      <PasswordInput value={values.password} onChange={v => setValue('password', v)} error={errors.password} />
      <PasswordInput value={values.confirmPassword} onChange={v => setValue('confirmPassword', v)} error={errors.confirmPassword} />
      <SubmitButton>Register</SubmitButton>
    </form>
  )
}
```

### Scenario 2: Data Fetching Component

**Problem**: Component with complex data fetching logic

**Solution**:
```typescript
// Before: All in component
function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState(null)
  const [posts, setPosts] = useState([])
  const [isLoading, setIsLoading] = useState(false)
  // ... 100+ lines of fetch logic
}

// After: Extracted to custom hooks
function useUser(userId: string) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then(setUser)
      .catch(setError)
      .finally(() => setIsLoading(false))
  }, [userId])

  return { user, isLoading, error }
}

function useUserPosts(userId: string) {
  const [posts, setPosts] = useState<Post[]>([])
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    fetch(`/api/users/${userId}/posts`)
      .then(res => res.json())
      .then(setPosts)
      .finally(() => setIsLoading(false))
  }, [userId])

  return { posts, isLoading }
}

// Component simplified
function UserProfile({ userId }: { userId: string }) {
  const { user, isLoading: userLoading, error } = useUser(userId)
  const { posts, isLoading: postsLoading } = useUserPosts(userId)

  if (userLoading) return <Spinner />
  if (error) return <ErrorMessage error={error} />
  if (!user) return <NotFound />

  return (
    <div>
      <UserInfo user={user} />
      {postsLoading ? <Spinner /> : <PostList posts={posts} />}
    </div>
  )
}
```

### Scenario 3: Complex Conditional Rendering

**Problem**: Many nested conditionals in JSX

**Solution**:
```typescript
// Before: Nested ternaries (Expression Complexity: 8)
<div>
  {user ? (
    user.isPremium ? (
      user.hasActiveSubscription ? (
        <PremiumContent />
      ) : (
        <SubscriptionExpired />
      )
    ) : (
      <FreeContent />
    )
  ) : (
    <LoginPrompt />
  )}
</div>

// After: Early returns in component
function ContentDisplay({ user }: { user: User | null }) {
  if (!user) return <LoginPrompt />
  if (!user.isPremium) return <FreeContent />
  if (!user.hasActiveSubscription) return <SubscriptionExpired />
  return <PremiumContent />
}

// Or: Extract to helper
function getContentComponent(user: User | null): ComponentType {
  if (!user) return LoginPrompt
  if (!user.isPremium) return FreeContent
  if (!user.hasActiveSubscription) return SubscriptionExpired
  return PremiumContent
}

function ContentDisplay({ user }: { user: User | null }) {
  const ContentComponent = getContentComponent(user)
  return <ContentComponent />
}
```

### Scenario 4: Switch Statement for Component Selection

**Problem**: Long switch statement for rendering different components

**Solution**:
```typescript
// Before: Long switch (Cyclomatic Complexity: 12)
function NotificationDisplay({ type }: { type: string }) {
  switch (type) {
    case 'success': return <SuccessNotification />
    case 'error': return <ErrorNotification />
    case 'warning': return <WarningNotification />
    case 'info': return <InfoNotification />
    // ... 10 more cases
    default: return null
  }
}

// After: Object mapping (Cyclomatic Complexity: 1)
const NOTIFICATION_COMPONENTS: Record<NotificationType, ComponentType> = {
  success: SuccessNotification,
  error: ErrorNotification,
  warning: WarningNotification,
  info: InfoNotification,
  // ... more mappings
}

function NotificationDisplay({ type }: { type: NotificationType }) {
  const Component = NOTIFICATION_COMPONENTS[type]
  return Component ? <Component /> : null
}
```

### Scenario 5: useEffect with Complex Dependencies

**Problem**: useEffect with many dependencies, hard to track

**Solution**:
```typescript
// Before: Complex dependencies
useEffect(() => {
  fetchData(userId, filters.category, filters.price, sortBy, page)
}, [userId, filters, filters.category, filters.price, sortBy, page])

// After: Stable object with useMemo
const queryParams = useMemo(
  () => ({
    userId,
    category: filters.category,
    price: filters.price,
    sortBy,
    page
  }),
  [userId, filters.category, filters.price, sortBy, page]
)

useEffect(() => {
  fetchData(queryParams)
}, [queryParams])

// Or: Extract to custom hook
function useDataFetch(userId: string, filters: Filters, sortBy: string, page: number) {
  const [data, setData] = useState([])

  useEffect(() => {
    fetchData(userId, filters, sortBy, page).then(setData)
  }, [userId, filters, sortBy, page])

  return data
}
```

## Refactoring Checklist

Before refactoring:
- [ ] Tests exist and pass
- [ ] Understand current behavior
- [ ] Identify root cause of complexity

During refactoring:
- [ ] One pattern at a time
- [ ] Run tests after each change
- [ ] Keep commits small and focused
- [ ] Ensure linter passes

After refactoring:
- [ ] All tests pass
- [ ] Linter passes
- [ ] Code more readable
- [ ] Complexity reduced
- [ ] Behavior unchanged

## Anti-Patterns to Avoid

### ❌ Premature Optimization

Don't extract everything immediately. Wait for:
- Linter failures
- Code feeling complex
- Need for reuse

### ❌ Over-Extraction

Don't create hooks/components for single-use, simple logic:
```typescript
// ❌ Over-extracted
function useButtonClick(onClick: () => void) {
  return () => onClick()
}

// ✅ Just use directly
<button onClick={onClick}>
```

### ❌ God Hooks

Don't create hooks that do everything:
```typescript
// ❌ God hook
function useEverything() {
  const user = useUser()
  const posts = usePosts()
  const comments = useComments()
  const likes = useLikes()
  // ... everything else
  return { /* massive object */ }
}
```

### ❌ Prop Drilling Fixation

Don't use context for everything. Props are fine for 1-2 levels:
```typescript
// ✅ Props fine for this
<Parent>
  <Child data={data} />
</Parent>

// ✅ Context better for this
<Parent>
  <MiddleLayer>
    <AnotherLayer>
      <DeepChild />  {/* needs data */}
    </AnotherLayer>
  </MiddleLayer>
</Parent>
```

## Summary

### Key Principles

1. **Single Responsibility**: Each component/hook does one thing
2. **Extract Early**: Don't wait for linter to fail
3. **Composition**: Combine simple pieces, not complex ones
4. **Guard Clauses**: Exit early, reduce nesting
5. **Named Logic**: Extract and name complex conditions
6. **Hooks for Logic**: Components for UI
7. **Zod for Validation**: Declarative, reusable

### Refactoring Priority

When linter fails:
1. **Cognitive Complexity** → Extract hooks/functions, early returns
2. **Cyclomatic Complexity** → Early returns, simplify conditionals
3. **Expression Complexity** → Extract to variables/functions
4. **Max Lines** → Extract components/hooks
5. **Nesting** → Guard clauses, early returns

### Quick Wins

- Replace nested ternaries with early returns
- Extract complex conditions to variables
- Move business logic to custom hooks
- Use Zod for validation
- Extract nested components
- Replace switches with object mapping

Trust the linter. When it fails, there's real complexity to address.
