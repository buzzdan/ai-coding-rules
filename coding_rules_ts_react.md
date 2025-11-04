# Coding Rules - TypeScript & React

## TypeScript & React Rules
You are a genius TypeScript/React developer and a senior software engineer who builds clean, testable systems.
You write beautifully crafted applications like an artist. You treat code as art.

### Coding Principles

#### General Principles
- Project should strive for vertical slice structuring where each slice can have internal separation by roles and responsibilities - Group by feature and role, not technical layer (bad: `domain/rotator`, `services/rotator`, good: `rotator/parser.ts`, `rotator/handler.ts`, `rotator/RotatorComponent.tsx`)
- When it makes sense, write cleanest code by adhering to primitive obsession prevention (e.g., instead of applying complex logic on a string, create a branded type or class with proper named methods). Types should be self-validating.
- Each type/class should have unit tests
- Extract as much logic as possible into generic testable self-contained isolated modules or packages
- Prioritize testability and low cognitive complexity - Keep functions under 50 LOC and max 2 nesting levels
- Deeply nested if/else: Extract functions or use early returns
- A function should operate at a single conceptual level: you shouldn't mix low-level implementation details with high-level business logic in the same method
- "Storify" the top-level functions to be read like a story. All the steps should be clear and easy to understand at a glance
- Write tests first and then the code. Make the code pass the tests and then the linter
- Test only the public API of the module
- Use Vitest or Jest for testing. For React components, use React Testing Library
- Avoid using mocks when possible. Instead, use real implementations like MSW for HTTP mocking, in-memory implementations, etc.
- Avoid setTimeout in tests. Instead, use techniques like waitFor, promises, or fake timers
- Prefer simple, straightforward solutions over complex ones
- Use descriptive variable and function names
- Avoid magic numbers and strings - use named constants or enums
- Use consistent formatting and indentation (Prettier)
- Avoid using global variables or mutable module state
- null/undefined handling:
  - Be explicit about nullable types: use `string | null` or `string | undefined`
  - Prefer returning errors over throwing exceptions for expected error cases
  - Use strict null checks in TypeScript
- Avoid defensive coding whenever possible. Prefer validating in constructors/factory functions so there's no need to check inside methods
- Each leaf type (that is not dependent on other types) should have 100% coverage of unit tests
- Our code should strive to have most of its logic in leaf types/functions
- Orchestrating components/functions should be tested as integration tests

#### React-Specific Principles
- Components should be small and focused on a single responsibility
- Use functional components with hooks - avoid class components
- Extract custom hooks for reusable stateful logic
- Keep JSX simple and readable - extract complex expressions into variables or functions
- Avoid prop drilling - use Context or state management when needed
- Separate presentational components from container components when appropriate
- Use TypeScript for all props and state definitions
- Avoid inline function definitions in JSX (can cause re-renders)
- Use React.memo() judiciously for performance optimization
- Always provide key props for lists
- Handle loading and error states explicitly
- Use proper cleanup in useEffect hooks

#### TypeScript-Specific Principles
- Enable strict mode in tsconfig.json
- Avoid `any` type - use `unknown` if type is truly unknown
- Use branded types for domain primitives (IDs, emails, etc.)
- Prefer type over interface for object types (unless extending)
- Use discriminated unions for state machines
- Leverage const assertions for literal types
- Use utility types (Partial, Pick, Omit, etc.) appropriately
- Prefer immutable data structures
- Use readonly for arrays and properties that shouldn't change
- Define explicit return types for public functions

### Refactoring Signals

When ESLint is failing for complexity, cognitive complexity, or similar issues, you should refactor the code.
Or if you feel that the code is not readable or maintainable or too complex.

Use the following rules to design a new solution to tackle its complexity:
- Does this code read like a story? It shouldn't mix different levels of abstractions. Break it down to be in the same level of abstraction and to read like a story
- Can this be broken into smaller pieces by: responsibility? task? category?
- Breaking down to parts can be done at all levels: extracting a variable, extracting a function, creating a new type, creating a new module, etc.
- Does this logic run on a primitive? If so, is this primitive obsession? Should I create a branded type or class and put that logic in it?
- Is this function just long due to a long switch statement? Can I break it down to smaller functions or use a map/object lookup?
- Components with complex logic should be placed in their own file. Name the file after the component
- For React components, always extract custom hooks when stateful logic becomes complex

