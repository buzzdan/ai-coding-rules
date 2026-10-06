
> **In TypeScript:** `throw` an `Error` subclass with its cause attached,
> `throw new ApiError('device: malformed response', { cause })`, never a string. A
> `catch (error: unknown)` narrows with `instanceof` and never by `message`; the one
> place a broad catch belongs is the boundary that renders the failure, an error
> boundary or the query layer's `onError`. A promise is awaited or returned, never
> dropped (`promise/catch-or-return`, `@typescript-eslint/no-floating-promises`);
> `console.error` and a rethrow in the same `catch` is handling it twice. A `catch`
> that returns `null` or `undefined` is R2 Q5: Separate Failure from Absence.

**Review:** Does any `catch` swallow the error, return `null` for a failure, both `console.error` and rethrow, inspect `message`, or throw without its `cause`?
