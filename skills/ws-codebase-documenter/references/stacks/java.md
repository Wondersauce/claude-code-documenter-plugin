# Java Stack Reference

## Detection Files
- `pom.xml` (Maven)
- `build.gradle`, `build.gradle.kts` (Gradle)
- `*.java` files

## Public vs Private API

### Access Modifiers
```java
// Public: Accessible everywhere
public class PublicClass { }
public void publicMethod() { }

// Protected: Accessible in package and subclasses
protected void protectedMethod() { }

// Package-private (default): Accessible within package
class PackageClass { }
void packageMethod() { }

// Private: Accessible only within class
private void privateMethod() { }
```

### Module System (Java 9+)
```java
// module-info.java
module com.myapp {
    exports com.myapp.api;           // Public packages
    exports com.myapp.spi to com.myapp.impl;  // Qualified export
    requires com.other.module;
}
```

### Interface vs Implementation
```java
// Public API (interface)
public interface UserService {
    User findById(String id);
}

// Implementation (often package-private or in impl package)
class UserServiceImpl implements UserService {
    @Override
    public User findById(String id) { }
}
```

## Documentation Comments

### Javadoc Format
```java
/**
 * Creates a new user with the specified details.
 *
 * <p>This method validates the input and persists the user
 * to the database. The user ID is automatically generated.
 *
 * @param name the user's display name, must not be null or empty
 * @param email the user's email address, must be valid format
 * @return the created user instance with generated ID
 * @throws IllegalArgumentException if name or email is invalid
 * @throws DuplicateUserException if email already exists
 * @see User
 * @see #updateUser(String, UserUpdateRequest)
 * @since 1.0
 * @deprecated Use {@link #createUser(CreateUserRequest)} instead
 */
public User createUser(String name, String email) {
```

### Common Javadoc Tags
- `@param name description` - Parameter
- `@return description` - Return value
- `@throws Exception description` - Exception
- `@see reference` - Related item
- `@since version` - Version introduced
- `@deprecated explanation` - Deprecation notice
- `@author name` - Author (usually omitted)
- `{@link Class#method}` - Inline link
- `{@code example}` - Code formatting
- `<p>`, `<ul>`, `<li>` - HTML formatting

### Package Documentation
```java
// package-info.java
/**
 * Provides authentication and authorization services.
 *
 * <p>The main entry point is {@link com.myapp.auth.AuthService}.
 *
 * @since 1.0
 */
package com.myapp.auth;
```

## Error Handling Patterns

### Exception Hierarchy
```java
// Base exception
public class AppException extends RuntimeException {
    private final String errorCode;

    public AppException(String message, String errorCode) {
        super(message);
        this.errorCode = errorCode;
    }

    public String getErrorCode() { return errorCode; }
}

// Specific exceptions
public class NotFoundException extends AppException { }
public class ValidationException extends AppException { }
```

### Checked vs Unchecked
- Checked: Must be declared in throws clause
- Unchecked (RuntimeException): Optional declaration

### Exception Documentation
Document:
- All checked exceptions in `@throws`
- Runtime exceptions that callers should handle
- Recovery strategies

## Type System

### Generics
```java
public interface Repository<T, ID> {
    Optional<T> findById(ID id);
    List<T> findAll();
    T save(T entity);
}

// Bounded generics
public <T extends Comparable<T>> T max(List<T> items)
```

### Optional
```java
/**
 * Finds a user by ID.
 *
 * @param id the user ID
 * @return an Optional containing the user if found, empty otherwise
 */
public Optional<User> findById(String id)
```

### Records (Java 16+)
```java
/**
 * Represents a user in the system.
 *
 * @param id the unique identifier
 * @param name the user's display name
 * @param email the user's email address
 */
public record User(String id, String name, String email) { }
```

## Project Structure Conventions

### Maven Layout
```
src/
  main/
    java/
      com/myapp/
        Application.java
        api/           # Public interfaces
        impl/          # Implementations
        model/         # Domain models
        exception/     # Custom exceptions
    resources/
  test/
    java/
    resources/
pom.xml
```

### Package Naming
```
com.company.product.module.submodule
```

### Common Package Structure
```
com.myapp.api        # Public interfaces
com.myapp.impl       # Implementations
com.myapp.model      # Domain objects
com.myapp.dto        # Data transfer objects
com.myapp.exception  # Exceptions
com.myapp.util       # Utilities
com.myapp.config     # Configuration
```

## Common Patterns to Recognize

### Builder Pattern
```java
public class User {
    public static Builder builder() { }

    public static class Builder {
        public Builder name(String name) { }
        public Builder email(String email) { }
        public User build() { }
    }
}
```

### Factory Methods
```java
public static User of(String name, String email)
public static User fromJson(String json)
public static User empty()
```

### Dependency Injection (Spring)
```java
@Service
public class UserService {
    private final UserRepository repository;

    @Autowired  // Often implicit in constructor
    public UserService(UserRepository repository) {
        this.repository = repository;
    }
}
```

