- Physically: an interface method cannot reference another package's unexported
  type, and exporting the wire type just to enable the method inverts the
  dependency.
- Architecturally: with multiple consumers (CLI, gateway, store), per-consumer
  `fill<X>Request` methods accrete every consumer's serialization onto the domain
  types — interface pollution from the opposite direction.
