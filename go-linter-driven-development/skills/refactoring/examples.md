# Example 1: Storifying Mixed Abstractions and Extracting Logic into Leaf Types

This is a real-world example from a production codebase showing how to transform a complex function by extracting logic into a new leaf type.

## Key Learning: From Fat Function to Lean Orchestration + Leaf Type
The original function contained ALL the logic. After refactoring:
- **Orchestration layer** (thin): `upsertIfaceAddrHost` - reads like a story
- **Leaf type** (juicy logic): `IPConfig` - owns IP collection, validation, testable in isolation
- **Result**: Most complexity moved to testable leaf type with 100% coverage potential

This is a real world example from a production codebase and what the developer chose to refactor.
It is not perfect, and it could be improved further, but it demonstrates the core refactoring pattern:
## Before refactoring
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

func (c *Config) isIP4Set() bool {
	return len(c.IP4) > 0
}

func (c *Config) isIP6Set() bool {
	return len(c.IP6) > 0
}

func (c *Config) parseIP4(ipnet *net.IPNet) bool {
	if c.IP4 == ipnet.IP.To4().String() {
		logger.Debug().Str("addr", ipnet.IP.To4().String()).Msg("IP4 match to interface")
		return true
	}
	if c.IP4 == anyIPv4 || c.IP4 == "" {
		logger.Debug().Str("addr", ipnet.IP.To4().String()).Msg("Using interface IP for NodeIP")
		// use first ip found from interface
		c.IP4 = ipnet.IP.To4().String()
		return true
	}
	return false
}

func (c *Config) parseIP6(ipnet *net.IPNet) bool {
	if c.IP6 == ipnet.IP.To16().String() {
		logger.Debug().Str("addr", ipnet.IP.To16().String()).Msg("IP6 match to interface")
		return true
	}
	if c.IP6 == anyIPv6 || c.IP6 == "" {
		logger.Debug().Str("addr", ipnet.IP.To16().String()).Msg("Using interface IP for NodeIP")
		// use first ip found from interface
		c.IP6 = ipnet.IP.To16().String()
		return true
	}
	return false
}
```

## Code Smells Identified

The `upsertIfaceAddrHost` function suffers from:

1. **Fat Function Anti-Pattern** - All logic crammed into one function (48 lines, complexity 12)
2. **Hidden Side Effects** - `parseIP4/parseIP6` names hide mutation
3. **Mixed Abstraction Levels** - Combines low-level iteration with high-level business logic
4. **No Leaf Types** - All logic lives in methods, nothing is extracted to testable types
5. **Flow Control Complexity** - Nested ifs, continues, boolean flags tracking state
6. **Poor Testability** - Must mock `net.Interface` to test anything

**The Core Problem**: All the juicy logic is trapped in a complex orchestration function. We need to extract it into a leaf type.


## After refactoring
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

func collectIPConfigFrom([]net.Addr addresses) IPConfig {
	var ipConfig IPConfig
	for _, a := range addresses {
		ipConfig.AddAddress(a)
	}
	return ipConfig
}


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
	}

	if ipnet.IP.To4() == nil {
		if len(c.IP6) > 0 {
			return // already added
		}
		c.IP6 = ipnet.IP.To16().String()

		return
	}
}

func (c *IPConfig) Validate() error {
	if len(c.IP4) == 0 && len(c.IP6) == 0 {
		return errors.New("IP addresses are not found")
	}

	return nil
}

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
	if len(c.IPv4) == 0 {
		c.ExistingClusterStartedIPv4Only = false
	}
	if c.ExistingClusterStartedIPv4Only && len(c.IPv6) > 0 {
		logger.Warn().
			Str("IPv6", c.IPv6).
			Str("IPv4", c.IPv4).
			Msg("existing cluster is running in IPv4 only. Dual stack is not possible.")
	}

	return nil
}

func (c *Config) alignIPv4(ip string) error {
	if c.IPv4 == ip {
		logger.Debug().Str("addr", ip).Msg("IP4 match to interface")

		return nil
	}
	if c.IPv4 == anyIPv4 || c.IPv4 == "" {
		logger.Debug().Str("addr", ip).Msg("Using interface IP for NodeIP")
		// use first ip found from interface
		c.IPv4 = ip

		return nil
	}

	return fmt.Errorf("existing IPv4 [%s] mismatch configured [%s]", ip, c.IPv4)
}

func (c *Config) alignIPv6(ip string) error {
	if c.IPv6 == ip {
		logger.Debug().Str("addr", ip).Msg("IPv6 match to interface")

		return nil
	}
	if c.IPv6 == anyIPv6 || c.IPv6 == "" {
		logger.Debug().Str("addr", ip).Msg("Using interface IP for NodeIP")
		// use first ip found from interface
		c.IPv6 = ip

		return nil
	}

	return fmt.Errorf("existing IPv6 [%s] mismatch configured [%s]", ip, c.IPv6)
}

```

