  ```python
  # ❌ re-validates what Host already guarantees
  @dataclass(frozen=True)
  class Address:
      host: Host
      port: Port

      def __post_init__(self) -> None:
          if not self.host.name:          # Host owns this
              raise ValueError("host required")


  # ✅ trusts composed self-validating types — nothing left to check, no __post_init__
  @dataclass(frozen=True)
  class Address:
      host: Host
      port: Port
  ```
