# Go Stack Reference

## Detection Files
- `go.mod` (primary)
- `go.sum`

## Public vs Private API

### Capitalization Rule
```go
// Public: Uppercase first letter
func PublicFunction() {}
type PublicStruct struct {}
const PublicConst = 1
var PublicVar int

// Private: Lowercase first letter
func privateHelper() {}
type internalStruct struct {}
```

### Package Visibility
- `internal/` directory: Only accessible by parent and sibling packages
- Items in `internal/` are never public API

### Exported Fields
```go
type Config struct {
    Host     string  // Public: uppercase
    Port     int     // Public: uppercase
    password string  // Private: lowercase
}
```

## Documentation Comments

### Package Comments
```go
// Package auth provides authentication and authorization
// functionality for the application.
//
// The main entry points are [Authenticate] and [Authorize].
package auth
```

### Function Comments
```go
// Authenticate verifies user credentials and returns a session token.
//
// It accepts a username and password, validates them against the
// configured authentication backend, and returns a JWT token on success.
//
// Example:
//
//	token, err := auth.Authenticate("user@example.com", "password123")
//	if err != nil {
//	    log.Fatal(err)
//	}
//	fmt.Println(token)
func Authenticate(username, password string) (string, error)
```

### Type Comments
```go
// User represents an authenticated user in the system.
//
// Users are created through [CreateUser] and can be retrieved
// with [GetUser] or [FindUsers].
type User struct {
    // ID is the unique identifier for the user.
    ID string

    // Email is the user's email address, used for login.
    Email string

    // CreatedAt is when the user account was created.
    CreatedAt time.Time
}
```

### Deprecated Items
```go
// Deprecated: Use NewClient instead.
func CreateClient() *Client
```

## Error Handling Patterns

### Custom Errors
```go
// Sentinel errors
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
)

// Error types
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("%s: %s", e.Field, e.Message)
}
```

### Error Wrapping
```go
if err != nil {
    return fmt.Errorf("failed to process user %s: %w", userID, err)
}
```

### Error Checking
```go
// errors.Is for sentinel errors
if errors.Is(err, ErrNotFound) { ... }

// errors.As for error types
var valErr *ValidationError
if errors.As(err, &valErr) { ... }
```

## Type System

### Interfaces
```go
// Reader is the interface for reading data.
type Reader interface {
    // Read reads up to len(p) bytes into p.
    Read(p []byte) (n int, err error)
}
```

### Type Aliases and Definitions
```go
type UserID string           // New type
type Handler = func() error  // Alias
```

### Generics (Go 1.18+)
```go
type Result[T any] struct {
    Value T
    Error error
}

func Map[T, U any](items []T, fn func(T) U) []U
```

## Project Structure Conventions

### Standard Layout
```
cmd/
  myapp/
    main.go           # Entry point
pkg/
  mypackage/          # Public packages
    mypackage.go
    types.go
internal/
  helper/             # Private packages
    helper.go
```

### Flat Layout (Small Projects)
```
main.go
handler.go
model.go
repository.go
```

### Package Organization
```go
// Single-file packages: package name matches directory
// Multi-file packages: all files share package declaration
// doc.go: Package-level documentation
```

## Common Patterns to Recognize

### Options Pattern
```go
type Option func(*Config)

func WithTimeout(d time.Duration) Option {
    return func(c *Config) {
        c.Timeout = d
    }
}

func NewClient(opts ...Option) *Client
```

### Constructor Functions
```go
func NewUser(name, email string) (*User, error)
func MustNewUser(name, email string) *User  // Panics on error
```

### Interface Satisfaction
```go
// Compile-time interface check
var _ io.Reader = (*MyReader)(nil)
```

### Context Usage
```go
func (s *Service) Process(ctx context.Context, req *Request) (*Response, error)
```
Document context cancellation and timeout behavior.

### Embedded Types
```go
type Server struct {
    http.Server  // Embedded, inherits methods
    logger *Logger
}
```
Document which methods come from embedded types.

## Frontend Indicators

> Note: Go projects rarely have co-located frontend assets. This section applies only when the Go project serves web content (e.g., web applications using `html/template`, embedded SPAs, or HTMX-driven UIs).

### Asset Locations

| Pattern | CSS Location | JS Location | Template Location |
|---------|-------------|-------------|-------------------|
| Standard web app | `static/css/`, `web/static/css/` | `static/js/`, `web/static/js/` | `templates/`, `web/templates/` |
| Embedded assets | `embed` directive targets | `embed` directive targets | `embed` directive targets |
| Separate frontend | `frontend/`, `ui/`, `web/` | `frontend/`, `ui/`, `web/` | N/A (SPA) |

### Template Engine Detection

```go
// Standard library templates
import "html/template"
import "text/template"

// Template files: *.html, *.tmpl, *.gohtml
tmpl := template.Must(template.ParseGlob("templates/*.html"))
```

### Embedded Assets (Go 1.16+)

```go
//go:embed static/*
var staticFiles embed.FS

//go:embed templates/*
var templateFiles embed.FS
```

Scan for `//go:embed` directives to find embedded static asset directories.

### Separate Frontend Detection

If a `package.json` exists alongside `go.mod`, the project likely has a separate frontend build step. Check for:
- `frontend/` or `ui/` directory with its own `package.json`
- Build scripts in `Makefile` or `justfile` that reference frontend builds
- Docker multi-stage builds that include a frontend build step

## Cross-Module Patterns

### Package Import Detection

```go
// Cross-package imports
import (
    "myproject/internal/auth"
    "myproject/pkg/database"
    "myproject/internal/orders"
)

// Usage
user, err := auth.GetCurrentUser(ctx)
orders.Create(ctx, user.ID, items)
```

Module boundaries in Go are defined by packages. Cross-package function calls are integration points.

### Internal Directory Visibility

```
myproject/
├── internal/        # Only importable by myproject and its sub-packages
│   ├── auth/        # internal/auth can import internal/database
│   ├── database/
│   └── orders/
├── pkg/             # Importable by external projects
│   ├── client/
│   └── models/
└── cmd/
    └── server/
```

The `internal/` directory enforces visibility at the compiler level. Packages under `internal/` can only be imported by code rooted at the parent of `internal/`.

### Interface-Based Decoupling

```go
// Module A defines an interface for what it needs
type UserStore interface {
    GetUser(ctx context.Context, id string) (*User, error)
    SaveUser(ctx context.Context, user *User) error
}

// Module B implements the interface
type PostgresUserStore struct { db *sql.DB }
func (s *PostgresUserStore) GetUser(ctx context.Context, id string) (*User, error) { ... }

// Integration point: where concrete type is assigned to interface
func NewServer(store UserStore) *Server { ... }
```

Interface definitions and their concrete implementations crossing package boundaries are key integration points.

### Context Propagation

```go
// Context carrying values across package boundaries
ctx = context.WithValue(ctx, userKey, user)

// Retrieved in another package
user := ctx.Value(userKey).(*User)
```

Context values passed between packages represent implicit cross-module data flow.

### gRPC Service Boundaries

When `*.proto` files exist:
```protobuf
service OrderService {
    rpc CreateOrder(CreateOrderRequest) returns (Order);
}
```

Each gRPC service definition represents a formal module boundary with an explicit contract.

### Shared Resources

- Database connections: `*sql.DB` or ORM instance passed to multiple packages
- Redis/cache clients: shared across packages via dependency injection
- Configuration: `config` package or struct passed at startup
- Logger: shared `*slog.Logger` or custom logger instance
