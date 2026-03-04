# .NET Stack Reference

## Detection Files
- `*.csproj` (C# project)
- `*.fsproj` (F# project)
- `*.sln` (Solution file)
- `global.json`

## Public vs Private API

### Access Modifiers
```csharp
// Public: Accessible everywhere
public class PublicClass { }
public void PublicMethod() { }

// Internal: Accessible within assembly
internal class InternalClass { }

// Protected: Accessible in derived classes
protected void ProtectedMethod() { }

// Private: Accessible only within type (default for members)
private void PrivateMethod() { }
void ImplicitlyPrivate() { }  // Also private

// Protected Internal: Protected OR internal
protected internal void ProtectedInternal() { }

// Private Protected: Protected AND internal
private protected void PrivateProtected() { }
```

### InternalsVisibleTo
```csharp
[assembly: InternalsVisibleTo("MyApp.Tests")]
```
Makes internal members visible to test assemblies.

### Interface Implementation Visibility
```csharp
public class MyClass : IDisposable
{
    // Explicit implementation - only accessible via interface
    void IDisposable.Dispose() { }
}
```

## Documentation Comments

### XML Documentation
```csharp
/// <summary>
/// Creates a new user with the specified details.
/// </summary>
/// <param name="name">The user's display name.</param>
/// <param name="email">The user's email address.</param>
/// <returns>The created user instance.</returns>
/// <exception cref="ArgumentNullException">
/// Thrown when <paramref name="name"/> or <paramref name="email"/> is null.
/// </exception>
/// <exception cref="ValidationException">
/// Thrown when the email format is invalid.
/// </exception>
/// <example>
/// <code>
/// var user = CreateUser("John Doe", "john@example.com");
/// Console.WriteLine(user.Id);
/// </code>
/// </example>
/// <remarks>
/// This method validates the email format before creating the user.
/// </remarks>
/// <seealso cref="UpdateUser"/>
/// <seealso cref="DeleteUser"/>
public User CreateUser(string name, string email)
```

### Common XML Tags
- `<summary>` - Brief description
- `<param name="x">` - Parameter description
- `<returns>` - Return value description
- `<exception cref="T">` - Exception documentation
- `<example>` - Usage example
- `<remarks>` - Additional information
- `<seealso cref="X">` - Related items
- `<typeparam name="T">` - Generic parameter
- `<value>` - Property value description
- `<inheritdoc/>` - Inherit documentation

## Error Handling Patterns

### Exception Hierarchy
```csharp
public class AppException : Exception
{
    public string Code { get; }
    public AppException(string message, string code) : base(message)
    {
        Code = code;
    }
}

public class ValidationException : AppException { }
public class NotFoundException : AppException { }
```

### Exception Documentation
Document:
- What exceptions are thrown
- Conditions that cause each exception
- How to handle/recover

### Result Pattern (Modern)
```csharp
public readonly struct Result<T>
{
    public bool IsSuccess { get; }
    public T Value { get; }
    public Error Error { get; }
}
```

## Type System

### Nullable Reference Types
```csharp
// Non-nullable (C# 8+)
public string Name { get; set; }

// Nullable
public string? MiddleName { get; set; }

// Method signatures
public User? FindUser(string id)
public User GetUser(string id)  // Throws if not found
```

### Generics
```csharp
public class Repository<TEntity> where TEntity : class, IEntity
{
    public Task<TEntity?> GetByIdAsync(Guid id);
    public Task<IEnumerable<TEntity>> GetAllAsync();
}
```

### Records (C# 9+)
```csharp
/// <summary>
/// Represents a user in the system.
/// </summary>
/// <param name="Id">The unique identifier.</param>
/// <param name="Name">The user's name.</param>
public record User(Guid Id, string Name);
```

## Project Structure Conventions

### Solution Layout
```
MySolution.sln
src/
  MyApp/
    MyApp.csproj
    Program.cs
  MyApp.Core/
    MyApp.Core.csproj
    Entities/
    Services/
  MyApp.Infrastructure/
    MyApp.Infrastructure.csproj
tests/
  MyApp.Tests/
  MyApp.Integration.Tests/
```

### Project References
```xml
<ItemGroup>
  <ProjectReference Include="..\MyApp.Core\MyApp.Core.csproj" />
</ItemGroup>
```

### Namespace Conventions
```csharp
namespace MyCompany.MyApp.Core.Entities;
namespace MyCompany.MyApp.Core.Services;
```

## Common Patterns to Recognize

### Dependency Injection
```csharp
public class UserService
{
    public UserService(IUserRepository repository, ILogger<UserService> logger)
    { }
}

// Registration
services.AddScoped<IUserService, UserService>();
```

### Async/Await
```csharp
public async Task<User> GetUserAsync(string id, CancellationToken ct = default)
{
    return await _repository.GetByIdAsync(id, ct);
}
```
Document cancellation behavior.

### Options Pattern
```csharp
public class EmailOptions
{
    public string SmtpHost { get; set; } = "";
    public int SmtpPort { get; set; } = 587;
}

// Usage
services.Configure<EmailOptions>(configuration.GetSection("Email"));
```

### Extension Methods
```csharp
public static class StringExtensions
{
    /// <summary>
    /// Converts the string to title case.
    /// </summary>
    public static string ToTitleCase(this string input) { }
}
```

### Attributes
```csharp
[Obsolete("Use NewMethod instead", error: false)]
public void OldMethod() { }

[Required]
[StringLength(100, MinimumLength = 1)]
public string Name { get; set; }
```

### Interfaces
```csharp
/// <summary>
/// Defines operations for user management.
/// </summary>
public interface IUserService
{
    Task<User?> GetByIdAsync(Guid id);
    Task<User> CreateAsync(CreateUserRequest request);
    Task DeleteAsync(Guid id);
}
```

## Frontend Indicators

### Asset Locations

| Framework | CSS Location | JS Location | Template/View Location |
|-----------|-------------|-------------|----------------------|
| Blazor | `wwwroot/css/` | `wwwroot/js/` (minimal) | `Components/**/*.razor` |
| Razor Pages | `wwwroot/css/`, `wwwroot/lib/` | `wwwroot/js/`, `wwwroot/lib/` | `Pages/**/*.cshtml` |
| MVC | `wwwroot/css/`, `wwwroot/lib/` | `wwwroot/js/`, `wwwroot/lib/` | `Views/**/*.cshtml` |
| API-only | Typically none | Typically none | N/A |

### Component-Scoped CSS (Blazor)

```
Components/
├── Pages/
│   ├── Home.razor
│   └── Home.razor.css        ← Scoped to Home component
├── Layout/
│   ├── MainLayout.razor
│   └── MainLayout.razor.css  ← Scoped to MainLayout
```

Blazor uses CSS isolation: `Component.razor.css` is automatically scoped to `Component.razor`. The build produces a bundled `{ProjectName}.styles.css`.

### Asset Management

```html
<!-- _Layout.cshtml or _Host.cshtml -->
<link rel="stylesheet" href="~/css/site.css" />
<link rel="stylesheet" href="~/lib/bootstrap/dist/css/bootstrap.min.css" />
<script src="~/js/site.js"></script>

<!-- Blazor CSS isolation bundle -->
<link href="{ProjectName}.styles.css" rel="stylesheet" />
```

### Build Tool Detection

| File | Tool |
|------|------|
| `libman.json` | Library Manager (client-side libraries) |
| `bundleconfig.json` | BuildBundlerMinifier |
| `package.json` (alongside .csproj) | npm/Node.js build step |
| `webpack.config.*` | Webpack |
| `gulpfile.*` | Gulp |

### Tag Helpers

```html
<link asp-href-include="css/**/*.css" rel="stylesheet" />
<script asp-src-include="js/**/*.js"></script>
<environment include="Development">
    <link rel="stylesheet" href="~/css/site.css" />
</environment>
```

Scan for `asp-href-include`, `asp-src-include` tag helpers to understand asset inclusion patterns.

## Cross-Module Patterns

### Project Reference Detection

```xml
<!-- In .csproj files -->
<ProjectReference Include="..\Auth\Auth.csproj" />
<ProjectReference Include="..\Shared\Shared.csproj" />
```

Each `<ProjectReference>` in `.csproj` files defines a direct module dependency.

### Namespace-Based Module Detection

```csharp
// Cross-namespace imports indicate cross-module calls
using MyApp.Auth;
using MyApp.Payments;
using MyApp.Shared.Models;
```

Module boundaries are typically defined by project/namespace (e.g., `MyApp.Auth`, `MyApp.Orders`).

### Dependency Injection

```csharp
// Service registration in Program.cs or Startup.cs
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();
builder.Services.AddSingleton<ICacheService, RedisCacheService>();

// Constructor injection reveals dependencies
public class OrderController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly IPaymentService _paymentService;

    public OrderController(IUserService userService, IPaymentService paymentService)
    {
        _userService = userService;
        _paymentService = paymentService;
    }
}
```

The DI container IS the primary cross-module integration mechanism. Scan `Program.cs`/`Startup.cs` for `Add*` calls and constructors for injected interfaces.

### MediatR / CQRS Pattern

```csharp
// Command/Query (Module A sends)
public record CreateOrderCommand(string UserId, List<Item> Items) : IRequest<OrderResult>;

// Handler (Module B processes)
public class CreateOrderHandler : IRequestHandler<CreateOrderCommand, OrderResult>
{
    public async Task<OrderResult> Handle(CreateOrderCommand request, CancellationToken ct) { ... }
}

// Notification (event across modules)
public record OrderCreatedNotification(Guid OrderId) : INotification;
public class SendEmailHandler : INotificationHandler<OrderCreatedNotification> { ... }
public class UpdateInventoryHandler : INotificationHandler<OrderCreatedNotification> { ... }
```

MediatR `IRequest`/`INotification` types define cross-module contracts.

### Event Bus Patterns

```csharp
// Domain events
public interface IDomainEvent { }
public record OrderCompletedEvent(Guid OrderId, decimal Total) : IDomainEvent;

// Publishing
await _eventBus.PublishAsync(new OrderCompletedEvent(order.Id, order.Total));

// Handling
public class OrderCompletedHandler : IEventHandler<OrderCompletedEvent> { ... }
```

### Shared Resources

- DbContext: `ApplicationDbContext` or split contexts shared across modules
- Configuration: `IOptions<T>` pattern for shared settings
- Cache: `IDistributedCache` or `IMemoryCache` instances
- HttpClient: `IHttpClientFactory` with named clients shared across services