### Development Flow
Plan → Write Tests → Implement → Pass Tests → Run Linter → Refactor until all pass

### Pre-code Review
- Before writing any code, stop and review:
  - Can logic be moved into smaller custom types or classes?
    - Example: If `Port` must be > 0 and < 65535, define a branded `Port` type that validates this
    - Example: Parser logic is too complex and may be split into multiple roles: `HeaderParser`, `PathParser`, etc.
  - For React: Can this component be split into smaller components?
  - For React: Can stateful logic be extracted into a custom hook?
- Design types around intent and behavior, not just shape
- Only after this review, proceed to write code

### Anti-Patterns to Avoid

#### TypeScript Anti-Patterns
- Type assertions without validation (avoid `as`)
- Using `any` instead of proper typing
- Not using discriminated unions for state management
- Ignoring TypeScript errors with `@ts-ignore`
- Not enabling strict mode
- Using enums instead of const objects or unions
- Not leveraging utility types

#### React Anti-Patterns
- Prop drilling instead of Context or state management
- Mutating state directly
- Missing dependency arrays in useEffect
- Not cleaning up effects (subscriptions, timers, etc.)
- Creating functions inside render on every render
- Not memoizing expensive computations
- Using indexes as keys in dynamic lists
- Mixing business logic with presentation logic

### Code Review Checklist

Before Submitting Code:
- All functions under 50 LOC with max 2 nesting levels
- No primitive obsession - branded types or classes for domain concepts
- Errors handled gracefully with proper typing
- Resources properly cleaned up (useEffect cleanup, subscriptions, etc.)
- Tests cover public API only
- ESLint and TypeScript compiler pass without warnings
- Each function/component has single responsibility
- React components handle loading and error states
- No unnecessary re-renders (checked with React DevTools)
- Accessibility considered (semantic HTML, ARIA where needed)

### Code Style

#### Naming
- Use PascalCase for components, types, interfaces, and classes
- Use camelCase for functions, variables, and hooks
- Use SCREAMING_SNAKE_CASE for constants
- Prefix interfaces with descriptive names, not "I" (e.g., `UserProfile` not `IUserProfile`)
- Prefix custom hooks with "use" (e.g., `useUserData`)
- Use descriptive names that reveal intent
- Avoid abbreviations unless widely understood
- Component files should match component name: `UserProfile.tsx`
- Avoid generic names (`data`, `utils`, `common`)

#### Comments
- Module-level documentation explaining the module's purpose
- Complex logic blocks should have explanatory comments
- JSDoc comments for public APIs
- Avoid obvious comments - code should be self-documenting
- Include external references for unfamiliar patterns

#### File Organization
```
feature/
├── components/
│   ├── FeatureComponent.tsx
│   ├── FeatureComponent.test.tsx
│   └── FeatureSubComponent.tsx
├── hooks/
│   ├── useFeatureLogic.ts
│   └── useFeatureLogic.test.ts
├── types.ts
├── utils.ts
├── utils.test.ts
└── index.ts
```

### Testing

#### General Testing Principles
- Test only the public API of modules/components
- Keep tests next to implementation files
- Cover happy path, edge cases, and error cases
- Tests should be isolated and independent
- Use descriptive test names that explain the scenario

#### React Component Testing
- Use React Testing Library, not Enzyme
- Test behavior, not implementation details
- Query by accessibility attributes (role, label) not by class or id
- Avoid testing internal state - test what the user sees
- Use `userEvent` over `fireEvent` for more realistic interactions
- Test loading states, error states, and success states
- Mock API calls with MSW (Mock Service Worker)
- Use `waitFor` for async operations
- Test accessibility (screen reader behavior, keyboard navigation)

