# Comment Noise Case: Nine Private Helpers, Nine Comments

Demonstrates: R9 (comment policy — the visibility default)

A real 143-line file from a JSON-RPC-over-HTTP client (anonymized), written by an
LLM flow before the visibility default existed. It detects which codec decoded a
reply body: JSON, or the client's configured non-JSON codec (msgpack). Every one
of its nine underscore-prefixed symbols carries a comment; the file has more comment lines
than code lines. Each comment, judged alone, "delivers a toolbox value". The file
as a whole is unreadable — a human reviewer of a sibling PR called the style
"utterly lacking empathy for the reader".

This is the case law for R9's visibility default: **underscore-prefixed symbols get no
comment; the special case is one line carrying a very high-value toolbox item.**

## The before — representative excerpts

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

## The verdicts

All nine symbols are underscore-prefixed, so the question is existence, not size:

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

## The after

```python
"""Which codec decoded a JSON-RPC reply body: JSON, or the client's configured non-JSON codec."""

from rpc import jsonrpc
from rpc.jsonrpc import Codec

# JSON envelopes start with '{' (0x7b); msgpack maps start at 0x80 or above.
_NON_JSON_LEADING_BYTE_FLOOR = 0x80

_MSGPACK_ALIAS_CONTENT_TYPE = "application/x-msgpack"

# A BOM's lead byte (0xEF) is above the floor, so strip it before the leading-byte check.
_UTF8_BOM = b"\xef\xbb\xbf"


def _trim_utf8_bom(data: bytes) -> bytes:
    return data.removeprefix(_UTF8_BOM)


def _detect_reply_codec(data: bytes, non_json: Codec) -> Codec:
    data = _trim_utf8_bom(data)
    if not data:
        return jsonrpc.JSONCodec()
    if data[0] >= _NON_JSON_LEADING_BYTE_FLOOR:
        return non_json

    return jsonrpc.JSONCodec()


def _reply_bytes_for_decode(codec: Codec, raw_response: bytes) -> bytes:
    # json.loads treats a leading BOM as an invalid character, not whitespace, so JSON strips it.
    if isinstance(codec, jsonrpc.JSONCodec):
        return _trim_utf8_bom(raw_response)

    return raw_response


def _normalize_content_type(header_content_type: str) -> str:
    content_type, _, _ = header_content_type.partition(";")
    return content_type.strip().lower()


def _is_msgpack_alias_content_type(header_content_type: str) -> bool:
    return _normalize_content_type(header_content_type) in (
        jsonrpc.CONTENT_TYPE_MSGPACK,
        _MSGPACK_ALIAS_CONTENT_TYPE,
    )


def _reply_codec_and_mismatch(
    data: bytes, non_json: Codec, header_content_type: str
) -> tuple[Codec, bool]:
    """The body bytes always pick the decoder; a disagreeing Content-Type header is only reported, never trusted."""
    codec = _detect_reply_codec(data, non_json)
    if not data or non_json.content_type() == jsonrpc.CONTENT_TYPE_JSON:
        return codec, False

    header_says_non_json = _normalize_content_type(
        header_content_type
    ) == _normalize_content_type(non_json.content_type()) or (
        _is_msgpack_alias_content_type(header_content_type)
        and non_json.content_type() == jsonrpc.CONTENT_TYPE_MSGPACK
    )
    body_says_non_json = codec.content_type() != jsonrpc.CONTENT_TYPE_JSON

    return codec, header_says_non_json != body_says_non_json
```

The knowledge that was worth keeping and did not fit a one-liner — the
msgpack-alias carve-out, why a JSON-only client never reports a mismatch — moves
to the feature doc, where the public caller's docstring points with its See-edge.
The public API (`Client.parse_response`, the mismatch event) is where a reader
meets this package; that is where the tier budgets and the See-edge live.

## The lesson

The tier budget caps how big a comment can be; only the visibility default
decides whether it should exist at all. Before this case, "Helper: 0–1 lines"
read as permission, and a writer in fill-the-menu mode gave every private symbol
its tier maximum — nine comments, each locally justified, jointly unreadable.
The default for underscore-prefixed symbols is **zero**: the name is the documentation,
and a name that needs a comment wants a rename or an extraction first. The
special case is **one line carrying a very high-value toolbox item** — an
ordering constraint, an external library quirk, the WHY of a magic number, the
package's one real policy. If a private symbol seems to need more than that one
line, the knowledge belongs to the exported symbol that uses it, the package
doc, or the feature doc.
