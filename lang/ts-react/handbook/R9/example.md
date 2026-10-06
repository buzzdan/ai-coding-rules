```typescript
// ❌ an exported class with no JSDoc; the comment narrates WHAT the loop does
export class Policy {
  async do(op: () => Promise<void>): Promise<void> {
    // loop over attempts and back off between failures
    for (let attempt = 1; attempt <= this.maxAttempts; attempt += 1) { /* … */ }
  }
}

// ❌ a JSDoc that restates the type is deleted
export interface Cluster {
  /** The cluster id. */
  readonly clusterId: string
}

/**
 * @param raw the raw string
 * @returns the policy
 */
export function parsePolicy(raw: string): Policy { /* … */ }

// ✅ the summary line states the contract, the body says why,
//    the doc points down at code and code points up at the doc
/**
 * A capped exponential-backoff retry policy with full jitter.
 *
 * Jitter is deliberate: synchronized clients retrying in lockstep re-overloaded
 * the upstream API after every blip.
 * See docs/retry-policy.md for the incident and the cap math.
 */
export class Policy { /* … */ }
```

> **In TypeScript:** an exported symbol gets a JSDoc when the WHY budget has
> something to say; the type system carries the WHAT, so `/** The cluster id */` on
> `clusterId: string`, `@param` and `@returns` tags that restate types, and `@type`
> tags are noise and are deleted. The summary line is the contract and never a
> restatement finding. A non-exported symbol gets no comment by default. A component's
> props doc the prop whose meaning its type does not carry: units, ownership, who
> calls it. Where the repository's `jsdoc/require-jsdoc` demands one, a WHAT-comment
> is rewritten, never deleted. The doc points down with greppable symbols
> (`Policy.do`, `parsePolicy`), never a path and a line number.