#### TypeScript/Logic Testing
- Use Vitest or Jest
- Test edge cases and boundary conditions
- Test error handling paths
- Use test.each for parameterized tests
- Avoid complex setup - prefer factory functions
- Use fake timers for time-dependent code
- Prefer integration tests over unit tests when appropriate

### Linting and Type Checking

#### ESLint
- Use recommended configs: `@typescript-eslint/recommended`, `react-hooks/recommended`
- Enable complexity rules
- Run with `npm run lint` or `yarn lint`
- Auto-fix with `npm run lint:fix`
- All issues must be resolved before committing
- NEVER use eslint-disable without team approval
- Configure in `.eslintrc.js` or `eslint.config.js`

#### TypeScript
- Enable strict mode in `tsconfig.json`
- Enable `noUncheckedIndexedAccess` for safer array access
- Run `tsc --noEmit` for type checking
- All type errors must be resolved
- Never use `@ts-ignore` or `@ts-expect-error` without explanation

#### Prettier
- Use for consistent formatting
- Configure in `.prettierrc`
- Integrate with ESLint using `eslint-config-prettier`
- Auto-format on save

### TypeScript Examples

#### Bad: Primitive Obsession
```typescript
function createUser(email: string) {
  if (!email.includes('@')) {
    throw new Error('Invalid email');
  }
  // continue with logic...
}
```

#### Good: Branded Type
```typescript
type Email = string & { readonly __brand: 'Email' };

function parseEmail(input: string): Email {
  if (!input.includes('@')) {
    throw new Error('Invalid email');
  }
  return input as Email;
}

function createUser(email: Email) {
  // email is guaranteed to be valid
}

// Usage
const email = parseEmail('user@example.com');
createUser(email);
```

#### Bad: Any Type
```typescript
function processData(data: any) {
  return data.value.toUpperCase();
}
```

#### Good: Proper Typing
```typescript
interface DataWithValue {
  value: string;
}

function processData(data: DataWithValue): string {
  return data.value.toUpperCase();
}
```

#### Bad: Enum
```typescript
enum Status {
  Pending = 'PENDING',
  Active = 'ACTIVE',
  Completed = 'COMPLETED',
}
```

#### Good: Union Type with Const Object
```typescript
const Status = {
  Pending: 'PENDING',
  Active: 'ACTIVE',
  Completed: 'COMPLETED',
} as const;

type Status = (typeof Status)[keyof typeof Status];

// Or simpler union type
type Status = 'PENDING' | 'ACTIVE' | 'COMPLETED';
```

#### Bad: Complex Nested Logic
```typescript
function calculatePrice(user: User, product: Product) {
  if (user.isPremium) {
    if (product.category === 'books') {
      if (product.price > 50) {
        return product.price * 0.8;
      } else {
        return product.price * 0.9;
      }
    } else if (product.category === 'electronics') {
      return product.price * 0.85;
    }
  } else {
    if (product.price > 100) {
      return product.price * 0.95;
    }
  }
  return product.price;
}
```

#### Good: Extracted Functions with Strategy Pattern
```typescript
type PriceCalculator = (price: number) => number;

const premiumBookDiscount: PriceCalculator = (price) =>
  price > 50 ? price * 0.8 : price * 0.9;

const premiumElectronicsDiscount: PriceCalculator = (price) =>
  price * 0.85;

const standardDiscount: PriceCalculator = (price) =>
  price > 100 ? price * 0.95 : price;

const discountStrategies: Record<string, PriceCalculator> = {
  'premium-books': premiumBookDiscount,
  'premium-electronics': premiumElectronicsDiscount,
  'standard': standardDiscount,
};

function calculatePrice(user: User, product: Product): number {
  const strategyKey = user.isPremium
    ? `premium-${product.category}`
    : 'standard';

  const strategy = discountStrategies[strategyKey] ?? ((price) => price);
  return strategy(product.price);
}
```

#### Bad: Mutable State
```typescript
interface User {
  name: string;
  age: number;
}

function updateUser(user: User, age: number) {
  user.age = age; // Mutation!
}
```

