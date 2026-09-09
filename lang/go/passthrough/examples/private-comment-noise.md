# Comment Noise Case: Nine Private Helpers, Nine Comments

Demonstrates: R9 (comment policy — the visibility default)

A real 143-line file from a JSON-RPC-over-HTTP client (anonymized), written by an
LLM flow before the visibility default existed. It detects which codec decoded a
reply body: JSON, or the client's configured non-JSON codec (msgpack). Every one
of its nine unexported symbols carries a comment; the file has more comment lines
than code lines. Each comment, judged alone, "delivers a toolbox value". The file
as a whole is unreadable — a human reviewer of a sibling PR called the style
"utterly lacking empathy for the reader".

This is the case law for R9's visibility default: **unexported symbols get no
comment; the special case is one line carrying a very high-value toolbox item.**

## The before — representative excerpts

A 5-line comment on a private constant, with cross-repo provenance:

```go
// nonJSONLeadingByteFloor is the lowest leading byte a non-JSON wire
// frame can start with in the leading-byte detection heuristic:
// JSON-RPC 2.0 envelopes always start with '{' (0x7b), and msgpack maps
// (fixmap, map16, map32) always start at 0x80 or above — the same
// boundary the legacy client's detectCodec uses.
nonJSONLeadingByteFloor byte = 0x80
```

Decoder rings and review-defense narration on another constant:

```go
// msgpackAliasContentType is the second literal spelling D-04 requires
// this package to accept as msgpack, alongside jsonrpc.ContentTypeMsgpack
// ("application/msgpack"). Named as a single constant — not a table —
// per Pitfall 3: a third wire format would earn its own narrow check,
// not a generalized alias registry.
msgpackAliasContentType = "application/x-msgpack"
```

Six lines on a one-line function, with forward references to its callers:

```go
// trimUTF8BOM strips a leading UTF-8 BOM from data, returning data unchanged
// when no BOM is present. Used both to classify a reply's byte verdict
// (detectReplyCodec) and, for a JSON verdict, to decode it
// (Client.ParseResponse): encoding/json treats a BOM as an invalid leading
// byte rather than whitespace, so leaving it in would still fail to decode
// even after correct classification.
func trimUTF8BOM(data []byte) []byte {
    return bytes.TrimPrefix(data, utf8BOM)
}
```

A caller list that rots on the next caller:

```go
// normalizeContentType strips any ";"-delimited parameters (e.g.
// "; charset=binary"), trims surrounding whitespace, and lowercases the
// result — the shared normalization step both isMsgpackAliasContentType and
// replyCodecAndMismatch's header cross-check use (see codec_event.go).
func normalizeContentType(headerContentType string) string {
```

And the centerpiece: **22 prose lines on an unexported function** — over 4× the
budget of an exported crossroads — ending in a sixty-word sentence:

```go
// replyCodecAndMismatch returns the byte-verdict codec (identical to
// detectReplyCodec) plus a bool that is true when the normalized
// Content-Type header disagrees with that byte verdict. The byte verdict
// always governs the actual decode (D-04: bytes-first); mismatch is only a
// signal for the caller's CodecEvent, never a second decode selector.
//
// headerSaysNonJSON is true when the header exactly names nonJSON's own
// content type, OR — the msgpack-alias carve-out D-04 requires — the
// header is either msgpack spelling AND nonJSON's content type IS msgpack
// (the alias never claims agreement for an unrelated non-JSON codec).
//
// An empty body never mismatches: it is not a valid non-JSON envelope
// regardless of what the header claims.
//
// A Client with no distinct non-JSON codec configured (nonJSON is the
// jsonrpc.JSONCodec{} default) never mismatches either: with nothing but
// JSON to disagree with, an ordinary JSON reply's own "Content-Type:
// application/json" header would otherwise satisfy headerSaysNonJSON's
// literal string comparison against nonJSON.ContentType() (also
// "application/json"), producing a false-positive mismatch on every
// zero-config JSON call — a bug this guard forecloses rather than lets a
// caller's mismatch check ever observe.
func replyCodecAndMismatch(data []byte, nonJSON jsonrpc.Codec, headerContentType string) (jsonrpc.Codec, bool) {
```

