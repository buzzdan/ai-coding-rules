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