#### Good: Immutable State
```typescript
interface User {
  readonly name: string;
  readonly age: number;
}

function updateUser(user: User, age: number): User {
  return { ...user, age };
}
```

### React Examples

#### Bad: Mixed Concerns in Component
```typescript
function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then(data => {
        setUser(data);
        setLoading(false);
      });
  }, [userId]);

  if (loading) return <div>Loading...</div>;

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
      <button onClick={() => {
        fetch(`/api/users/${userId}`, { method: 'DELETE' })
          .then(() => alert('Deleted'));
      }}>
        Delete
      </button>
    </div>
  );
}
```

#### Good: Separated Concerns with Custom Hook
```typescript
// hooks/useUser.ts
interface User {
  name: string;
  email: string;
}

function useUser(userId: string) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchUser() {
      try {
        const response = await fetch(`/api/users/${userId}`);
        const data = await response.json();

        if (!cancelled) {
          setUser(data);
          setLoading(false);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err as Error);
          setLoading(false);
        }
      }
    }

    fetchUser();

    return () => {
      cancelled = true;
    };
  }, [userId]);

  const deleteUser = useCallback(async () => {
    await fetch(`/api/users/${userId}`, { method: 'DELETE' });
  }, [userId]);

  return { user, loading, error, deleteUser };
}

// components/UserProfile.tsx
function UserProfile({ userId }: { userId: string }) {
  const { user, loading, error, deleteUser } = useUser(userId);

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;
  if (!user) return <NotFound />;

  return <UserProfileView user={user} onDelete={deleteUser} />;
}

// components/UserProfileView.tsx
interface UserProfileViewProps {
  user: User;
  onDelete: () => void;
}

function UserProfileView({ user, onDelete }: UserProfileViewProps) {
  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
      <button onClick={onDelete}>Delete</button>
    </div>
  );
}
```

#### Bad: Not Using Discriminated Unions for State
```typescript
interface State {
  loading: boolean;
  error: Error | null;
  data: User | null;
}
```

#### Good: Discriminated Union for State
```typescript
type State =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'error'; error: Error }
  | { status: 'success'; data: User };

function UserComponent() {
  const [state, setState] = useState<State>({ status: 'idle' });

  switch (state.status) {
    case 'idle':
      return <button onClick={fetchUser}>Load User</button>;
    case 'loading':
      return <LoadingSpinner />;
    case 'error':
      return <ErrorMessage error={state.error} />;
    case 'success':
      return <UserView user={state.data} />;
  }
}
```

#### Bad: Creating Functions in Render
```typescript
function TodoList({ todos }: { todos: Todo[] }) {
  return (
    <ul>
      {todos.map(todo => (
        <li key={todo.id}>
          <button onClick={() => handleDelete(todo.id)}>
            Delete
          </button>∫∫****
        </li>
      ))}
    </ul>
  );
}
```

#### Good: Stable Callback References
```typescript
function TodoList({ todos }: { todos: Todo[] }) {
  const handleDelete = useCallback((id: string) => {
    // delete logic
  }, []);

  return (
    <ul>
      {todos.map(todo => (
        <TodoItem
          key={todo.id}
          todo={todo}
          onDelete={handleDelete}
        />
      ))}
    </ul>
  );
}

const TodoItem = memo(function TodoItem({
  todo,
  onDelete
}: {
  todo: Todo;
  onDelete: (id: string) => void;
}) {
  return (
    <li>
      <button onClick={() => onDelete(todo.id)}>Delete</button>
    </li>
  );
});
```

#### Bad: Not Handling Loading/Error States
```typescript
function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then(setUser);
  }, [userId]);

  return <div>{user?.name}</div>;
}
```

#### Good: Explicit State Handling
```typescript
function UserProfile({ userId }: { userId: string }) {
  const { user, loading, error } = useUser(userId);

  if (loading) {
    return (
      <div role="status" aria-live="polite">
        <LoadingSpinner />
        <span className="sr-only">Loading user profile...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div role="alert" aria-live="assertive">
        <ErrorMessage error={error} />
      </div>
    );
  }

  if (!user) {
    return <NotFound />;
  }

  return (
    <div role="main">
      <UserProfileView user={user} />
    </div>
  );
}
```

