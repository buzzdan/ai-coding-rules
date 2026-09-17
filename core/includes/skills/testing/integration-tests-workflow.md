**Purpose**: Middle rungs — each adds one real layer; test the seams and emergent behaviors that layer brings

1. **Identify integration points** - Where packages/components interact
2. **Choose dependencies** - Prefer: in-memory > binary > test-containers
3. **Write tests** - Imported as a consumer would, marked the way the repository marks
   slower tests (a build tag, a marker, a separate directory) so they can be run on
   their own
4. **Test workflows** - Cover happy path and error scenarios across boundaries
5. **Use real or test-utility implementations** - Avoid heavy mocking

**File organization:** one integration test file per seam, next to the tests of the
component that owns the seam, or under the repository's integration-test directory
when it has one — follow the existing layout.