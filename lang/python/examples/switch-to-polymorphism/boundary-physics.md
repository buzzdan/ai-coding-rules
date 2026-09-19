- Physically: a method on a domain class cannot take one consumer's private request
  type without importing that consumer — an import cycle, or the domain package
  depending on its client, which inverts the dependency.
- Architecturally: with multiple consumers (CLI, gateway, store), per-consumer
  `fill_<x>_request` methods accrete every consumer's serialization onto the domain
  classes — protocol pollution from the opposite direction.