## Refactoring Thought Process

### Step 1: Identify What's Orchestration vs. Logic
The original function does 3 things:
1. **Collects** IP addresses from interface (LOGIC)
2. **Validates** them (LOGIC)
3. **Aligns** Config state with discovered IPs (orchestration + logic)

**Decision**: Extract the collection logic into a new type

### Step 2: Create a Leaf Type to Hold the Juicy Logic
Instead of keeping all logic in `Config` methods:
→ **Created `IPConfig` type** - a leaf type (no dependencies on other types)
→ **Moved collection logic** into `IPConfig.AddAddress()` method
→ **Moved validation logic** into `IPConfig.Validate()` method

**Why this matters**:
- `IPConfig` is now a **leaf type** with testable logic
- Can achieve 100% unit test coverage without mocking anything
- Logic is isolated and reusable

### Step 3: Make Orchestration Read Like a Story
`upsertIfaceAddrHost` now reads:
1. Get addresses from interface
2. Collect them into IPConfig
3. Align our config with what we collected

No nested ifs, no continues, no boolean flags - just clear steps.

### Step 4: Honest Naming for Side Effects
`parseIP4/parseIP6` → `alignIPv4/alignIPv6`
The word "align" signals mutation, "parse" suggested read-only.

## Key Improvements

### Architecture
* **Fat function became lean orchestration** - 48 lines → 12 lines in main function
* **Created leaf type `IPConfig`** - Holds all the juicy IP collection logic
* **Separated concerns** - Collection (IPConfig) vs. Alignment (Config methods)

### Readability
* **Storified orchestration** - `upsertIfaceAddrHost` reads like: collect → align → done
* **Honest naming** - `align*` reveals side effects vs. `parse*` hiding them
* **Single level of abstraction** - Each function operates at one conceptual level

### Testability
* **Leaf type with 100% coverage** - `IPConfig` can be fully unit tested without mocks
* **Testable in isolation**:
  ```go
  // Test collection logic without network code
  func TestIPConfig_AddAddress(t *testing.T) {
      cfg := &IPConfig{}
      cfg.AddAddress(createIPv4Addr("192.168.1.1"))
      assert.Equal(t, "192.168.1.1", cfg.IP4)
  }
  ```
* **Integration tests for orchestration** - Test the seams between IPConfig and Config

### Complexity Reduction
**Before**: Cognitive complexity 18, cyclomatic complexity 12
**After**: Max complexity 6 per function

## Refactoring Patterns Applied

1. **Type Extraction** → Created `IPConfig` leaf type for IP collection
2. **Storifying** → Top-level reads: collect → validate → align
3. **Honest Naming** → `align*` instead of `parse*` reveals mutation
4. **Single Responsibility** → Each function does ONE thing
5. **Early Returns** → Replaced `continue` with `return` for clarity

## The Leaf Type Strategy

**Before**: All logic trapped in one place
```
Config.upsertIfaceAddrHost() {
  // ALL the logic here: iteration, validation, collection, alignment
  // 48 lines, complexity 12, impossible to test separately
}
```

**After**: Logic extracted to leaf type
```
IPConfig (LEAF TYPE - no dependencies)
  ├─ AddAddress()  // Collection logic (juicy!)
  └─ Validate()    // Validation logic (juicy!)

Config (ORCHESTRATOR)
  ├─ upsertIfaceAddrHost()  // Thin story: collect → align
  └─ AlignIPs()             // Thin coordination
```

**Result**: Most of the complexity now lives in `IPConfig`, a leaf type with 100% test coverage potential.


# Example 2: Primitive Obsession with Multiple Types and Storifying Switch Statements

This real-world example shows how to transform a 60-line function with nested switches and boolean flags into a 7-line story by extracting multiple leaf types. The original function was named `validateCIDR()` but actually mutated state - a classic naming smell that triggered deeper refactoring.

## Key Learning: From Primitive Obsession to Type-Rich Design (Without Over-Abstraction!)

**Before**: All logic operates on raw `[]string` with manual parsing and boolean flags
```
One 60-line function
  └─ Manual string parsing + switch statements + boolean flags
```

**After**: Multiple focused leaf types with clear responsibilities
```
K3SArgs (Leaf Type - string slice wrapper)
  ├─ ParseCIDRConfig() → returns domain model
  └─ AppendCIDRDefaults() → mutation with explicit dependencies

CIDRConfig (Leaf Type - domain model with private fields)
  ├─ clusterCIDRSet (private bool - controlled mutation)
  ├─ serviceCIDRSet (private bool - controlled mutation)
  ├─ ClusterCIDRSet() → accessor (read-only)
  ├─ ServiceCIDRSet() → accessor (read-only)
  └─ AreBothSet() → reads like English

  Note: No CIDRPresence wrapper! Private fields achieve
        same safety without wrapper ceremony.

IPVersionConfig (Leaf Type - configuration)
  └─ DefaultCIDRs() → value generator

Main Function (Orchestrator - 7 lines)
  └─ Story: create config → convert to type → append defaults → store back
```

