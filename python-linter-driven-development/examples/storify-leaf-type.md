# Storify + Leaf Type Case: From Fat Function to Lean Orchestration

Demonstrates: R3, R1, R2

A real refactoring from a production codebase: a 48-line function mixing iteration,
validation, collection, and mutation becomes a 3-step story, with the juicy logic
extracted into a leaf type that unit-tests without mocks. This is the case law for
R3's core move — storifying discovers the leaf type — and for what the developer
actually shipped, including the imperfections and the next steps they left on the
table.

## The setting

`Config.upsert_iface_addr_host` must inspect a network interface, pick usable
global-unicast IPv4/IPv6 addresses, and reconcile the `Config`'s IP fields with what
it found.

## Before

```python
def upsert_iface_addr_host(self, iface: Interface) -> None:
    """Set any IP from iface or raise if the provided IP does not match the interface."""
    addr_ip4_added = False
    addr_ip6_added = False
    for a in iface.addrs():
        ip = ipaddress.ip_address(a.address)
        if not ip.is_global:
            logger.debug("not a global unicast address: %s", a.address)
            continue
        if ip.version == 6:  # validate IP6
            if addr_ip6_added:  # already added. skip
                continue
            if not self._parse_ip6(ip):
                raise ValueError(f"IP6 {self.ip6!r} address is not valid")
            logger.debug("set IP6 %s", self.ip6)
            addr_ip6_added = True
            continue
        if addr_ip4_added:
            continue  # already added. skip
        if not self._parse_ip4(ip):
            raise ValueError(f"IP4 {self.ip4!r} address is not valid")
        logger.debug("set IP4 %s", self.ip6)
        addr_ip4_added = True

    if not addr_ip4_added and not addr_ip6_added:
        raise ValueError(f"IP address is not valid. IP4: {self.ip4!r}, IP6: {self.ip6!r}")


def _parse_ip4(self, ip: IPv4Address) -> bool:
    if self.ip4 == str(ip):
        return True
    if self.ip4 in (ANY_IPV4, ""):
        # use first ip found from interface
        self.ip4 = str(ip)
        return True
    return False


def _parse_ip6(self, ip: IPv6Address) -> bool:
    if self.ip6 == str(ip):
        return True
    if self.ip6 in (ANY_IPV6, ""):
        # use first ip found from interface
        self.ip6 = str(ip)
        return True
    return False
```

## The smells, named

1. **Fat function** — 40 lines, cyclomatic complexity 12 (ruff `C901` at the default
   threshold), twelve branches (`PLR0912`): collection, validation, and config
   mutation crammed into one body.
2. **Mixed abstraction levels (R3)** — `ipaddress.ip_address` parsing and
   `ip.version` checks in the same body as the business decision "is this
   configuration valid".
3. **Boolean flags tracking loop state** — `addr_ip4_added`/`addr_ip6_added` are set
   inside the loop and read after it: the classic signature of a collection type
   waiting to absorb the loop.
4. **Comments naming blocks** — `# validate IP6`, `# already added. skip`: each is
   an extraction order (R3), a function name written as prose.
5. **Dishonest names** — `_parse_ip4`/`_parse_ip6` mutate `self.ip4`/`self.ip6`;
   "parse" promises read-only. (Note the real-world bug it helped hide: the before
   code logs `self.ip6` under "set IP4" — a copy-paste slip that a smaller, honest
   function would have made glaring.)
6. **No leaf types (R1)** — all logic lives on the big `Config`, so nothing is
   testable without constructing an `Interface` scenario.

The core problem: the juicy logic (which addresses count, how many of each family
to keep) is trapped inside an orchestration function. The fix is not to reshuffle
the fat function — it is to give that logic an owner.

## Step 1 — separate orchestration from logic

The function does three things: **collect** candidate IPs from the interface
(logic), **validate** the result (logic), **align** the config with what was found
(orchestration + logic). Collection and validation don't need `Config` at all —
that's the leaf type.

## After — the storified orchestrator

```python
def upsert_iface_addr_host(self, iface: Interface) -> None:
    """Set any IP from iface or raise if the provided IP does not match the interface."""
    ip_config = collect_ip_config_from(iface.addrs())
    self.align_ips(ip_config)


def collect_ip_config_from(addresses: Iterable[Addr]) -> IPConfig:
    ip_config = IPConfig()
    for a in addresses:
        ip_config.add_address(a)
    return ip_config
```

Read aloud: get addresses → collect them into an IPConfig → align our config with
what we collected. No nested ifs, no `continue`, no boolean flags — every line at
one altitude.

