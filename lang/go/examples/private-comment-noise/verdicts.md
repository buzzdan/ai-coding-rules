| Symbol | Before | Verdict | Why |
|---|---|---|---|
| `nonJSONLeadingByteFloor` | 5 lines | one-liner survives | the WHY of the magic number ('{' is 0x7b; msgpack maps start at 0x80) — the code cannot carry it |
| `msgpackAliasContentType` | 5 lines | DELETE | the name and value say it; "D-04 requires" is a decoder ring; "not a table, per Pitfall 3" is review-defense narration |
| `utf8BOM` | 6 lines | one-liner survives | an ordering constraint: 0xEF ≥ the floor, so the BOM check must run before the leading-byte check |
| `trimUTF8BOM` | 6 lines | DELETE | the name is the documentation; the encoding/json quirk belongs to `replyBytesForDecode`, its only decode-side caller |
| `detectReplyCodec` | 7 lines | DELETE | narrated implementation ("Bounds-checked: it never indexes an empty slice") plus cross-repo provenance |
| `replyBytesForDecode` | 8 lines | one-liner survives | an external library quirk: encoding/json treats a BOM as an invalid leading byte, not whitespace |
| `normalizeContentType` | 4 lines | DELETE | the name says it; the caller list rots |
| `isMsgpackAliasContentType` | 5 lines | DELETE | the name says it; decoder rings and review-defense again |
| `replyCodecAndMismatch` | 22 lines | one-liner survives | the package's one real policy: bytes pick the decoder, the header is only a signal — the rest moves to the feature doc |

Four one-liners survive out of nine comments; roughly 68 comment lines become 4.