**Result**:
- Main function reduced from 60 to 7 lines
- Most complexity lives in 3 leaf types (100% testable)
- Each type can be tested without mocking anything
- Code reads like English: "append CIDR defaults based on IP config"
- **Avoided over-abstraction**: Rejected `CIDRPresence` wrapper, used private fields instead

## Code Smells Identified

1. **Misleading Name** - `validateCIDR()` doesn't validate - it mutates! Should return `bool` or `error` if validating
2. **Primitive Obsession (CRITICAL)** - Operating on raw `[]string`, manual parsing everywhere, no encapsulation
3. **Mixed Abstraction Levels** - Jumps between string splitting (`strings.SplitN`) and business logic (`isClusterCIDRSet`)
4. **Boolean Flags Tracking State** - Two booleans tracking related information instead of domain type
5. **Switch Statement Duplication** - Three nearly identical switch cases (IPv4/IPv6/dual) differing only in data values
6. **Fat Function** - 60 lines doing: parse + detect + construct + mutate
7. **Hard to Test** - Must construct entire Config object, can't test parsing independently

**The Core Problem**: All the juicy logic is trapped in string manipulation and scattered across switch cases. We need multiple leaf types to separate parsing, configuration, and value generation concerns.

## Before Refactoring

```go
// Original name was validateCIDR - misleading!
func (c *Config) alignCIDRArgs() {
	var (
		isClusterCIDRSet bool
		isServerCIDRSet  bool
	)
	// LOW LEVEL: String parsing
	for _, arg := range c.Configuration.K3SArgs {
		kv := strings.SplitN(arg, "=", 2)
		if len(kv) != 2 {
			continue
		}
		switch kv[0] {
		case "--cluster-cidr":
			isClusterCIDRSet = true
		case "--service-cidr":
			isServerCIDRSet = true
		}
	}
	// HIGH LEVEL: Business logic
	if isClusterCIDRSet && isServerCIDRSet {
		return // both set, nothing to do
	}

	// DUPLICATION: Same pattern repeated 3 times with different values
	switch {
	case c.isIP4Set() && c.isIP6Set():
		if !isClusterCIDRSet {
			c.Configuration.K3SArgs = append(c.Configuration.K3SArgs,
				fmt.Sprintf("--cluster-cidr=%s,%s", clusterCIDRIPv4, clusterCIDRIPv6))
		}
		if !isServerCIDRSet {
			c.Configuration.K3SArgs = append(c.Configuration.K3SArgs,
				fmt.Sprintf("--service-cidr=%s,%s", serviceCIDRIPv4, serviceCIDRIPv6))
		}
	case c.isIP4Set():
		if !isClusterCIDRSet {
			c.Configuration.K3SArgs = append(c.Configuration.K3SArgs,
				"--cluster-cidr="+clusterCIDRIPv4)
		}
		if !isServerCIDRSet {
			c.Configuration.K3SArgs = append(c.Configuration.K3SArgs,
				"--service-cidr="+serviceCIDRIPv4)
		}
	case c.isIP6Set():
		if !isClusterCIDRSet {
			c.Configuration.K3SArgs = append(c.Configuration.K3SArgs,
				"--cluster-cidr="+clusterCIDRIPv6)
		}
		if !isServerCIDRSet {
			c.Configuration.K3SArgs = append(c.Configuration.K3SArgs,
				"--service-cidr="+serviceCIDRIPv6)
		}
	}
}
```

## First Refactoring Attempt: The Over-Abstraction Trap

Before showing the final solution, let's see a common mistake: **over-abstracting booleans**.

### What We Tried (Over-Abstraction ❌)

```go
// CIDRPresence - A wrapper that adds NO value
type CIDRPresence bool

const (
	cidrPresent CIDRPresence = true
)

func (p CIDRPresence) IsSet() bool {
	return bool(p)  // Just unwraps the bool!
}

type CIDRConfig struct {
	ClusterCIDR CIDRPresence  // Wrapped bool
	ServiceCIDR CIDRPresence  // Wrapped bool
}

func (c CIDRConfig) AreBothSet() bool {
	return c.ClusterCIDR.IsSet() && c.ServiceCIDR.IsSet()
}
```

### Why This Is Over-Abstraction

**Problems with CIDRPresence**:
1. ❌ **8 lines of code** for a trivial wrapper
2. ❌ **One method** that just unwraps: `return bool(p)`
3. ❌ **No type safety** - still just a bool underneath
4. ❌ **Not more readable** - compare:
   - `config.ClusterCIDR.IsSet()` (with wrapper)
   - `config.ClusterCIDRSet` (with good naming)
5. ❌ **No validation, no logic, no invariants** - pure ceremony
6. ❌ **Increases cognitive load** - one more type to understand

