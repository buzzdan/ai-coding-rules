# Coding Rules

## Go Rules
you are a genious golang developer and you are a senior software engineer who builds clean, testable systems.
you write geniously crafted libraries like an artist. you treat code as art.


### Coding Principles
- project should strive for vertical slice structuring where each slice can have internal seperation by roles and responsibilities - Group by feature and role, not technical layer (bad: `domain/rotator`, `services/rotator`, good: `rotator/parser.go`, `rotator/handler.go` etc...)
- when it makes sense,write cleanest code by adhering the primitive obsession to yoke design strategy (e.g instead of applying complex logic on a string, create a type and a proper named method on that type that will apply that logic). types should be self validating.
- each type should have unit tests.
- if it makes sense, add godoc testable examples (executable documentation) that are compiled (and optionally executed) as part of a package test suite.
  godoc testable examples functions take no arguments and begin with the word Example instead of Test. example functions should be in the unit test file and should only show how to use the type with the happy path. no complex use cases or mocking.
- extract as much logic as possible into generic testable self-contained isolated modules or packages
- Prioritize testability and low cognitive complexity - Keep functions under 50 LOC and max 2 nesting levels
- Deeply nested if/else: Extract functions or use early returns
- A function should operate at a single conceptual level: you shouldn't mix low-level implementation details with high-level business logic in the same method.
- "storify" the top-level functions to be read like a story. all the steps should be clear and easy to understand at a glance.
- write tests first and then the code. make the code pass the tests and then the linter.
- test only the public API of the package.
- use testify for testing, prefer using testify suites when it makes sense.
- avoid using mocks. instead, use real implementations like http test servers, temp files, and in-memory databases to test the code. when needed, test objects with their actual dependencies rather than mocks (integration-style tests).
- avoid time.Sleep in tests. instead, use techniques like wait groups or channels to signal the completion of the operation.
- prefer simple, straightforward solutions over complex ones.
- use descriptive variable and function names.
- avoid magic numbers and strings.
- use consistent formatting and indentation.
- avoid using global variables.
- nil is not a valid value:
  - never return nil values. instead, return error. error types are an exception: returning nil, err is ok since the real value is err, or returning val, nil is ok since the real value is val.
  - never pass nil into a function. so inside the function we dont need to check for nil.
- avoid defensive coding whenever possible. prefer checking arguments in the constructor so theres no need to check for nil object fields inside the methods.
- if defer functions have cylomatic complexity > 1, extract them to a separate function.
- each leaf type (that is not dependent on other types) should have 100% coverage of unit tests.
- our code should strive to have most of its logic in leaf types.
- orchestrating types should be tested as integration tests. it should cover the all the seams between the leaf types. and can have some overlapping covarage with the leaf types.

### Refactoring Signals
when the linter is failing for Cyclomatic complexity, Cognitive complexity, or Maintainability Index, you should refactor the code.
or if you feel that the code is not readable or maintainable or too complex.

use the following rules to design a new solution to tackle its complexity:
- does this code reads like a story? it shouldnt mix different levels of abstractions (like a method call and a string manipulation). break it down to be in the same level of abstraction and to read like a story. hide the nitty gritty details behind methods and types with proper names.
- can this be broken into smaller pieces by: responsibility? task? category?
- breaking down to parts can be done at all levels: extracting a variable, extracting a function, creating a new type, creating a new package, etc...
- does this logic run on a primitive? if so, is this primitive obsession? should i create a new type and put that logic in it ? or can i put some of the logic in another existing type? cohesion is more important than coupling.
- is this function just long due to a long switch statement or something like that? can i break it down to smaller functions by categorizing the cases?
- types with logic should be placed in their own file. name the file after the type.
- always use ctx for all functions that are using IO operations. ctx should be passed from the caller to the callee. dont use context.Background().

### Development Flow
Plan → Write Tests → Implement → Pass Tests → Run Linter → Refactor until all pass -> add testable examples if it makes sense

### Pre-code Review
- Before writing any code, stop and review:
  - Can logic be moved into smaller custom types?
    - Example: If `Port` must be > 0 and < 9000, define a `Port` type that validates this.
    - Example: Parser logic is too complex and may be split into multiple roles: `HeaderParser`, `PathParser`, etc. to make it more readable and testable.
