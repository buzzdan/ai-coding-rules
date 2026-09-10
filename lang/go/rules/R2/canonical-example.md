Compact excerpt from the Port case (`R1-primitive-obsession.md` has the full
three-stage study — extraction, placement, testing):

```go
// Port cannot exist out of range — the constructor is the only entry.
type Port struct {
    name   string
    number int32
}

func ParsePort(name string, number int32) (Port, error) {
    if number <= 0 || number > 65535 {
        return Port{}, fmt.Errorf("port %q: %d out of range 1-65535", name, number)
    }
    return Port{name: name, number: number}, nil
}
```

Before this type existed, `p.Port > 0 && p.Port <= 65535` was duplicated across two
loops at the use site. After, there is no `IsValid()` and no re-check anywhere: the
concept of a maybe-invalid port is deleted from downstream logic, not relocated.

The same pattern for a composed object — validate dependencies once, then trust:

```go
// ❌ every method defends
type UserService struct {
    Repo Repository // exported, might be nil
}

func (s *UserService) CreateUser(ctx context.Context, u User) error {
    if s.Repo == nil { // repeated in every method; forget one → panic
        return errors.New("repo is nil")
    }
    return s.Repo.Save(ctx, u)
}

// ✅ constructor validates once; methods trust the receiver
type UserService struct {
    repo Repository // private
}

func NewUserService(repo Repository) (*UserService, error) {
    if repo == nil {
        return nil, errors.New("repo is required")
    }
    return &UserService{repo: repo}, nil
}

func (s *UserService) CreateUser(ctx context.Context, u User) error {
    return s.repo.Save(ctx, u) // no checks — an invalid service cannot exist
}
```
