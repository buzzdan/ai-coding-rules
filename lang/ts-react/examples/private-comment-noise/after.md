```typescript
import type { Codec } from './jsonrpc'
import { CONTENT_TYPE_JSON, CONTENT_TYPE_MSGPACK, JSON_CODEC } from './jsonrpc'

// JSON envelopes start with '{' (0x7b); msgpack maps start at 0x80 or above.
const nonJsonLeadingByteFloor = 0x80

const msgpackAliasContentType = 'application/x-msgpack'

// A BOM's lead byte (0xEF) is above the floor, so strip it before the leading-byte check.
const UTF8_BOM = new Uint8Array([0xef, 0xbb, 0xbf])

function trimUtf8Bom(data: Uint8Array): Uint8Array {
  const hasBom = UTF8_BOM.every((byte, i) => data[i] === byte)
  return hasBom ? data.subarray(UTF8_BOM.length) : data
}

function detectReplyCodec(data: Uint8Array, nonJson: Codec): Codec {
  const body = trimUtf8Bom(data)
  if (body.length === 0) {
    return JSON_CODEC
  }
  if (body[0] >= nonJsonLeadingByteFloor) {
    return nonJson
  }

  return JSON_CODEC
}

// JSON.parse rejects a leading BOM as an unexpected token, and TextDecoder strips it only with ignoreBOM: false, so JSON trims it here.
function replyBytesForDecode(codec: Codec, rawResponse: Uint8Array): Uint8Array {
  if (codec.contentType === CONTENT_TYPE_JSON) {
    return trimUtf8Bom(rawResponse)
  }

  return rawResponse
}

function normalizeContentType(headerContentType: string): string {
  const [contentType] = headerContentType.split(';')
  return contentType.trim().toLowerCase()
}

function isMsgpackAliasContentType(headerContentType: string): boolean {
  const contentType = normalizeContentType(headerContentType)
  return contentType === CONTENT_TYPE_MSGPACK || contentType === msgpackAliasContentType
}

// The body bytes always pick the decoder; a disagreeing Content-Type header is only reported, never trusted.
function replyCodecAndMismatch(
  data: Uint8Array,
  nonJson: Codec,
  headerContentType: string,
): { codec: Codec; mismatch: boolean } {
  const codec = detectReplyCodec(data, nonJson)
  if (data.length === 0 || nonJson.contentType === CONTENT_TYPE_JSON) {
    return { codec, mismatch: false }
  }

  const headerSaysNonJson =
    normalizeContentType(headerContentType) === normalizeContentType(nonJson.contentType) ||
    (isMsgpackAliasContentType(headerContentType) && nonJson.contentType === CONTENT_TYPE_MSGPACK)
  const bodySaysNonJson = codec.contentType !== CONTENT_TYPE_JSON

  return { codec, mismatch: headerSaysNonJson !== bodySaysNonJson }
}
```

The knowledge that was worth keeping and did not fit a one-liner — the
msgpack-alias carve-out, why a JSON-only client never reports a mismatch — moves
to the feature doc, where the exported caller's JSDoc points with its See-edge.
The exported API (`decodeReply`, the module's one export below these helpers, and
the mismatch event `apiClient.parseResponse` raises) is where a reader meets this
module; that is where the tier budgets and the See-edge live.
