---
# The plant: free functions (dial, healthURL) that each take the host/port/TLS
# trio and hand back a connection or a URL. After the fix the trio travels as
# one value, so no function outside a constructor takes the three primitives
# and returns a Conn or a string. A constructor accepting the primitives at the
# package boundary (NewClient, newEndpoint) is the legitimate remaining site.
type: regex
pattern: '^func [a-z][A-Za-z]*\(host string, port int, tls bool\) \(?(net\.Conn|string)'
flags: m
match: count:0
target: files
---