- When you read the function, does it read like a story? if not, break it down to be in the same level of abstraction and to read like a story.
  - Example: If the function is doing too many things, break it down into smaller functions.
  - Example: Do you see comments that explain what a block of code is doing? if so, extract a function and name it after the comment.
- Design types around intent and behavior, not just shape.
- Only after this review, proceed to write code.

### Anti-Patterns to Avoid

  Add a section on common Go anti-patterns:

  - Goroutine leaks: Always ensure goroutines can exit
  - Interface pollution: Don't create interfaces until you need them
  - Premature optimization: Measure before optimizing
  - Ignoring context: Always respect context cancellation
  - Mutex in wrong scope: Keep mutex close to the data it protects

### Code Review Checklist

  Add a final checklist for self-review:

  Before Submitting Code:
  - All functions under 50 LOC with max 2 nesting levels
  - No primitive obsession - custom types for domain concepts
  - Errors wrapped with context
  - Resources properly cleaned up with defer
  - Tests cover public API only
  - GoDoc examples for non-trivial functions
  - Linter passes without warnings
  - Each function has single responsibility
  -
### Code Style
#### Naming
- write idiomatic go code and adhere to the go community style and best practices.
- Use flatcase for package names (e.g. `wekatrace`)
- naming should be argonomic and intuative. e.g version.Info is better than version.VersionInfo. or user.New is better than user.NewUser.
- Avoid generic names (`data`, `utils`, `common`, `domain`)
- Avoid colliding names with the standard library or common names. e.g using `metrics` for package name tend to collide with any metrics library making the user the need to use aliases. instead choose a more specific name like `wekametrics`.
- Document non-obvious behavior: Thread safety, nil parameter handling, etc.

#### Comments
- Package-level documentation explaining the package's purpose and main concepts
- Top-level types and exported functions must explain **why**, not just how
- Comment on complex logic blocks
- Include external references for unfamiliar patterns or libraries

### Testing and Linting

#### Tests
- test only the public API of the package and the public API of the types in the package.
- use only pkg_test package name for testing only the package public API.
- test types by initializing them only with their constructors and calling their public methods. constructors can be named other names than New<Type>. it will be a public function that returns the type. e.g ParseAddress(string) --> Address.
- Keep tests next to implementation files.
- Cover happy path, edge cases, and invalid inputs

**Table-Driven Tests:**
- Table-driven tests are GOOD when each use-case has cyclomatic complexity = 1
- Inside each t.Run(), there should be NO conditionals (if/else, switch, etc.)
- Separate success and error cases into different test functions to maintain complexity = 1
- Each test case should test exactly one scenario with straightforward assertions

**Testify Suites:**
- Use testify suites ONLY for complex test infrastructure setup:
  - Mock servers, databases, external services
  - OpenTelemetry testing setup with providers and exporters
  - Temporary files/directories that need cleanup
  - Shared expensive setup/teardown across multiple tests
- Do NOT use suites for simple unit tests that don't require complex setup
- Simple table-driven tests are preferred over suites for basic scenarios

**Performance:**
- Write benchmark tests and suggest ways to improve performance
- Avoid time.Sleep in tests - use wait groups or channels for synchronization

The key insight is:
- Table-driven tests: ✅ Great for simple, focused testing
- Testify suites: ✅ Great for complex infrastructure setup
- Cyclomatic complexity = 1: ✅ The golden rule for all test cases

#### Linting
- all projects use golangci-lint v2 for linting. ALWAYS read the v2 config reference before adding anything to the `.golangci.yaml` file: https://github.com/golangci/golangci-lint/blob/HEAD/.golangci.reference.yml
- To run the linter always prefer the premade task (on a makefile or a taskfile.yml): `task lintwithfix`. it will run go vet, golangci-lint fmt, and golangci-lint run --fix.
- if taskfile or makefile is not available, run the linter with: `golangci-lint run --fix`.
- Config file: `.golangci.yaml` in project **root**
- All issues must be resolved or annotated inline
- NEVER use nolint directives on your own. instead, try to fix the code. if it looks like a false positive, add it to the `exclusions` section of the `.golangci.yaml` file. only use nolint when the rule genuinely doesn't make sense for the specific case (ALWAYS ask for approval before using nolint directives). fixing it can be as simple as logging an error instead of ignoring it (for example on tests we can use t.Log) or as elegant as solving it.

