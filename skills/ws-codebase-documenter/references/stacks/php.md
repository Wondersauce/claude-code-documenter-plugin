# PHP Stack Reference

## Detection Files
- `composer.json` (primary)
- `composer.lock`
- `*.php` files

## Public vs Private API

### Visibility Modifiers
```php
class MyClass
{
    // Public: Accessible everywhere
    public string $publicProperty;
    public function publicMethod(): void { }

    // Protected: Accessible in class and subclasses
    protected string $protectedProperty;
    protected function protectedMethod(): void { }

    // Private: Accessible only in this class
    private string $privateProperty;
    private function privateMethod(): void { }
}
```

### Interface Exposure
```php
// Public API is typically defined by interfaces
interface UserServiceInterface
{
    public function find(string $id): ?User;
    public function create(array $data): User;
}
```

### Trait Visibility
```php
trait Timestamps
{
    public \DateTime $createdAt;
    public \DateTime $updatedAt;
}
```

## Documentation Comments

### PHPDoc Format
```php
/**
 * Creates a new user with the given details.
 *
 * This method validates the input, hashes the password,
 * and persists the user to the database.
 *
 * @param string $name The user's display name
 * @param string $email The user's email address
 * @param array{role?: string, active?: bool} $options Additional options
 *
 * @return User The created user instance
 *
 * @throws InvalidArgumentException When name or email is empty
 * @throws DuplicateEmailException When email already exists
 *
 * @example
 * $user = $service->createUser('John', 'john@example.com');
 * echo $user->getId();
 *
 * @see User
 * @see UserRepository::save()
 *
 * @since 1.0.0
 * @deprecated 2.0.0 Use create() instead
 */
public function createUser(string $name, string $email, array $options = []): User
```

### Common PHPDoc Tags
- `@param type $name Description` - Parameter
- `@return type Description` - Return value
- `@throws ExceptionClass Description` - Exception
- `@var type Description` - Property/variable
- `@see reference` - Related item
- `@since version` - Version introduced
- `@deprecated version Description` - Deprecation
- `@example` - Usage example
- `@method returnType name(params)` - Magic method
- `@property type $name` - Magic property

### Class Documentation
```php
/**
 * Manages user authentication and sessions.
 *
 * This service handles login, logout, password reset,
 * and session management.
 *
 * @package App\Auth
 * @author Team <team@example.com>
 */
class AuthService
```

## Type System (PHP 8+)

### Type Declarations
```php
// Scalar types
function process(string $name, int $count, float $rate, bool $active): void

// Nullable types
function find(string $id): ?User

// Union types
function handle(string|int $id): Response|null

// Intersection types
function process(Countable&Iterator $items): void

// Mixed type
function log(mixed $data): void

// Never type (PHP 8.1+)
function fail(): never { throw new Exception(); }
```

### Constructor Property Promotion
```php
class User
{
    public function __construct(
        public readonly string $id,
        public string $name,
        private string $email,
    ) { }
}
```

### Enums (PHP 8.1+)
```php
/**
 * User status values.
 */
enum UserStatus: string
{
    case Active = 'active';
    case Pending = 'pending';
    case Suspended = 'suspended';
}
```

## Error Handling Patterns

### Exception Hierarchy
```php
/**
 * Base exception for application errors.
 */
class AppException extends \Exception
{
    public function __construct(
        string $message,
        public readonly string $errorCode,
        ?\Throwable $previous = null
    ) {
        parent::__construct($message, 0, $previous);
    }
}

class ValidationException extends AppException { }
class NotFoundException extends AppException { }
```

### Error Handling
```php
// Try-catch with multiple types
try {
    $result = $service->process($data);
} catch (ValidationException $e) {
    // Handle validation error
} catch (NotFoundException $e) {
    // Handle not found
} catch (\Exception $e) {
    // Handle other errors
}
```

## Project Structure Conventions

### PSR-4 Autoloading
```json
{
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
```

### Directory Structure
```
src/
  Controller/
  Service/
  Repository/
  Entity/
  Exception/
  DTO/
config/
tests/
public/
  index.php
composer.json
```

### Namespace Conventions
```php
namespace App\Service;
namespace App\Entity;
namespace App\Exception;
```

## Common Patterns to Recognize

### Constructor Injection
```php
class UserService
{
    public function __construct(
        private UserRepository $repository,
        private EventDispatcher $events,
    ) { }
}
```

### Repository Pattern
```php
interface UserRepository
{
    public function find(string $id): ?User;
    public function findByEmail(string $email): ?User;
    public function save(User $user): void;
    public function delete(User $user): void;
}
```

### Factory Methods
```php
class User
{
    public static function create(string $name, string $email): self
    {
        return new self($name, $email);
    }

    public static function fromArray(array $data): self
    {
        return new self($data['name'], $data['email']);
    }
}
```

### Value Objects
```php
final readonly class Email
{
    public function __construct(
        public string $value
    ) {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('Invalid email');
        }
    }
}
```

### Attributes (PHP 8+)
```php
#[Route('/users', methods: ['GET'])]
public function list(): Response

#[Deprecated('Use newMethod() instead')]
public function oldMethod(): void
```

### Magic Methods
```php
/**
 * @method User findByEmail(string $email)
 * @method User[] findByStatus(string $status)
 * @property-read int $count
 */
class UserRepository
{
    public function __call(string $name, array $arguments): mixed
    {
        // Dynamic method handling
    }
}
```
Document magic methods with @method tags.

## Frontend Indicators

### Asset Locations

