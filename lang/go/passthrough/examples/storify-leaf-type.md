# Storify + Leaf Type Case: From Fat Function to Lean Orchestration

Demonstrates: R3, R1, R2

A real refactoring from a production codebase: a 48-line function mixing iteration,
validation, collection, and mutation becomes a 3-step story, with the juicy logic
extracted into a leaf type that unit-tests without mocks. This is the case law for
R3's core move — storifying discovers the leaf type — and for what the developer
actually shipped, including the imperfections and the next steps they left on the
table.

## The setting

`upsertIfaceAddrHost` must inspect a network interface, pick usable global-unicast
IPv4/IPv6 addresses, and reconcile the `Config`'s IP fields with what it found.

## Before

```go
// upsertIfaceAddrHost sets any IP from iface or returns error if provided IP not match to the interface
func (c *Config) upsertIfaceAddrHost(iface net.Interface) error {
    addr, err := iface.Addrs()
    if err != nil {
        return fmt.Errorf("network addr: %w", err)
    }
    var (
        addrIP4Added bool
        addrIP6Added bool
    )
    for _, a := range addr {
        ipnet, ok := a.(*net.IPNet)
        if !ok || !ipnet.IP.IsGlobalUnicast() {
            logger.Debug().Str("addr", a.String()).Msg("Not a global unicast address")
            continue
        }
        if ipnet.IP.To4() == nil { // validate IP6
            if addrIP6Added { // already added. skip
                continue
            }
            if !c.parseIP6(ipnet) {
                return fmt.Errorf("IP6 %q address is not valid", c.IP6)
            }
            logger.Debug().Str("ip6", c.IP6).Msg("set IP6")
            addrIP6Added = true
            continue
        }
        if addrIP4Added {
            continue // already added. skip
        }
        if !c.parseIP4(ipnet) {
            return fmt.Errorf("IP4 %q address is not valid", c.IP4)
        }
        logger.Debug().Str("ip4", c.IP6).Msg("set IP4")
        addrIP4Added = true
    }

    if !addrIP4Added && !addrIP6Added {
        return fmt.Errorf("IP address is not valid. IP4: %q, IP6: %q", c.IP4, c.IP6)
    }

    return nil
}

func (c *Config) parseIP4(ipnet *net.IPNet) bool {
    if c.IP4 == ipnet.IP.To4().String() {
        return true
    }
    if c.IP4 == anyIPv4 || c.IP4 == "" {
        // use first ip found from interface
        c.IP4 = ipnet.IP.To4().String()
        return true
    }
    return false
}

func (c *Config) parseIP6(ipnet *net.IPNet) bool {
    if c.IP6 == ipnet.IP.To16().String() {
        return true
    }
    if c.IP6 == anyIPv6 || c.IP6 == "" {
        // use first ip found from interface
        c.IP6 = ipnet.IP.To16().String()
        return true
    }
    return false
}
```

## The smells, named

1. **Fat function** — 48 lines, cyclomatic complexity 12, cognitive complexity 18:
   collection, validation, and config mutation crammed into one body.
2. **Mixed abstraction levels (R3)** — type assertions and `To4()` bit-fiddling in
   the same body as the business decision "is this configuration valid".
3. **Boolean flags tracking loop state** — `addrIP4Added`/`addrIP6Added` are set
   inside the loop and read after it: the classic signature of a collection type
   waiting to absorb the loop.
4. **Comments naming blocks** — `// validate IP6`, `// already added. skip`: each is
   an extraction order (R3), a function name written as prose.
5. **Dishonest names** — `parseIP4`/`parseIP6` mutate `c.IP4`/`c.IP6`; "parse"
   promises read-only. (Note the real-world bug it helped hide: the before code logs
   `Str("ip4", c.IP6)` — a copy-paste slip that a smaller, honest function would
   have made glaring.)
6. **No leaf types (R1)** — all logic lives on the big `Config`, so nothing is
   testable without constructing a `net.Interface` scenario.

The core problem: the juicy logic (which addresses count, how many of each family
to keep) is trapped inside an orchestration function. The fix is not to reshuffle
the fat function — it is to give that logic an owner.

## Step 1 — separate orchestration from logic

The function does three things: **collect** candidate IPs from the interface
(logic), **validate** the result (logic), **align** the config with what was found
(orchestration + logic). Collection and validation don't need `Config` at all —
that's the leaf type.

## After — the storified orchestrator

```go
// upsertIfaceAddrHost sets any IP from iface or returns error if provided IP not match to the interface
func (c *Config) upsertIfaceAddrHost(iface net.Interface) error {
    addr, err := iface.Addrs()
    if err != nil {
        return fmt.Errorf("network addr: %w", err)
    }

    ipConfig := collectIPConfigFrom(addr)

    if err = c.AlignIPs(ipConfig); err != nil {
        return fmt.Errorf("align config IPs err: %w", err)
    }

    return nil
}

func collectIPConfigFrom(addresses []net.Addr) IPConfig {
    var ipConfig IPConfig
    for _, a := range addresses {
        ipConfig.AddAddress(a)
    }
    return ipConfig
}
```

Read aloud: get addresses → collect them into an IPConfig → align our config with
what we collected. No nested ifs, no `continue`, no boolean flags — every line at
one altitude.

## After — the extracted leaf type