**The Honest Question**: Is `config.ClusterCIDR.IsSet()` **significantly** clearer than `config.ClusterCIDRSet`?

**Answer**: No! Good naming achieves the same clarity.

**The Real Need**: We DO need controlled mutation (only parser should set these values), but we don't need a wrapper type to achieve it.

### The Better Solution: Private Fields

Instead of wrapping with `CIDRPresence`, use **private fields with accessor methods**:

```go
// ✅ Simple, safe, clear
type CIDRConfig struct {
	clusterCIDRSet bool  // Private: can only be set by ParseCIDRConfig
	serviceCIDRSet bool  // Private: can only be set by ParseCIDRConfig
}

// Read-only accessors
func (c CIDRConfig) ClusterCIDRSet() bool { return c.clusterCIDRSet }
func (c CIDRConfig) ServiceCIDRSet() bool { return c.serviceCIDRSet }

func (c CIDRConfig) AreBothSet() bool {
	return c.clusterCIDRSet && c.serviceCIDRSet
}
```

**Why This Is Better**:
- ✅ **4 lines** vs 8 lines for CIDRPresence wrapper
- ✅ **Same safety** - compiler enforces that only parser can set values
- ✅ **Same readability** - `ClusterCIDRSet()` is just as clear
- ✅ **No wrapper ceremony** - fields are what they are: bools
- ✅ **Controlled mutation** - private fields can't be set externally

**Key Lesson**: Not every primitive needs a type. Use private fields when you need controlled mutation without wrapper overhead.

---

## After Refactoring (Final Solution)

```go
// Main function: Now a 7-line story!
func (c *Config) alignCIDRArgs() {
	ipConfig := IPVersionConfig{
		IPv4Enabled: c.isIP4Set(),
		IPv6Enabled: c.isIP6Set(),
	}

	k3sArgs := K3SArgs(c.K3SArgs)
	k3sArgs.AppendCIDRDefaults(ipConfig)
	c.K3SArgs = []string(k3sArgs)
}

// ==================== LEAF TYPE 1: K3SArgs ====================
// K3SArgs represents K3S command-line arguments.
// Encapsulates ALL argument list operations.
// Design choice: Type alias (not struct) allows direct use in JSON configs:
//   type Config struct {
//       K3SArgs K3SArgs `json:"k3sArgs,omitempty"`
//   }
type K3SArgs []string

// ParseCIDRConfig extracts which CIDRs are already configured.
// This is the ONLY place where CIDR flags can be set.
func (args K3SArgs) ParseCIDRConfig() CIDRConfig {
	var config CIDRConfig

	for _, arg := range args {
		key, _, found := parseK3SArgument(arg)
		if !found {
			continue
		}

		switch key {
		case "--cluster-cidr":
			config.clusterCIDRSet = true  // ✓ Controlled mutation in parser
		case "--service-cidr":
			config.serviceCIDRSet = true  // ✓ Controlled mutation in parser
		}
	}

	return config
}

// AppendCIDRDefaults adds missing CIDR arguments based on IP configuration.
func (args *K3SArgs) AppendCIDRDefaults(ipConfig IPVersionConfig) {
	existing := args.ParseCIDRConfig()

	if existing.AreBothSet() {
		return // nothing to do
	}

	defaults := ipConfig.DefaultCIDRs()

	if !existing.ClusterCIDRSet() {  // ✓ Read-only access via method
		*args = append(*args, defaults.ClusterCIDRArg())
	}

	if !existing.ServiceCIDRSet() {  // ✓ Read-only access via method
		*args = append(*args, defaults.ServiceCIDRArg())
	}
}

// parseK3SArgument splits a K3S argument into key and value.
func parseK3SArgument(arg string) (key, value string, ok bool) {
	parts := strings.SplitN(arg, "=", 2)
	if len(parts) != 2 {
		return "", "", false
	}
	return parts[0], parts[1], true
}

// ==================== LEAF TYPE 2: CIDRConfig ====================
// CIDRConfig represents which CIDR configurations are present.
// Uses private fields for controlled mutation - can only be set by ParseCIDRConfig.
type CIDRConfig struct {
	clusterCIDRSet bool  // Private: controlled mutation
	serviceCIDRSet bool  // Private: controlled mutation
}

// ClusterCIDRSet returns true if cluster CIDR is configured.
func (c CIDRConfig) ClusterCIDRSet() bool {
	return c.clusterCIDRSet
}

// ServiceCIDRSet returns true if service CIDR is configured.
func (c CIDRConfig) ServiceCIDRSet() bool {
	return c.serviceCIDRSet
}

// AreBothSet returns true if both cluster and service CIDRs are configured.
func (c CIDRConfig) AreBothSet() bool {
	return c.clusterCIDRSet && c.serviceCIDRSet
}

// ==================== LEAF TYPE 3: IPVersionConfig ====================
// IPVersionConfig describes which IP versions are enabled.
type IPVersionConfig struct {
	IPv4Enabled bool
	IPv6Enabled bool
}

func (cfg IPVersionConfig) DefaultCIDRs() DefaultCIDRValues {
	return DefaultCIDRValues{
		ipv4Enabled: cfg.IPv4Enabled,
		ipv6Enabled: cfg.IPv6Enabled,
	}
}

// DefaultCIDRValues generates default CIDR arguments based on IP config.
type DefaultCIDRValues struct {
	ipv4Enabled bool
	ipv6Enabled bool
}

func (d DefaultCIDRValues) ClusterCIDRArg() string {
	return "--cluster-cidr=" + d.clusterCIDRValue()
}

func (d DefaultCIDRValues) ServiceCIDRArg() string {
	return "--service-cidr=" + d.serviceCIDRValue()
}

func (d DefaultCIDRValues) clusterCIDRValue() string {
	var cidrs []string
	if d.ipv4Enabled {
		cidrs = append(cidrs, defaultClusterCIDRIPv4)
	}
	if d.ipv6Enabled {
		cidrs = append(cidrs, defaultClusterCIDRIPv6)
	}
	return strings.Join(cidrs, ",")
}

func (d DefaultCIDRValues) serviceCIDRValue() string {
	var cidrs []string
	if d.ipv4Enabled {
		cidrs = append(cidrs, defaultServiceCIDRIPv4)
	}
	if d.ipv6Enabled {
		cidrs = append(cidrs, defaultServiceCIDRIPv6)
	}
	return strings.Join(cidrs, ",")
}
```

