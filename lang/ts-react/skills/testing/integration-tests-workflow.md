**Purpose**: Middle rungs — each adds one real layer; test the seams and emergent behaviors that layer brings

1. **Identify integration points** - Where a page, its hooks, the query layer and `apiClient` interact
2. **Choose dependencies** - Prefer: MSW handlers in-process > the real API as a child process > test-containers
3. **Write tests** - Imported as a consumer would, in `<Page>.test.tsx` beside the page (or `<Page>.integration.test.tsx` when the repository splits them by name, with a Vitest project or `include` pattern in `vitest.config.*` so the fast loop can skip them)
4. **Test workflows** - Cover happy path and error scenarios across boundaries (`server.use(devicesErrorHandler)`)
5. **Use real or test-support implementations** - Real providers, real routing, handlers whose fixture is a recorded exchange with the real API; no `vi.mock` of an internal hook or service

**File organization:**
```tsx
// src/pages/Devices/DevicesPage.test.tsx
import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { renderWithProviders } from '@/test-utils/renderWithProviders'
import { DevicesPage } from './DevicesPage'

// Page + hooks + query layer + apiClient against the devices handlers
```

See reference.md for integration test patterns with dependencies.
