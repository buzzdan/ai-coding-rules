A 5-line comment on a private constant, with cross-repo provenance:

```python
# _NON_JSON_LEADING_BYTE_FLOOR is the lowest leading byte a non-JSON wire
# frame can start with in the leading-byte detection heuristic:
# JSON-RPC 2.0 envelopes always start with '{' (0x7b), and msgpack maps
# (fixmap, map16, map32) always start at 0x80 or above — the same
# boundary the legacy client's detect_codec uses.
_NON_JSON_LEADING_BYTE_FLOOR = 0x80
```

Decoder rings and review-defense narration on another constant:

```python
# _MSGPACK_ALIAS_CONTENT_TYPE is the second literal spelling D-04 requires
# this package to accept as msgpack, alongside jsonrpc.CONTENT_TYPE_MSGPACK
# ("application/msgpack"). Named as a single constant — not a table —
# per Pitfall 3: a third wire format would earn its own narrow check,
# not a generalized alias registry.
_MSGPACK_ALIAS_CONTENT_TYPE = "application/x-msgpack"
```

A six-line docstring on a one-line function, with forward references to its
callers:

```python
def _trim_utf8_bom(data: bytes) -> bytes:
    """Strip a leading UTF-8 BOM from data, returning data unchanged when none is present.

    Used both to classify a reply's byte verdict (_detect_reply_codec) and, for
    a JSON verdict, to decode it (Client.parse_response): json.loads treats a
    BOM as an invalid leading character rather than whitespace, so leaving it
    in would still fail to decode even after correct classification.
    """
    return data.removeprefix(_UTF8_BOM)
```

A caller list that rots on the next caller:

```python
def _normalize_content_type(header_content_type: str) -> str:
    """Strip any ";"-delimited parameters (e.g. "; charset=binary"), trim
    surrounding whitespace, and lowercase the result — the shared
    normalization step both _is_msgpack_alias_content_type and
    _reply_codec_and_mismatch's header cross-check use (see codec_event.py).
    """
```

And the centerpiece: **22 prose lines on a private function** — over 4× the
budget of a public crossroads — ending in a sixty-word sentence:

```python
def _reply_codec_and_mismatch(
    data: bytes, non_json: Codec, header_content_type: str
) -> tuple[Codec, bool]:
    """Return the byte-verdict codec plus whether the header disagrees with it.

    The byte verdict is identical to _detect_reply_codec's. It always governs
    the actual decode (D-04: bytes-first); mismatch is only a signal for the
    caller's CodecEvent, never a second decode selector.

    header_says_non_json is true when the header exactly names non_json's own
    content type, OR — the msgpack-alias carve-out D-04 requires — the
    header is either msgpack spelling AND non_json's content type IS msgpack
    (the alias never claims agreement for an unrelated non-JSON codec).

    An empty body never mismatches: it is not a valid non-JSON envelope
    regardless of what the header claims.

    A Client with no distinct non-JSON codec configured (non_json is the
    JSONCodec() default) never mismatches either: with nothing but JSON to
    disagree with, an ordinary JSON reply's own "Content-Type:
    application/json" header would otherwise satisfy header_says_non_json's
    literal string comparison against non_json.content_type() (also
    "application/json"), producing a false-positive mismatch on every
    zero-config JSON call — a bug this guard forecloses rather than lets a
    caller's mismatch check ever observe.
    """
```