## Refactoring Thought Process

### Step 1: Recognize Primitive Obsession - The Root Cause

**What's happening**: Function operates on raw `[]string` with manual parsing scattered throughout
```go
// Config struct uses primitive type
type Config struct {
    K3SArgs []string `json:"k3sArgs,omitempty"`  // Just a slice!
}

// Parsing logic mixed into business logic
for _, arg := range c.K3SArgs {
    kv := strings.SplitN(arg, "=", 2)  // String parsing
    if len(kv) != 2 { continue }       // Validation
    switch kv[0] { ... }               // Business logic
}
```

→ **Decision**: Extract a `K3SArgs` type alias to encapsulate argument list operations

```go
type K3SArgs []string  // Type alias, not struct

type Config struct {
    K3SArgs K3SArgs `json:"k3sArgs,omitempty"`  // Now has methods!
}
```

**Why type alias vs struct?**
- ✅ Can use directly in JSON config structs (serializes as array)
- ✅ Can convert to/from `[]string` easily: `K3SArgs(slice)` and `[]string(k3sArgs)`
- ✅ No wrapper overhead
- ✅ Backward compatible with existing JSON configs

**Why this matters**:
- Once you have a type, you can move ALL operations on that data into methods
- Type can be used directly as a config field with JSON tags
- Creates a testable boundary
- Methods travel with the data everywhere it's used

### Step 2: Identify What Logic Belongs Where

**Analysis of the original function**:
1. **Parse existing arguments** → Belongs in `K3SArgs.ParseCIDRConfig()`
2. **Track which CIDRs exist** → Needs domain type: `CIDRConfig`
3. **Determine defaults based on IP version** → Needs config type: `IPVersionConfig`
4. **Generate CIDR strings** → Needs value generator: `DefaultCIDRValues`

→ **Decision**: Extract 4 different types, each with one responsibility

**Why this matters**: Instead of one 60-line function, we get 4 small leaf types that are independently testable.

### Step 3: Replace Boolean Flags with Domain Type

**Before**: Two booleans tracking related state
```go
var isClusterCIDRSet bool
var isServerCIDRSet bool
if isClusterCIDRSet && isServerCIDRSet { return }
```

**After**: Domain model with query method
```go
type CIDRConfig struct {
    clusterCIDRSet bool  // Private fields
    serviceCIDRSet bool
}

func (c CIDRConfig) AreBothSet() bool {
    return c.clusterCIDRSet && c.serviceCIDRSet
}

if existing.AreBothSet() { return }
```

→ **Why this transformation matters**:
- Reads like English: "are both set?"
- Encapsulates the logic in one place
- Extensible: easy to add DNS CIDR field
- Groups related state

### Step 3.5: Recognize Over-Abstraction (Critical Decision!)

**Temptation**: Wrap the bool in a type
```go
// ❌ Over-abstraction!
type CIDRPresence bool
func (p CIDRPresence) IsSet() bool { return bool(p) }

type CIDRConfig struct {
    ClusterCIDR CIDRPresence
    ServiceCIDR CIDRPresence
}
```

**Questions to ask**:
1. Does `CIDRPresence` add meaningful methods? → **NO** (just `.IsSet()` which unwraps)
2. Does it enforce invariants? → **NO** (still just a bool)
3. Does it need controlled mutation? → **YES!** (should only be set by parser)
4. Is `.ClusterCIDR.IsSet()` clearer than `.ClusterCIDRSet()`? → **NO!**

