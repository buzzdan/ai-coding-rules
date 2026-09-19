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