## After — the extracted leaf type

```python
@dataclass
class IPConfig:
    """The first usable global-unicast IPv4 and IPv6 address of an interface."""

    ip4: str = ""
    ip6: str = ""

    def add_address(self, a: Addr) -> None:
        ip = ipaddress.ip_address(a.address)
        if not ip.is_global:
            logger.debug("not a global unicast address: %s", a.address)
            return

        if ip.version == 4:
            if self.ip4:
                return  # already added
            self.ip4 = str(ip)
            return

        if self.ip6:
            return  # already added
        self.ip6 = str(ip)

    def validate(self) -> None:
        if not self.ip4 and not self.ip6:
            raise ValueError("IP addresses are not found")
```

The boolean flags are gone: "already added" is now a question the collected state
answers (`if self.ip4:`), and the `continue`s became early `return`s — each address
is handled by one small decision tree instead of steering a shared loop.

## After — the alignment side, honestly named

```python
def align_ips(self, ip_config: IPConfig) -> None:
    ip_config.validate()
    self._align_ipv4(ip_config.ip4)
    self._align_ipv6(ip_config.ip6)


def _align_ipv4(self, ip: str) -> None:
    if self.ipv4 == ip:
        return  # matches interface
    if self.ipv4 in (ANY_IPV4, ""):
        self.ipv4 = ip  # use first ip found from interface
        return
    raise ValueError(f"existing IPv4 [{ip}] mismatch configured [{self.ipv4}]")


def _align_ipv6(self, ip: str) -> None:
    if self.ipv6 == ip:
        return
    if self.ipv6 in (ANY_IPV6, ""):
        self.ipv6 = ip
        return
    raise ValueError(f"existing IPv6 [{ip}] mismatch configured [{self.ipv6}]")
```

`_parse_ip4` → `_align_ipv4`: "align" admits the mutation that "parse" hid, and the
boolean returns became exceptions that say *what* mismatched.

## The test payoff

Before, exercising any of this meant faking an `Interface` — building a network
scenario to check "keep the first IPv4". After, the leaf is tested with constructed
addresses and no orchestration in sight:

```python
def test_ip_config_add_address_keeps_first_ipv4() -> None:
    cfg = netconfig.IPConfig()

    cfg.add_address(Addr("192.168.1.1"))
    cfg.add_address(Addr("192.168.1.2"))  # second one is ignored

    assert cfg.ip4 == "192.168.1.1"


def test_ip_config_validate_rejects_nothing_collected() -> None:
    cfg = netconfig.IPConfig()  # nothing collected

    with pytest.raises(ValueError, match="not found"):
        cfg.validate()
```

100% coverage on `IPConfig` costs a handful of literal-input cases. The orchestrator
(`upsert_iface_addr_host` + `align_ips`) keeps an integration-style test covering
the seam — collection feeding alignment — per R7.

## Metrics

| | Before | After |
|---|---|---|
| Main function | 40 lines | 4 lines |
| Cyclomatic complexity | 12 | max 6 per function |
| Branches (`PLR0912`) | 12 | under threshold |
| Testable without faking `Interface` | nothing | all of `IPConfig` |

## Decision points

1. **Storifying discovered the type.** The extraction order was: name the steps
   (collect → validate → align), then notice that "collect" carries its own state —
   the loop flags — and give that state an owner. R3 and R1 are one move here, not
   two.
2. **Honest naming was part of the refactor, not polish.** Renaming
   `_parse_*` → `_align_*` changed what readers expect the function to do; the
   copy-paste logging bug in the before code is the kind of defect dishonest names
   incubate.
3. **This is real shipped code, not an ideal.** The developer stopped here, and two
   improvements remain on the table:
   - **R2 is not fully paid.** `IPConfig` is a mutable dataclass with a separate
     `validate()` that `align_ips` must remember to call — validation the type does
     not own. The stricter move: make collection the constructor, a
     `IPConfig.collect(addresses)` classmethod that raises on an empty result and
     returns a `frozen=True` instance, so `validate()` disappears. Then an invalid
     `IPConfig` cannot reach `align_ips` at all (see
     `../rules/R2-self-validating-types.md`).
   - **The IP strings are still primitives.** `ip4: str` re-checks emptiness at
     each use; an `ipaddress.IPv4Address | None` field, or a small type around it,
     would delete those checks. Score it before wrapping
     (`../rules/R1-primitive-obsession.md`).

   Good refactoring knows when to stop — but a review citing this case should name
   these as the next iterations, not treat the shipped state as the ceiling.