→ **Decision**: Don't create `CIDRPresence` wrapper. Instead, use **private fields** for controlled mutation:

```go
// ✅ Better: Private fields + accessor methods
type CIDRConfig struct {
    clusterCIDRSet bool  // Private: only parser can set
    serviceCIDRSet bool
}

func (c CIDRConfig) ClusterCIDRSet() bool { return c.clusterCIDRSet }
func (c CIDRConfig) ServiceCIDRSet() bool { return c.serviceCIDRSet }
```

**Why this matters**:
- Achieves same safety (compiler-enforced controlled mutation)
- 4 fewer lines than wrapper approach
- No ceremonial type wrapping
- Just as readable: `ClusterCIDRSet()` vs `ClusterCIDR.IsSet()`

**Key lesson**: Not every primitive needs a type. Use private fields when you need controlled mutation without wrapper overhead.

### Step 4: Eliminate Switch Statement Duplication

**Problem identified**: Same pattern repeated 3 times
```go
case c.isIP4Set() && c.isIP6Set():
    if !isClusterCIDRSet { append(..., IPv4+IPv6) }
    if !isServerCIDRSet { append(..., IPv4+IPv6) }
case c.isIP4Set():
    if !isClusterCIDRSet { append(..., IPv4) }
    if !isServerCIDRSet { append(..., IPv4) }
case c.isIP6Set():
    // Same pattern again!
```

**What differs**: Only the CIDR values (IPv4 vs IPv6 vs both)

→ **Decision**: Extract value generation into `DefaultCIDRValues` type

**Result**: The pattern disappears entirely - replaced by:
```go
defaults := ipConfig.DefaultCIDRs()
if !existing.ClusterCIDR.IsSet() {
    *args = append(*args, defaults.ClusterCIDRArg())
}
```

**Why this matters**: Duplication eliminated by separating data selection from flow control.

### Step 5: Storify the Main Function

**Goal**: Make it read like a story at ONE abstraction level

**Process**:
```go
// Step 1: Create configuration object (HIGH LEVEL)
ipConfig := IPVersionConfig{
    IPv4Enabled: c.isIP4Set(),
    IPv6Enabled: c.isIP6Set(),
}

// Step 2: Convert to typed wrapper (HIGH LEVEL)
k3sArgs := K3SArgs(c.K3SArgs)

// Step 3: Apply business logic (HIGH LEVEL)
k3sArgs.AppendCIDRDefaults(ipConfig)

// Step 4: Store result (HIGH LEVEL)
c.K3SArgs = []string(k3sArgs)
```

**Read it aloud**: "Create IP config, convert args to typed wrapper, append CIDR defaults, store back."

→ **Result**: All implementation details (parsing, switching, string building) are hidden in leaf types

## Key Improvements

### Architecture
* **Fat function became lean orchestrator** - 60 lines → 7 lines
* **Created 3 leaf types** - Each handles one concern:
  - `K3SArgs`: Argument list operations (parsing, appending) - **usable as config field**
  - `CIDRConfig`: Domain model with **private fields for safety**
  - `IPVersionConfig` + `DefaultCIDRValues`: CIDR value generation
* **Clear separation** - Parsing vs Detection vs Value Generation vs Orchestration
* **Type alias pattern** - `K3SArgs` as type alias enables direct use in config structs with JSON serialization
* **Avoided over-abstraction** - Rejected `CIDRPresence` wrapper, used private fields instead (4 fewer lines, same safety)

### Readability
* **Storified main function** - Reads like: create config → convert → append → store
* **Fixed misleading name** - `validateCIDR()` → `alignCIDRArgs()` (now accurately describes mutation)
* **Query methods read like English**:
  ```go
  if existing.AreBothSet() { return }
  if !existing.ClusterCIDR.IsSet() { /* ... */ }
  ```
* **Single abstraction level** - Main function operates entirely at HIGH level

### Testability
* **All leaf types testable independently**:
  ```go
  // Test argument parsing without Config
  func TestK3SArgs_ParseCIDRConfig(t *testing.T) {
      args := K3SArgs{"--cluster-cidr=10.0.0.0/8", "--other-flag=value"}
      config := args.ParseCIDRConfig()
      assert.True(t, config.ClusterCIDR.IsSet())
      assert.False(t, config.ServiceCIDR.IsSet())
  }

  // Test CIDR value generation without network code
  func TestDefaultCIDRValues_ClusterCIDRArg(t *testing.T) {
      values := DefaultCIDRValues{ipv4Enabled: true, ipv6Enabled: true}
      arg := values.ClusterCIDRArg()
      assert.Equal(t, "--cluster-cidr=10.42.0.0/16,fd00:42::/56", arg)
  }

  // Test domain logic without parsing
  func TestCIDRConfig_AreBothSet(t *testing.T) {
      config := CIDRConfig{
          ClusterCIDR: cidrPresent,
          ServiceCIDR: cidrPresent,
      }
      assert.True(t, config.AreBothSet())
  }
  ```
