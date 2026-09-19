  ```python
  # ❌ relies on callers to validate
  @dataclass
  class Config:
      host: str      # every caller must remember: if not host ...
      port: int


  # ✅ owns its own validation
  @dataclass(frozen=True)
  class Config:
      host: str
      port: int

      def __post_init__(self) -> None:
          if not self.host:
              raise ValueError("host required")
          if not 0 < self.port <= 65535:
              raise ValueError("invalid port")
  ```
