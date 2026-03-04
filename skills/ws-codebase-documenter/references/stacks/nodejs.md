# Node.js/TypeScript Stack Reference

## Detection Files
- `package.json` (primary)
- `tsconfig.json` (TypeScript)
- `.nvmrc`, `.node-version`

## Public vs Private API

### Export Patterns
```typescript
// Public: Explicit exports
export function publicFunc() {}
export class PublicClass {}
export type PublicType = {}
export { namedExport } from './module'
export default MainClass

// Private: No export keyword
function privateFunc() {}
const internalHelper = () => {}
```

### Index File Patterns
Public API is typically re-exported from:
- `src/index.ts` or `index.ts`
- `src/public/index.ts`
- Files referenced in `package.json` exports field

### package.json Exports Field
```json
{
  "exports": {
    ".": "./dist/index.js",
    "./utils": "./dist/utils/index.js"
  }
}
```
Anything in `exports` is public API.

## Documentation Comments

### JSDoc Format
```typescript
/**
 * Brief description on first line.
 *
 * Detailed description follows after blank line.
 *
 * @param name - Parameter description
 * @param options - Options object
 * @param options.timeout - Timeout in ms
 * @returns Description of return value
 * @throws {TypeError} When name is invalid
 * @example
 * const result = myFunction('test', { timeout: 1000 })
 */
```

### TSDoc Additions
```typescript
/**
 * @public - Explicitly marks as public API
 * @internal - Marks as internal (not public)
 * @beta - Unstable API
 * @deprecated Use newFunction instead
 */
```

## Error Handling Patterns

### Custom Error Classes
```typescript
class CustomError extends Error {
  constructor(message: string, public code: string) {
    super(message)
    this.name = 'CustomError'
  }
}
```

### Error Throwing
- Sync functions: `throw new Error()`
- Async functions: rejected promise or thrown error
- Callbacks: `callback(error, null)`

### Error Types to Document
- Input validation errors
- Network/IO errors
- Business logic errors
- Type coercion errors

## Project Structure Conventions

### Common Layouts
```
src/
  index.ts          # Main entry, public exports
  types.ts          # Shared types
  errors.ts         # Error definitions
  utils/            # Internal utilities
  lib/              # Core implementation
  __tests__/        # Tests (exclude from docs)
```

### Monorepo Patterns
- `packages/*/src/index.ts` - Per-package entry
- Shared types in `@org/types` package
- Look for `workspaces` in package.json

## Type Extraction

### Interface/Type Definitions
```typescript
interface UserOptions {
  /** User's display name */
  name: string
  /** Optional email address */
  email?: string
  /** Age in years @default 0 */
  age: number
}
```

### Generic Types
```typescript
type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E }
```
Document generic parameters and constraints.

## Common Patterns to Recognize

### Factory Functions
```typescript
export function createClient(config: Config): Client
```

### Builder Pattern
```typescript
class QueryBuilder {
  where(condition: string): this
  limit(n: number): this
  execute(): Promise<Result[]>
}
```

### Middleware Pattern
```typescript
type Middleware = (ctx: Context, next: () => Promise<void>) => Promise<void>
```

### Event Emitters
```typescript
class MyEmitter extends EventEmitter {
  on(event: 'data', listener: (data: Data) => void): this
  on(event: 'error', listener: (err: Error) => void): this
}
```
Document all event types and payloads.

## Frontend Indicators

### Asset Locations

| Framework | CSS Location | JS Location |
|-----------|-------------|-------------|
| Next.js | `styles/`, `app/**/*.module.css`, `app/**/globals.css` | `app/`, `pages/`, `components/` |
| React (CRA) | `src/*.css`, `src/components/**/*.css` | `src/`, `src/components/` |
| React (Vite) | `src/styles/`, `src/**/*.css` | `src/` |
| Express + Views | `public/css/`, `public/stylesheets/` | `public/js/`, `public/javascripts/` |

### Build Tool Detection

| File | Tool |
|------|------|
| `next.config.*` | Next.js (built-in webpack/turbopack) |
| `vite.config.*` | Vite |
| `webpack.config.*` | Webpack |
| `postcss.config.*` | PostCSS |
| `tailwind.config.*` | Tailwind CSS |

### CSS Pattern Detection

```typescript
// CSS Modules — detect *.module.css or *.module.scss files
import styles from './Component.module.css'
<div className={styles.container}>

// Tailwind — detect tailwind.config.* + className with utility classes
<div className="flex items-center gap-4 p-2">

// styled-components — detect import from 'styled-components'
import styled from 'styled-components'
const Button = styled.button`color: red;`

// Emotion — detect import from '@emotion/styled' or '@emotion/react'
import { css } from '@emotion/react'

// CSS-in-JS vanilla-extract — detect *.css.ts files
import { style } from '@vanilla-extract/css'
```

### Template References to CSS/JS

- React: `import './styles.css'`, `import styles from './x.module.css'`
- Next.js: `import '@/styles/globals.css'` in layout, CSS Modules per component
- `<Script>` component for external scripts (Next.js)
- `<link>` and `<script>` tags in HTML templates (Express)

### Monorepo Note

When `workspaces` field exists in `package.json`, frontend assets may be in a separate workspace (e.g., `packages/web/`, `apps/frontend/`). Check workspace `package.json` files for framework indicators.

## Cross-Module Patterns

### Import Detection

```typescript
// ES Module cross-module imports
import { UserService } from '../services/user'
import { validateEmail } from '@org/shared-utils'

// CommonJS cross-module requires
const { db } = require('../database')
```

Cross-module calls are identified by imports that cross directory boundaries (e.g., `../other-module/`), or reference a different workspace package (`@org/package`).

### Event Systems

```typescript
// Node.js EventEmitter
class OrderService extends EventEmitter {
  complete(order: Order) {
    this.emit('order:completed', order)
  }
}

// Listening across modules
orderService.on('order:completed', (order) => {
  notificationService.send(order.userId, 'Order complete')
})
```

Document: event name, emitting module, listening module(s), data payload type.

### Framework-Specific Patterns

**NestJS Modules**:
```typescript
@Module({
  imports: [DatabaseModule, AuthModule],
  providers: [UserService],
  exports: [UserService],
})
export class UserModule {}
```
Module `imports` array defines cross-module dependencies. `exports` defines the public API.

**Express Middleware**:
```typescript
// Middleware from auth module used in routes module
app.use('/api/users', authMiddleware, userRouter)
```
Middleware chains crossing module boundaries are integration points.

### Shared Resources

- Database connections: shared `Pool`, `DataSource`, or ORM connection
- Redis/cache clients: shared across modules
- Configuration: `process.env` or config objects imported from shared module
- Logger instances: shared logging infrastructure