* **No mocking needed** - Each type constructed with simple values
* **100% coverage achievable** - All logic in leaf types

### Complexity Reduction
**Before**:
- 60 lines in one function
- Cyclomatic complexity: 12
- Cognitive complexity: 18
- 3 nesting levels

**After**:
- Main function: 7 lines, complexity 1
- Largest helper: 15 lines, complexity 4
- Max nesting: 2 levels
- **Most complexity in leaf types** (easily testable)

### Avoiding Over-Abstraction
* **Rejected CIDRPresence wrapper** - Recognized it added no value:
  - Would be 8 lines for a trivial bool wrapper
  - Only one method: `.IsSet()` that just unwraps the bool
  - Not more readable than good naming
  - No validation, no logic, no invariants
* **Used private fields instead** - Achieved same safety with less code:
  - Compiler-enforced controlled mutation
  - Only parser can set values
  - 4 fewer lines than wrapper approach
* **Key decision**: Compared `config.ClusterCIDR.IsSet()` vs `config.ClusterCIDRSet()` honestly
  - **Answer**: Good naming is just as clear as method call
  - **Lesson**: Not every primitive needs a type

## Refactoring Patterns Applied

1. **Replace Primitive with Domain Type (Type Alias Pattern)** → Created `K3SArgs` type alias for `[]string` (usable in config fields)
2. **Extract Multiple Leaf Types** → Created 3 leaf types (`K3SArgs`, `CIDRConfig`, `IPVersionConfig`) instead of one complex function
3. **Storifying** → Main function reads: create config → convert → append → store (all at same abstraction level)
4. **Replace Boolean Flags with Domain Model** → `isClusterCIDRSet, isServerCIDRSet` → `CIDRConfig` with **private fields** and query methods
5. **Eliminate Switch Duplication** → Extracted value generation to `DefaultCIDRValues`, eliminated 3 duplicate cases
6. **Introduce Parameter Object** → Created `IPVersionConfig` to pass related configuration together
7. **Query Method Pattern** → `AreBothSet()`, `ClusterCIDRSet()`, `ServiceCIDRSet()` read like English questions
8. **Avoid Over-Abstraction** → Rejected `CIDRPresence` wrapper, used private fields with accessors for controlled mutation

## The Type Extraction Strategy

**Before**: All logic in one place
```
Config.alignCIDRArgs() {
  // 60 lines of:
  // - String parsing (strings.SplitN, validation)
  // - Boolean flag tracking
  // - Switch statements with duplication
  // - String building (fmt.Sprintf, string concatenation)
  // - Slice mutation
}
```

**After**: Multiple focused leaf types
```
K3SArgs (LEAF TYPE - no external dependencies)
  ├─ ParseCIDRConfig()      // Parsing logic (juicy!)
  ├─ AppendCIDRDefaults()   // Mutation logic (juicy!)
  └─ parseK3SArgument()     // Helper (juicy!)

CIDRConfig (LEAF TYPE - domain model with private fields)
  ├─ clusterCIDRSet (private bool)
  ├─ serviceCIDRSet (private bool)
  ├─ ClusterCIDRSet()       // Accessor (read-only)
  ├─ ServiceCIDRSet()       // Accessor (read-only)
  └─ AreBothSet()           // Domain logic (juicy!)

  Note: No CIDRPresence wrapper! Private fields achieve
        same safety with less ceremony.

IPVersionConfig (LEAF TYPE - configuration)
  └─ DefaultCIDRs() → DefaultCIDRValues

DefaultCIDRValues (LEAF TYPE - value generator)
  ├─ ClusterCIDRArg()       // String building (juicy!)
  ├─ ServiceCIDRArg()       // String building (juicy!)
  ├─ clusterCIDRValue()     // IPv4/IPv6 selection (juicy!)
  └─ serviceCIDRValue()     // IPv4/IPv6 selection (juicy!)

Config (ORCHESTRATOR)
  └─ alignCIDRArgs()        // Thin story: 7 lines
```

**Result**:
- Main function is 7 lines of pure orchestration
- ALL complexity moved to leaf types
- Each leaf type achieves 100% unit test coverage
- No mocking required for any test

## Linter Metrics

**Before**:
- Lines: 60
- Cyclomatic complexity: 12
- Cognitive complexity: 18
- Functions: 1 (doing everything)
- Testable units: 1 (requires full Config)

**After**:
- Main function: 7 lines, complexity 1
- Total lines: ~146 (across 5 types + helpers)
- Max complexity per function: 4
- Testable units: 9 (all independently testable)
- Leaf types: 3 (all with 100% coverage potential)

## Abstraction Balance: Comparison Table