```go
// IPConfig collects the first usable global-unicast IPv4 and IPv6 address.
type IPConfig struct {
    IP4 string
    IP6 string
}

func (c *IPConfig) AddAddress(a net.Addr) {
    ipnet, ok := a.(*net.IPNet)
    if !ok || !ipnet.IP.IsGlobalUnicast() {
        logger.Debug().Str("addr", a.String()).Msg("Not a global unicast address")
        return
    }

    if ipnet.IP.To4() != nil {
        if len(c.IP4) > 0 {
            return // already added
        }
        c.IP4 = ipnet.IP.To4().String()
        return
    }

    if len(c.IP6) > 0 {
        return // already added
    }
    c.IP6 = ipnet.IP.To16().String()
}

func (c *IPConfig) Validate() error {
    if len(c.IP4) == 0 && len(c.IP6) == 0 {
        return errors.New("IP addresses are not found")
    }
    return nil
}
```

The boolean flags are gone: "already added" is now a question the collected state
answers (`len(c.IP4) > 0`), and the `continue`s became early `return`s — each address
is handled by one small decision tree instead of steering a shared loop.

## After — the alignment side, honestly named

```go
func (c *Config) AlignIPs(ipConfig IPConfig) error {
    if err := ipConfig.Validate(); err != nil {
        return fmt.Errorf("ip config is not valid: %w", err)
    }

    if err := c.alignIPv4(ipConfig.IP4); err != nil {
        return fmt.Errorf("align IPv4 err: %w", err)
    }
    if err := c.alignIPv6(ipConfig.IP6); err != nil {
        return fmt.Errorf("align IPv6 err: %w", err)
    }
    return nil
}

func (c *Config) alignIPv4(ip string) error {
    if c.IPv4 == ip {
        return nil // matches interface
    }
    if c.IPv4 == anyIPv4 || c.IPv4 == "" {
        c.IPv4 = ip // use first ip found from interface
        return nil
    }
    return fmt.Errorf("existing IPv4 [%s] mismatch configured [%s]", ip, c.IPv4)
}

func (c *Config) alignIPv6(ip string) error {
    if c.IPv6 == ip {
        return nil
    }
    if c.IPv6 == anyIPv6 || c.IPv6 == "" {
        c.IPv6 = ip
        return nil
    }
    return fmt.Errorf("existing IPv6 [%s] mismatch configured [%s]", ip, c.IPv6)
}
```

`parseIP4` → `alignIPv4`: "align" admits the mutation that "parse" hid, and the
boolean returns became errors that say *what* mismatched.

## The test payoff

Before, exercising any of this meant mocking `net.Interface` — building a network
scenario to check "keep the first IPv4". After, the leaf is tested with constructed
addresses and no orchestration in sight:

```go
func TestIPConfig_AddAddress_KeepsFirstIPv4(t *testing.T) {
    var cfg netconfig.IPConfig

    cfg.AddAddress(ipv4Addr(t, "192.168.1.1"))
    cfg.AddAddress(ipv4Addr(t, "192.168.1.2")) // second one is ignored

    assert.Equal(t, "192.168.1.1", cfg.IP4)
}

func TestIPConfig_Validate_Error(t *testing.T) {
    var cfg netconfig.IPConfig // nothing collected

    assert.Error(t, cfg.Validate())
}

func ipv4Addr(t *testing.T, ip string) net.Addr {
    t.Helper()
    return &net.IPNet{IP: net.ParseIP(ip), Mask: net.CIDRMask(24, 32)}
}
```

100% coverage on `IPConfig` costs a handful of literal-input cases. The
orchestrator (`upsertIfaceAddrHost` + `AlignIPs`) keeps an integration-style test
covering the seam — collection feeding alignment — per R7.

## Metrics

| | Before | After |
|---|---|---|
| Main function | 48 lines | 12 lines |
| Cyclomatic complexity | 12 | max 6 per function |
| Cognitive complexity | 18 | under threshold |
| Testable without mocking `net.Interface` | nothing | all of `IPConfig` |

## Decision points

1. **Storifying discovered the type.** The extraction order was: name the steps
   (collect → validate → align), then notice that "collect" carries its own state —
   the loop flags — and give that state an owner. R3 and R1 are one move here, not
   two.
2. **Honest naming was part of the refactor, not polish.** Renaming
   `parse*` → `align*` changed what readers expect the function to do; the
   copy-paste logging bug in the before code is the kind of defect dishonest names
   incubate.
3. **This is real shipped code, not an ideal.** The developer stopped here, and two
   improvements remain on the table:
   - **R2 is not fully paid.** `IPConfig` has exported fields and a separate
     `Validate()` that `AlignIPs` must remember to call — validation the type does
     not own. The stricter move: make collection the constructor,
     `collectIPConfigFrom(addresses) (IPConfig, error)`, fold `Validate` into it,
     and unexport the fields behind accessors. Then an invalid `IPConfig` cannot
     reach `AlignIPs` at all (see `../rules/R2-self-validating-types.md`).
   - **The IP strings are still primitives.** `IP4 string` re-checks emptiness at
     each use; a `netip.Addr`-backed type would delete those checks. Score it before
     wrapping (`../rules/R1-primitive-obsession.md`).

   Good refactoring knows when to stop — but a review citing this case should name
   these as the next iterations, not treat the shipped state as the ceiling.