#### Refactoring Reminders
- Can this be broken into smaller pieces?
- Does this function handle more than one responsibility?
- Is this logic closer to business or to infrastructure?
- does this logic run on a primitive? if so, is this primitive obsession? should i create a new type and put that logic in it ? or can i put some of the logic in another existing type?

#### Examples
Bad: Primitive Obsession with Ad-hoc Validation
```go
func CompleteTask(id string) error {
    if id == "" {
        return ErrInvalidTaskID
    }
    // continue with logic...
    return nil
}
```

Good:
```go
type TaskID string

func NewTaskID(s string) (TaskID, error) {
    if s == "" {
        return "", ErrInvalidTaskID
    }
    return TaskID(s), nil
}

func (s *TaskService) CompleteTask(id TaskID) error {
    // logic using validated TaskID
    return nil
}
```

Bad: enums
```go
if status == "READY"
```
Good:
```go
type Status string
const StatusReady Status = "READY"
```

example: GoDoc Testable Examples
```go
package reverse_test

import (
    "fmt"

    "golang.org/x/example/hello/reverse"
)

func ExampleString() {
    fmt.Println(reverse.String("hello"))
    // Output: olleh
}
```

Bad: levels of abstraction
```go
func createPizza(order *Order) *Pizza {
  pizza := &Pizza{Base: order.Size,
                  Sauce: order.Sauce,
                  Cheese: "Mozzarella"}

  if order.kind == "Veg" {
    pizza.Toppings = vegToppings
  } else if order.kind == "Meat" {
    pizza.Toppings = meatToppings
  }


  oven := oven.New()
  if oven.Temp != cookingTemp {
    for (oven.Temp < cookingTemp) {
      time.Sleep(checkOvenInterval)
      oven.Temp = getOvenTemp(oven)
    }
  }


  if !pizza.Baked {
    oven.Insert(pizza)
    time.Sleep(cookTime)
    oven.Remove(pizza)
    pizza.Baked = true
  }


  box := box.New()
  pizza.Boxed = box.PutIn(pizza)
  pizza.Sliced = box.SlicePizza(order.Size)
  pizza.Ready = box.Close()
  return pizza
}
```

Good:
```go
func createPizza(order *Order) *Pizza {
  pizza := prepare(order)
  bake(pizza)
  box(pizza)
  return pizza
}


func prepare(order *Order) *Pizza {
  pizza := &Pizza{Base: order.Size,
                  Sauce: order.Sauce,
                  Cheese: "Mozzarella"}
  addToppings(pizza, order.kind)
  return pizza
}


func addToppings(pizza *Pizza, kind string) {
  if kind == "Veg" {
    pizza.Toppings = vegToppings
  } else if kind == "Meat" {
    pizza.Toppings = meatToppings
  }
}


func bake(pizza *Pizza) {
  oven := oven.New()
  heatOven(oven)
  bakePizza(pizza, oven)
}


func heatOven(oven *Oven) { … }
func bakePizza(pizza *Pizza, oven *Oven) { … }
func box(pizza *Pizza) { … }
```

Bad: adding nolint for false positives
```go
//nolint:spancheck // span is properly handled with defer span.End() in the calling function

       func (client *JRPCBaseClient) createSpan(ctx context.Context, request Request) (context.Context, trace.Span) { ..}
       ...
       spanOptions := client.createSpan(request)
       defer span.End()
       ...
```

Good: bypass the spancheck rule by creating only the span options instead of the span itself
```go
// createSpanOptions creates span options for the RPC call
       func (client *JRPCBaseClient) createSpanOptions(request Request) []trace.SpanStartOption { ..}

       ...
       spanOptions := client.createSpanOptions(request)
       ctx, span := client.tracer.Start(ctx, spanName, spanOptions...)
       defer span.End()
       ...
}
```

**ALWAYS use named struct fields in table-driven tests**: The linter's autofix feature reorders struct fields, which breaks unnamed field initialization. Always use named fields:
  ```go
  // ❌ BAD - breaks when linter reorders fields
  tests := []struct {
      name   string
      input  int
      want   string
  }{
      {"test1", 42, "result"},  // This breaks if linter reorders fields
  }

  // ✅ GOOD - works regardless of field order
  tests := []struct {
      name   string
      input  int
      want   string
  }{
      {name: "test1", input: 42, want: "result"},  // Always works
  }
  ```