| Approach | Total Lines | Types | Readability | Safety | Ceremony | Verdict |
|----------|-------------|-------|-------------|--------|----------|---------|
| **CIDRPresence wrapper** | ~150 | 6 | Good | Low | High | ❌ Over-abstraction |
| **Public bool fields** | ~142 | 5 | Good | Low | Low | ⚠️ Acceptable for small teams |
| **Private bool + accessors** | ~146 | 5 | Good | **High** | Low | ✅ **Recommended** |

**Why Private Fields Win**:
- Only 4 extra lines vs public fields (2 accessor methods)
- 4 fewer lines than CIDRPresence wrapper
- Compiler-enforced mutation control (can only be set in `ParseCIDRConfig`)
- Same readability as public fields
- Best safety-to-complexity ratio
- No wrapper ceremony

## Remaining Opportunities

**What could still be improved** (and why we stopped):

### 1. Why We Rejected CIDRPresence Wrapper ❌

**Could have done**:
```go
type CIDRPresence bool
func (p CIDRPresence) IsSet() bool { return bool(p) }
```

**Why we didn't**:
- ❌ 8 lines for a trivial bool wrapper
- ❌ Only one method that just unwraps: `return bool(p)`
- ❌ Not more readable: `config.ClusterCIDR.IsSet()` vs `config.ClusterCIDRSet()`
- ❌ No validation, no logic, no invariants
- ❌ Would add ceremony without benefit

**What we did instead**: Private bool fields with accessor methods
- ✅ Same safety (compiler-enforced controlled mutation)
- ✅ 4 fewer lines
- ✅ No wrapper overhead
- ✅ Just as readable

**Lesson**: **Not every primitive needs a type.** Ask: "Does this wrapper add meaningful logic or just ceremony?"

### 2. Why We Chose Private Fields Over Public Fields

**Could have used public fields**:
```go
type CIDRConfig struct {
    ClusterCIDRSet bool  // Public
    ServiceCIDRSet bool  // Public
}
```

**Why we used private fields**:
- ✅ Compiler enforces that only `ParseCIDRConfig` can set values
- ✅ Single source of truth for where values come from
- ✅ Easy to debug: only one place to check
- ✅ Only 4 extra lines (2 accessor methods)
- ✅ Public fields would work for small, disciplined teams, but private fields are safer

**Lesson**: **Use private fields when mutation should be controlled.** Only 4 lines for compile-time safety.

### 3. DefaultCIDRValues Has Similar Methods

**Could extract**:
- `clusterCIDRValue()` and `serviceCIDRValue()` are similar
- Could extract common pattern with constants as parameters

**Why we stopped**:
- Only 2 cases - extraction would be premature abstraction
- Current code is clear and straightforward
- YAGNI principle applies

### 4. K3SArgs Could Support More Operations

**Could add**:
- `Remove()`, `Update()`, `HasFlag()` methods

**Why we stopped**:
- YAGNI - only need parsing and appending for now
- Add methods when you need them, not before

### 5. IPVersionConfig Is Just Two Bools

**Could use enum**:
```go
type IPVersion int
const (
    IPv4Only IPVersion = iota
    IPv6Only
    DualStack
)
```

**Why we stopped**:
- Two bools are clear and simple enough
- Enum would add complexity without clarity benefit
- Current code is self-documenting

### 6. Why Type Alias Over Struct for K3SArgs

```go
// ❌ Struct would require unwrapping for JSON
type K3SArgs struct {
    args []string
}
type Config struct {
    K3SArgs K3SArgs // JSON: {"k3sArgs": {"args": [...]}}
}

// ✅ Type alias works directly
type K3SArgs []string
type Config struct {
    K3SArgs K3SArgs `json:"k3sArgs,omitempty"` // JSON: {"k3sArgs": [...]}
}
```

---

## Key Lessons: When to Stop Refactoring

**Good refactoring knows when to stop.** We achieved our goals:
- ✅ Main function reads like a story (7 lines)
- ✅ All logic extracted to testable leaf types
- ✅ No primitive obsession (created `K3SArgs` with real behavior)
- ✅ **Avoided over-abstraction** (rejected `CIDRPresence` wrapper)
- ✅ Switch duplication eliminated
- ✅ Complexity under control
- ✅ Controlled mutation via private fields
- ✅ Type alias pattern enables clean JSON serialization

**The Balance**:
```
Too Simple          Sweet Spot              Over-Engineering
    |                   |                          |
Raw primitives    Domain types           Types for everything
[]string           K3SArgs               CIDRPresence wrapper
bool flags         CIDRConfig            Every bool wrapped
                   (private fields)
```

**Critical Questions Before Creating a Type**:
1. Does it have >1 meaningful method with logic? (Not just unwrapping)
2. Does it enforce invariants or validation?
3. Does it need controlled mutation? (Use private fields, not wrappers)
4. Is the method call **significantly** clearer than good naming?
5. Does it hide complex implementation?

**If answers are mostly NO** → Use primitives with good naming (or private fields for safety)

Further refactoring would be over-engineering at this point.