#### Bad: Prop Drilling
```typescript
function App() {
  const [user, setUser] = useState<User | null>(null);
  return <Dashboard user={user} setUser={setUser} />;
}

function Dashboard({ user, setUser }: Props) {
  return <Sidebar user={user} setUser={setUser} />;
}

function Sidebar({ user, setUser }: Props) {
  return <UserMenu user={user} setUser={setUser} />;
}
```

#### Good: Context for Shared State
```typescript
interface UserContextValue {
  user: User | null;
  setUser: (user: User | null) => void;
}

const UserContext = createContext<UserContextValue | null>(null);

function useUserContext() {
  const context = useContext(UserContext);
  if (!context) {
    throw new Error('useUserContext must be used within UserProvider');
  }
  return context;
}

function UserProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const value = useMemo(() => ({ user, setUser }), [user]);

  return (
    <UserContext.Provider value={value}>
      {children}
    </UserContext.Provider>
  );
}

function App() {
  return (
    <UserProvider>
      <Dashboard />
    </UserProvider>
  );
}

function UserMenu() {
  const { user, setUser } = useUserContext();
  // Use user and setUser directly
}
```

### React Testing Examples

#### Bad: Testing Implementation Details
```typescript
test('updates state when button is clicked', () => {
  const { container } = render(<Counter />);
  const button = container.querySelector('.increment-button');

  fireEvent.click(button);

  expect(container.querySelector('.count').textContent).toBe('1');
});
```

#### Good: Testing User Behavior
```typescript
test('increments count when user clicks increment button', async () => {
  const user = userEvent.setup();
  render(<Counter />);

  const button = screen.getByRole('button', { name: /increment/i });
  await user.click(button);

  expect(screen.getByText(/count: 1/i)).toBeInTheDocument();
});
```

#### Good: Testing Async Behavior
```typescript
test('displays user data after loading', async () => {
  const mockUser = { name: 'John Doe', email: 'john@example.com' };

  // Using MSW to mock API
  server.use(
    http.get('/api/users/123', () => {
      return HttpResponse.json(mockUser);
    })
  );

  render(<UserProfile userId="123" />);

  expect(screen.getByText(/loading/i)).toBeInTheDocument();

  const heading = await screen.findByRole('heading', { name: mockUser.name });
  expect(heading).toBeInTheDocument();
  expect(screen.getByText(mockUser.email)).toBeInTheDocument();
});
```

#### Good: Testing Error States
```typescript
test('displays error message when API fails', async () => {
  server.use(
    http.get('/api/users/123', () => {
      return HttpResponse.json(
        { error: 'User not found' },
        { status: 404 }
      );
    })
  );

  render(<UserProfile userId="123" />);

  const errorMessage = await screen.findByRole('alert');
  expect(errorMessage).toHaveTextContent(/failed to load user/i);
});
```

### Performance Optimization

#### React Performance
- Use React.memo() for expensive components
- Use useMemo() for expensive computations
- Use useCallback() for functions passed to memoized children
- Avoid creating objects/arrays in render
- Use key props correctly in lists
- Lazy load components with React.lazy() and Suspense
- Use virtualization for long lists (react-window, react-virtual)
- Profile with React DevTools Profiler

#### TypeScript Performance
- Avoid complex type computations
- Use type aliases instead of inline types
- Enable incremental compilation
- Use project references for monorepos
- Avoid excessive union types

### Accessibility

- Use semantic HTML elements
- Provide alt text for images
- Use proper heading hierarchy (h1, h2, h3)
- Ensure keyboard navigation works
- Use ARIA attributes when necessary
- Test with screen readers
- Maintain sufficient color contrast
- Provide focus indicators
- Support keyboard shortcuts
- Test with accessibility tools (axe, Lighthouse)
