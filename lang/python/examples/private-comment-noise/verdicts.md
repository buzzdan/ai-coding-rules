| Symbol | Before | Verdict | Why |
|---|---|---|---|
| `_NON_JSON_LEADING_BYTE_FLOOR` | 5 lines | one-liner survives | the WHY of the magic number ('{' is 0x7b; msgpack maps start at 0x80) — the code cannot carry it |
| `_MSGPACK_ALIAS_CONTENT_TYPE` | 5 lines | DELETE | the name and value say it; "D-04 requires" is a decoder ring; "not a table, per Pitfall 3" is review-defense narration |
| `_UTF8_BOM` | 6 lines | one-liner survives | an ordering constraint: 0xEF ≥ the floor, so the BOM check must run before the leading-byte check |
| `_trim_utf8_bom` | 6 lines | DELETE | the name is the documentation; the `json.loads` quirk belongs to `_reply_bytes_for_decode`, its only decode-side caller |
| `_detect_reply_codec` | 7 lines | DELETE | narrated implementation ("Bounds-checked: it never indexes an empty bytes") plus cross-repo provenance |
| `_reply_bytes_for_decode` | 8 lines | one-liner survives | a standard-library quirk: `json.loads` treats a BOM as an invalid leading character, not whitespace |
| `_normalize_content_type` | 4 lines | DELETE | the name says it; the caller list rots |
| `_is_msgpack_alias_content_type` | 5 lines | DELETE | the name says it; decoder rings and review-defense again |
| `_reply_codec_and_mismatch` | 22 lines | one-liner survives | the package's one real policy: bytes pick the decoder, the header is only a signal — the rest moves to the feature doc |

Four one-liners survive out of nine comments; roughly 68 comment lines become 4.
None of the nine is a ruff `D1` obligation: pydocstyle prices public names only,
so a private function with no docstring is silent under the strictest `D` config,
and a WHAT-docstring on one is deleted, not rewritten.
