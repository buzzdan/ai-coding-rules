# Component Designing Examples

> **Source**: Real-world patterns and best practices for TypeScript + React

## Table of Contents
1. [Presentational vs Container Components](#presentational-vs-container-components)
2. [Props Management with Readonly](#props-management-with-readonly)
3. [State Updates (Functional vs Direct)](#state-updates-functional-vs-direct)
4. [Component Composition Patterns](#component-composition-patterns)
5. [Data Test IDs](#data-test-ids)

---

## Presentational vs Container Components

### Presentational Component (Pure UI)

**Characteristics:**
- Focus on how things *look*
- Receive data via props only
- Don't fetch data or manage complex state
- Highly reusable and testable
- Usually in `/components` directory

```typescript
// ============================================
// PRESENTATIONAL COMPONENT
// File: src/components/ClusterCard/ClusterCard.tsx
// Purpose: Pure UI component, highly reusable
// ============================================

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
    <div className={styles.card}>
      <div className={styles.header}>
        <h3>{name}</h3>
        <SystemStatus status={status} />
      </div>

      <div className={styles.content}>
        <CapacityProgressBar
          used={usedCapacity}
          total={capacity}
          percentage={utilizationPercent}
        />
      </div>

      <div className={styles.footer}>
        <Button onClick={onViewDetails}>View Details</Button>
      </div>
    </div>
  )
}

// Easy to test - just pass props!
// Easy to use in Storybook
// No dependencies on APIs, hooks, or external state
```

### Container Component (Logic + Orchestration)

**Characteristics:**
- Focus on how things *work*
- Handle data fetching, side effects, business logic
- Pass data down to presentational components
- Less reusable, more feature-specific
- Usually in `/pages` or as `*Container` files

```typescript
// ============================================
// CONTAINER COMPONENT
// File: src/pages/ClustersOverview/ClusterCardContainer.tsx
// Purpose: Handles data fetching and business logic
// ============================================

interface ClusterCardContainerProps {
  readonly clusterId: string
}

export function ClusterCardContainer({ clusterId }: ClusterCardContainerProps) {
  // Data fetching
  const { data: clusters, isLoading, error } = useClusters()
  const cluster = clusters?.find(c => c.id === clusterId)

  // Navigation
  const navigate = useNavigate()

  // Analytics
  const posthog = usePostHog()

  // Business logic
  const handleViewDetails = useCallback(() => {
    posthog?.capture('cluster_details_viewed', {
      clusterId,
      clusterName: cluster?.name
    })
    navigate(`/cluster/${clusterId}`)
  }, [clusterId, cluster?.name, navigate, posthog])

  // Loading/error states
  if (isLoading) return <ClusterCardSkeleton />
  if (error) return <ErrorCard message="Failed to load cluster" />
  if (!cluster) return null

  // Transform API data to component props
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
```

### Usage in Page

```typescript
// ============================================
// USAGE IN PAGE
// File: src/pages/ClustersOverview/ClustersOverview.tsx
// ============================================

export function ClustersOverview() {
  const { data: clusters } = useClusters()

  return (
    <div className={styles.grid}>
      {clusters?.map(cluster => (
        <ClusterCardContainer key={cluster.id} clusterId={cluster.id} />
      ))}
    </div>
  )
}
```

**Benefits of this pattern:**
- ✅ `ClusterCard` is easy to test with different props
- ✅ `ClusterCard` can be used in Storybook
- ✅ `ClusterCard` is reusable anywhere (modals, lists, detail pages)
- ✅ Business logic is centralized in the container
- ✅ Easy to mock data for testing the presentational component
- ✅ API changes only affect the container, not the UI

**When to separate:**
- Component has both complex logic AND complex UI
- You want to reuse the UI in multiple places with different data sources
- You want to test UI independently of data fetching
- Component is getting large (> 200 lines)

**When NOT to separate:**
- Simple components with minimal logic
- Component is only used once
- Logic and UI are tightly coupled
- Would create unnecessary abstraction

---

## Props Management with Readonly

### Our Preferred Pattern

```typescript
// ❌ Bad - No readonly enforcement
interface ButtonProps {
  label: string
  onClick: () => void
}

function Button({ label, onClick }: ButtonProps) {
  // Props can be mutated (TypeScript won't catch this)
}

// ✅ Good - Our preferred pattern
// Define interface without readonly, apply Readonly<> in function signature
interface ButtonProps {
  label: string
  onClick: () => void
}

function Button({ label, onClick }: Readonly<ButtonProps>) {
  // Props are readonly here
}
```

**Why this pattern:**
- ✅ Interface stays clean and readable
- ✅ Readonly enforcement at usage point (function signature)
- ✅ Same safety, less visual noise
- ✅ Easier to read and maintain

### Alternative Pattern (More Verbose)

```typescript
// ✅ Also valid - Readonly on each property
interface ButtonProps {
  readonly label: string
  readonly onClick: () => void
}

function Button({ label, onClick }: ButtonProps) {
  // Props are readonly
}
```

---

## State Updates (Functional vs Direct)

### Rule: Use functional updates when new state **depends on** previous state

```typescript
// ❌ Bad - May use stale state when incrementing
const [count, setCount] = useState(0)
setCount(count + 1)

// ✅ Good - Always uses current state
setCount(prev => prev + 1)

// ✅ Good - Setting independent value (doesn't depend on previous)
const [name, setName] = useState('')
setName(newName) // Fine, not based on previous value

// ❌ Bad - Multiple updates may conflict
setItems([...items, newItem])
setItems([...items, anotherItem])

// ✅ Good - Guaranteed order
setItems(prev => [...prev, newItem])
setItems(prev => [...prev, anotherItem])
```

**When to use functional updates:**
- ✅ Incrementing/decrementing numbers
- ✅ Adding/removing items from arrays
- ✅ Updating object properties based on current values
- ✅ Multiple rapid updates to same state

**When direct updates are fine:**
- ✅ Setting completely new value (user input, API response)
- ✅ Replacing entire state with unrelated value
- ✅ Toggle between fixed values (not based on previous)

---

## Component Composition Patterns

### 1. Children Prop Pattern

```typescript
function Card({ children }: { children: React.ReactNode }) {
  return <div className={styles.card}>{children}</div>
}

// Use it
<Card>
  <h3>Title</h3>
  <p>Content</p>
</Card>
```

### 2. Render Props Pattern

```typescript
function DataProvider({
  endpoint,
  render
}: {
  endpoint: string
  render: (data: Data, loading: boolean) => React.ReactNode
}) {
  const { data, isLoading } = useFetch(endpoint)
  return <>{render(data, isLoading)}</>
}
```

### 3. Custom Hooks (Preferred for Logic Reuse)

```typescript
// Extract logic to hook
function useClusterCard(clusterId: string) {
  const { data: cluster, isLoading } = useClusters()
  const navigate = useNavigate()

  const handleViewDetails = () => navigate(`/cluster/${clusterId}`)

  return { cluster, isLoading, handleViewDetails }
}

// Use in component
function ClusterCardContainer({ clusterId }: Props) {
  const { cluster, isLoading, handleViewDetails } = useClusterCard(clusterId)

  if (isLoading) return <Skeleton />

  return <ClusterCard {...cluster} onViewDetails={handleViewDetails} />
}
```

### 4. Compound Components Pattern

```typescript
function Tabs({ children }: { children: React.ReactNode }) {
  return <div className={styles.tabs}>{children}</div>
}

Tabs.List = function TabsList({ children }) {
  return <div className={styles.tabsList}>{children}</div>
}

Tabs.Panel = function TabsPanel({ children }) {
  return <div className={styles.tabsPanel}>{children}</div>
}

// Use it
<Tabs>
  <Tabs.List>
    <button>Tab 1</button>
    <button>Tab 2</button>
  </Tabs.List>
  <Tabs.Panel>Content 1</Tabs.Panel>
  <Tabs.Panel>Content 2</Tabs.Panel>
</Tabs>
```

---

## Data Test IDs

### Rule: Use camelCase `dataTestId` prop for React components, apply as kebab-case `data-testid` to DOM elements

```typescript
// ✅ Good - React component receives camelCase prop
interface ButtonProps {
  label: string
  dataTestId?: string  // camelCase
}

function Button({ label, dataTestId }: Readonly<ButtonProps>) {
  return (
    <button data-testid={dataTestId}>  {/* kebab-case on DOM */}
      {label}
    </button>
  )
}

// Usage
<Button label="Submit" dataTestId="submit-button" />

// ❌ Bad - Don't pass data-testid directly to React components
<Button data-testid="submit-button" label="Submit" />
```

**Why:**
- React components use camelCase props (JavaScript convention)
- HTML attributes use kebab-case (HTML/DOM convention)
- Component abstracts the DOM implementation

---

## Additional React Best Practices

### Key Attribute in Lists

```typescript
// ❌ Bad - Using index as key
{items.map((item, index) => (
  <Item key={index} {...item} />
))}

// ❌ Bad - No key
{items.map(item => (
  <Item {...item} />
))}

// ✅ Good - Unique stable ID
{items.map(item => (
  <Item key={item.id} {...item} />
))}
```

### Props Destructuring

```typescript
// ❌ Bad
function Button(props: Readonly<ButtonProps>) {
  return <button onClick={props.onClick}>{props.label}</button>
}

// ✅ Good
function Button({ label, onClick }: Readonly<ButtonProps>) {
  return <button onClick={onClick}>{label}</button>
}
```

### Boolean Props

```typescript
// ❌ Bad
<Button disabled={true} isRounded={true} />

// ✅ Good
<Button disabled isRounded />

// ✅ Good - For false
<Button disabled={false} />
```

### Self-Closing Tags

```typescript
// ❌ Bad
<Button></Button>
<Icon></Icon>

// ✅ Good
<Button />
<Icon />
```

### Fragments

```typescript
// ❌ Bad
<React.Fragment>
  <Header />
  <Content />
</React.Fragment>

// ✅ Good
<>
  <Header />
  <Content />
</>

// ✅ Good - When key is needed
<Fragment key={item.id}>
  <Header />
  <Content />
</Fragment>
```

### No Useless Fragments

```typescript
// ❌ Bad
return (
  <>
    <div>Single child</div>
  </>
)

// ✅ Good
return <div>Single child</div>

// ✅ Good - Multiple children
return (
  <>
    <Header />
    <Content />
  </>
)
```

### Avoid Nested Components

```typescript
// ❌ Bad - Component recreated on every render
function Parent() {
  function NestedChild({ name }: { name: string }) {
    return <div>{name}</div>
  }

  return <NestedChild name="test" />
}

// ✅ Good - Define outside
function NestedChild({ name }: Readonly<{ name: string }>) {
  return <div>{name}</div>
}

function Parent() {
  return <NestedChild name="test" />
}
```

### Early Returns for Conditional Rendering

```typescript
// ❌ Bad - Hard to read
function Component({ isLoading, error, data }: Props) {
  return isLoading ? (
    <Spinner />
  ) : error ? (
    <Error message={error} />
  ) : data ? (
    <DataDisplay data={data} />
  ) : (
    <EmptyState />
  )
}

// ✅ Good - Clear flow
function Component({ isLoading, error, data }: Readonly<Props>) {
  if (isLoading) return <Spinner />
  if (error) return <Error message={error} />
  if (!data) return <EmptyState />

  return <DataDisplay data={data} />
}
```