## The verdicts

All nine symbols are unexported, so the question is existence, not size:

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

## The after

```go
package jrpchttp

import (
    "bytes"
    "strings"

    "example.com/rpc/jsonrpc"
)

const (
    // JSON envelopes start with '{' (0x7b); msgpack maps start at 0x80 or above.
    nonJSONLeadingByteFloor byte = 0x80

    msgpackAliasContentType = "application/x-msgpack"
)

// A BOM's lead byte (0xEF) is above the floor, so strip it before the leading-byte check.
var utf8BOM = []byte{0xEF, 0xBB, 0xBF}

func trimUTF8BOM(data []byte) []byte {
    return bytes.TrimPrefix(data, utf8BOM)
}

func detectReplyCodec(data []byte, nonJSON jsonrpc.Codec) jsonrpc.Codec {
    data = trimUTF8BOM(data)
    if len(data) == 0 {
        return jsonrpc.JSONCodec{}
    }
    if data[0] >= nonJSONLeadingByteFloor {
        return nonJSON
    }

    return jsonrpc.JSONCodec{}
}

// encoding/json treats a leading BOM as an invalid byte, not whitespace, so JSON strips it.
func replyBytesForDecode(codec jsonrpc.Codec, rawResponse []byte) []byte {
    if _, isJSON := codec.(jsonrpc.JSONCodec); isJSON {
        return trimUTF8BOM(rawResponse)
    }

    return rawResponse
}

func normalizeContentType(headerContentType string) string {
    contentType := headerContentType
    if idx := strings.IndexByte(contentType, ';'); idx >= 0 {
        contentType = contentType[:idx]
    }

    return strings.ToLower(strings.TrimSpace(contentType))
}

func isMsgpackAliasContentType(headerContentType string) bool {
    switch normalizeContentType(headerContentType) {
    case string(jsonrpc.ContentTypeMsgpack), msgpackAliasContentType:
        return true
    default:
        return false
    }
}

// The body bytes always pick the decoder; a disagreeing Content-Type header is only reported, never trusted.
func replyCodecAndMismatch(data []byte, nonJSON jsonrpc.Codec, headerContentType string) (jsonrpc.Codec, bool) {
    codec := detectReplyCodec(data, nonJSON)
    if len(data) == 0 || nonJSON.ContentType() == jsonrpc.ContentTypeJSON {
        return codec, false
    }

    headerSaysNonJSON := normalizeContentType(
        headerContentType,
    ) == normalizeContentType(
        string(nonJSON.ContentType()),
    ) ||
        (isMsgpackAliasContentType(headerContentType) && nonJSON.ContentType() == jsonrpc.ContentTypeMsgpack)
    bodySaysNonJSON := codec.ContentType() != jsonrpc.ContentTypeJSON

    return codec, headerSaysNonJSON != bodySaysNonJSON
}
```

The knowledge that was worth keeping and did not fit a one-liner — the
msgpack-alias carve-out, why a JSON-only client never reports a mismatch — moves
to the feature doc, where the exported caller's godoc points with its See-edge.
The exported API (`Client.ParseResponse`, the mismatch event) is where a reader
meets this package; that is where the tier budgets and the See-edge live.

## The lesson

The tier budget caps how big a comment can be; only the visibility default
decides whether it should exist at all. Before this case, "Helper: 0–1 lines"
read as permission, and a writer in fill-the-menu mode gave every private symbol
its tier maximum — nine comments, each locally justified, jointly unreadable.
The default for unexported symbols is **zero**: the name is the documentation,
and a name that needs a comment wants a rename or an extraction first. The
special case is **one line carrying a very high-value toolbox item** — an
ordering constraint, an external library quirk, the WHY of a magic number, the
package's one real policy. If a private symbol seems to need more than that one
line, the knowledge belongs to the exported symbol that uses it, the package
doc, or the feature doc.
