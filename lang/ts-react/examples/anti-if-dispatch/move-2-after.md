```typescript
export type Format = 'json' | 'text' | 'markdown'

const RENDERERS: Record<Format, (a: Alert) => string> = {
  json: renderJson,
  text: renderText,
  markdown: renderMarkdown,
}

function isFormat(raw: string): raw is Format {
  return Object.hasOwn(RENDERERS, raw)
}

export function parseFormat(raw: string): Format {
  if (!isFormat(raw)) {
    throw new Error(`unknown format ${raw}`) // for "yaml", here and nowhere else
  }
  return raw
}

export function render(a: Alert, f: Format): string {
  return RENDERERS[f](a)
}
```

The lookup *is* the dispatch; the "is this a known format" question is asked once, in
`parseFormat`, at the boundary (the search-param reader), and `RENDERERS[f]` never
needs a `??` default because a `Format` that exists is a key that exists. The silent
markdown default — an undecided decision — became an explicit error. (The `Record` is
module-level immutable data, the sanctioned shape under R8; naming the union is R1's
"Name enum strings" move, and `Record<Format, …>` is what keeps the map complete: a
fourth `Format` without a renderer does not compile.)