| Framework | CSS Location | JS Location | Template Location |
|-----------|-------------|-------------|-------------------|
| WordPress | `src/css/`, `src/scss/`, `assets/css/` | `src/js/`, `assets/js/` | `templates/`, `template-parts/`, `blocks/` |
| Laravel | `resources/css/`, `resources/sass/` | `resources/js/` | `resources/views/**/*.blade.php` |
| Symfony | `assets/styles/` | `assets/` | `templates/**/*.html.twig` |
| Generic PHP | `public/css/`, `css/` | `public/js/`, `js/` | `views/`, `templates/` |

### WordPress Asset Registration

```php
// Enqueue styles
function enqueue_theme_styles() {
    wp_enqueue_style('main-style', get_template_directory_uri() . '/dist/css/main.css');
    wp_enqueue_style('block-style', get_template_directory_uri() . '/dist/css/blocks/hero.css');
}
add_action('wp_enqueue_scripts', 'enqueue_theme_styles');

// Enqueue scripts
function enqueue_theme_scripts() {
    wp_enqueue_script('main-js', get_template_directory_uri() . '/dist/js/app.js', [], false, true);
    wp_enqueue_script('block-js', get_template_directory_uri() . '/dist/js/blocks/hero.js', ['jquery'], false, true);
    wp_localize_script('main-js', 'themeData', ['ajaxUrl' => admin_url('admin-ajax.php')]);
}
add_action('wp_enqueue_scripts', 'enqueue_theme_scripts');

// Block editor assets
function enqueue_block_assets() {
    wp_enqueue_style('editor-styles', get_template_directory_uri() . '/dist/css/editor.css');
}
add_action('enqueue_block_editor_assets', 'enqueue_block_assets');
```

Scan for `wp_enqueue_style`, `wp_enqueue_script`, `wp_localize_script` to map which CSS/JS files are actually loaded and on which hooks.

### Laravel Asset Management

```php
// Vite (Laravel 9+)
@vite(['resources/css/app.css', 'resources/js/app.js'])

// Laravel Mix (legacy)
<link href="{{ mix('css/app.css') }}" rel="stylesheet">
<script src="{{ mix('js/app.js') }}"></script>
```

Config files: `vite.config.js` (Vite) or `webpack.mix.js` (Mix).

### Symfony Encore

```twig
{{ encore_entry_link_tags('app') }}
{{ encore_entry_script_tags('app') }}
```

Config: `webpack.config.js` with Symfony Encore setup.

### Build Tool Detection

| File | Tool | Framework |
|------|------|-----------|
| `webpack.config.js` (with Encore) | Webpack + Encore | Symfony |
| `webpack.mix.js` | Laravel Mix | Laravel |
| `vite.config.js` | Vite | Laravel 9+ |
| `webpack.config.js` (with entries in `src/js/`) | Webpack | WordPress |
| `gulpfile.js` | Gulp | WordPress/Generic |

## Cross-Module Patterns

### Namespace Detection

```php
// Cross-namespace calls indicate cross-module dependencies
use App\Services\PaymentService;
use App\Models\User;
use App\Events\OrderCompleted;
```

Module boundaries in PHP are typically defined by top-level namespace segments (e.g., `App\Users`, `App\Payments`, `App\Orders`).

### WordPress Hooks

WordPress hooks are the primary cross-module communication mechanism:

```php
// Registering an action (Module B provides functionality)
add_action('order_completed', function($order) {
    // Send notification
}, 10, 1);

// Firing an action (Module A triggers it)
do_action('order_completed', $order);

// Registering a filter (Module B modifies data)
add_filter('product_price', function($price, $product) {
    return apply_discount($price, $product);
}, 10, 2);

// Applying a filter (Module A requests modified data)
$price = apply_filters('product_price', $base_price, $product);
```

**Detection procedure**:
1. Scan for all `add_action()` and `add_filter()` calls → record hook name, callback, priority, module
2. Scan for all `do_action()` and `apply_filters()` calls → record hook name, module
3. Match registrations to invocations to build the hook dependency map

### Laravel Events

```php
// Event definition
class OrderCompleted {
    public function __construct(public Order $order) {}
}

// Dispatching
event(new OrderCompleted($order));
// or
Event::dispatch(new OrderCompleted($order));

// Listener (registered in EventServiceProvider)
protected $listen = [
    OrderCompleted::class => [
        SendOrderNotification::class,
        UpdateInventory::class,
    ],
];
```

### Symfony Events

```php
// Dispatching
$dispatcher->dispatch(new OrderCompletedEvent($order), OrderEvents::COMPLETED);

// Subscriber
class OrderSubscriber implements EventSubscriberInterface {
    public static function getSubscribedEvents(): array {
        return [OrderEvents::COMPLETED => 'onOrderCompleted'];
    }
}
```

### Service Container Dependencies

```php
// Laravel DI
class OrderService {
    public function __construct(
        private PaymentGateway $gateway,
        private NotificationService $notifications,
    ) {}
}

// Symfony DI (services.yaml)
// App\Service\OrderService:
//     arguments:
//         $gateway: '@App\Gateway\PaymentGateway'
```

Constructor injection parameters reveal cross-module dependencies.

### Shared Resources

- Database tables: Multiple models/repositories accessing the same table
- Cache keys: `Cache::get('key')` or `wp_cache_get('key', 'group')` used across modules
- Global functions: `wsum_*` helper functions called from multiple modules
- Configuration: `config('key')` (Laravel) or `get_option('key')` (WordPress) shared across modules