### Annotations
```java
@Deprecated(since = "2.0", forRemoval = true)
@NotNull
@Valid
@Transactional
@Cacheable
```

### Stream API
```java
/**
 * Finds all active users matching the filter.
 *
 * @param filter the filter criteria
 * @return stream of matching users, never null
 */
public Stream<User> findActive(UserFilter filter)
```

### Functional Interfaces
```java
@FunctionalInterface
public interface Processor<T, R> {
    R process(T input) throws ProcessingException;
}
```

### Sealed Classes (Java 17+)
```java
public sealed interface Shape
    permits Circle, Rectangle, Triangle {
}
```

## Frontend Indicators

### Asset Locations

| Framework | CSS Location | JS Location | Template Location |
|-----------|-------------|-------------|-------------------|
| Spring Boot | `src/main/resources/static/css/` | `src/main/resources/static/js/` | `src/main/resources/templates/` |
| Spring + Thymeleaf | `src/main/resources/static/css/` | `src/main/resources/static/js/` | `src/main/resources/templates/**/*.html` |
| JSP (legacy) | `webapp/css/`, `webapp/WEB-INF/css/` | `webapp/js/`, `webapp/WEB-INF/js/` | `webapp/WEB-INF/views/**/*.jsp` |
| Vaadin | `frontend/styles/` | `frontend/` | N/A (Java-based UI) |

### Template References

**Thymeleaf**:
```html
<link th:href="@{/css/style.css}" rel="stylesheet">
<script th:src="@{/js/app.js}"></script>
<link th:href="@{/webjars/bootstrap/css/bootstrap.min.css}" rel="stylesheet">
```

**JSP**:
```jsp
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/style.css">
<script src="${pageContext.request.contextPath}/js/app.js"></script>
```

### Build Tool Detection

| Indicator | Tool |
|-----------|------|
| `frontend-maven-plugin` in `pom.xml` | Maven with Node.js frontend build |
| `com.github.node-gradle.node` in `build.gradle` | Gradle with Node.js frontend build |
| `package.json` alongside `pom.xml`/`build.gradle` | Separate frontend build step |
| `webjars` dependencies | WebJars (pre-packaged client-side libs) |

### Separate Frontend Detection

If a `package.json` exists alongside Java build files:
- Check for `frontend/` or `src/main/frontend/` directory
- Maven: look for `frontend-maven-plugin` execution phases
- Gradle: look for Node plugin tasks
- Multi-module: frontend may be a separate Maven/Gradle module

## Cross-Module Patterns

### Package Import Detection

```java
// Cross-package imports
import com.myapp.auth.AuthService;
import com.myapp.payments.PaymentProcessor;
import com.myapp.shared.models.User;
```

Module boundaries are defined by top-level packages (e.g., `com.myapp.auth`, `com.myapp.orders`).

### Java Module System (Java 9+)

```java
// module-info.java
module com.myapp.orders {
    requires com.myapp.auth;
    requires com.myapp.shared;
    exports com.myapp.orders.api;
    exports com.myapp.orders.model;
}
```

`requires` defines module dependencies. `exports` defines the public API boundary.

### Spring Dependency Injection

```java
// Constructor injection reveals cross-module dependencies
@Service
public class OrderService {
    private final UserRepository userRepository;    // from auth module
    private final PaymentService paymentService;    // from payments module
    private final NotificationService notifier;     // from notifications module

    public OrderService(UserRepository userRepository,
                       PaymentService paymentService,
                       NotificationService notifier) {
        this.userRepository = userRepository;
        this.paymentService = paymentService;
        this.notifier = notifier;
    }
}
```

### Spring Events

```java
// Event definition
public class OrderCompletedEvent extends ApplicationEvent {
    private final Order order;
    public OrderCompletedEvent(Object source, Order order) {
        super(source);
        this.order = order;
    }
}

// Publishing (in one module)
applicationEventPublisher.publishEvent(new OrderCompletedEvent(this, order));

// Listening (in another module)
@EventListener
public void handleOrderCompleted(OrderCompletedEvent event) {
    // Process event
}

// Or async
@Async
@EventListener
public void handleOrderCompletedAsync(OrderCompletedEvent event) { }
```

### Maven/Gradle Multi-Module

**Maven**:
```xml
<!-- Parent pom.xml -->
<modules>
    <module>auth</module>
    <module>orders</module>
    <module>shared</module>
</modules>

<!-- Child module dependency -->
<dependency>
    <groupId>com.myapp</groupId>
    <artifactId>auth</artifactId>
</dependency>
```

**Gradle**:
```groovy
// settings.gradle
include 'auth', 'orders', 'shared'

// build.gradle (orders module)
dependencies {
    implementation project(':auth')
    implementation project(':shared')
}
```

Multi-module dependencies define formal cross-module contracts.

### Shared Resources

- JPA entities: `@Entity` classes referenced across services
- Configuration beans: `@Configuration` classes providing shared beans
- Cache: `@Cacheable`, `@CacheEvict` with shared cache names
- Database: shared `DataSource` or `EntityManager`
- Message queues: JMS/Kafka producers and consumers across modules
