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

### Error Hierarchy Pattern
```typescript
class AppError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code: string = 'INTERNAL_ERROR',
    public isOperational: boolean = true,
  ) {
    super(message)
    this.name = this.constructor.name
    Error.captureStackTrace(this, this.constructor)
  }
}

class ValidationError extends AppError {
  constructor(message: string, public fields: Record<string, string>) {
    super(message, 400, 'VALIDATION_ERROR')
  }
}

class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource} with id ${id} not found`, 404, 'NOT_FOUND')
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED')
  }
}
```

### Express Error Middleware
```typescript
// Error-handling middleware (4 parameters)
const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ error: err.code, message: err.message })
  } else {
    res.status(500).json({ error: 'INTERNAL_ERROR' })
  }
}

// Must be registered last
app.use(errorHandler)
```

### Async Error Handling
```typescript
// express-async-errors — auto-catches rejected promises in route handlers
import 'express-async-errors'

// Manual wrapper pattern (when not using express-async-errors)
const asyncHandler = (fn: RequestHandler): RequestHandler =>
  (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next)

app.get('/users', asyncHandler(async (req, res) => {
  const users = await userService.findAll()
  res.json(users)
}))
```

Detection: scan for `express-async-errors` in dependencies or `asyncHandler`/`catchAsync` wrapper functions.

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

## Framework Detection

### Express / Fastify / Koa

**Detection indicators**:
- `express` in `package.json` dependencies
- `fastify` or `@fastify/*` in dependencies
- `koa` or `@koa/*` in dependencies
- `app.listen()`, `app.use()`, `app.get()` patterns in entry files

**Middleware chain patterns**:
```typescript
// Express middleware signature
type ExpressMiddleware = (req: Request, res: Response, next: NextFunction) => void

// Auth middleware
const authenticate: RequestHandler = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1]
  if (!token) return next(new UnauthorizedError())
  req.user = verifyToken(token)
  next()
}

// Validation middleware
const validate = (schema: ZodSchema): RequestHandler => (req, res, next) => {
  const result = schema.safeParse(req.body)
  if (!result.success) return next(new ValidationError('Invalid input', result.error.flatten()))
  req.body = result.data
  next()
}

// Router-level middleware chain
router.post('/users',
  authenticate,
  authorize('admin'),
  validate(createUserSchema),
  userController.create
)
```

```typescript
// Fastify hook-based middleware
fastify.addHook('onRequest', async (request, reply) => {
  // Auth check
})

// Fastify plugin pattern
const userPlugin: FastifyPluginAsync = async (fastify, opts) => {
  fastify.get('/users', handler)
}
fastify.register(userPlugin, { prefix: '/api' })
```

```typescript
// Koa middleware (context-based)
const auth: Middleware = async (ctx, next) => {
  ctx.state.user = await getUser(ctx.headers.authorization)
  await next()
}
```

### Next.js

**Detection indicators**:
- `next` in `package.json` dependencies
- `next.config.js` or `next.config.mjs` or `next.config.ts`
- `app/` directory with `layout.tsx` and `page.tsx` (App Router)
- `pages/` directory with `_app.tsx` and `_document.tsx` (Pages Router)

**App Router patterns** (Next.js 13+):
```typescript
// app/layout.tsx — root layout
export default function RootLayout({ children }: { children: React.ReactNode }) {}

// app/page.tsx — page component (server component by default)
export default async function Page() {}

// app/api/users/route.ts — route handler
export async function GET(request: Request) {}
export async function POST(request: Request) {}

// 'use client' directive — client component
'use client'
export default function InteractiveForm() {}

// 'use server' directive — server action
'use server'
export async function submitForm(formData: FormData) {}

// app/loading.tsx, app/error.tsx, app/not-found.tsx — special files
```

**Pages Router patterns**:
```typescript
// pages/index.tsx — page component
export default function Home() {}

// pages/api/users.ts — API route
export default function handler(req: NextApiRequest, res: NextApiResponse) {}

// getServerSideProps / getStaticProps
export const getServerSideProps: GetServerSideProps = async (context) => {}
export const getStaticProps: GetStaticProps = async () => {}
```

**Router detection**: presence of `app/layout.tsx` indicates App Router. Presence of `pages/_app.tsx` without `app/` indicates Pages Router. Both can coexist.

### NestJS

**Detection indicators**:
- `@nestjs/core`, `@nestjs/common` in dependencies
- `nest-cli.json` or `.nestcli.json`
- `*.module.ts`, `*.controller.ts`, `*.service.ts` file naming convention
- Decorator usage: `@Module`, `@Controller`, `@Injectable`, `@Get`, `@Post`

**Module/Controller/Service structure**:
```typescript
// user.module.ts
@Module({
  imports: [DatabaseModule],
  controllers: [UserController],
  providers: [UserService, UserRepository],
  exports: [UserService],
})
export class UserModule {}

// user.controller.ts
@Controller('users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get()
  findAll(): Promise<User[]> { return this.userService.findAll() }

  @Get(':id')
  findOne(@Param('id') id: string): Promise<User> {}

  @Post()
  @UsePipes(new ValidationPipe())
  create(@Body() dto: CreateUserDto): Promise<User> {}
}

// user.service.ts
@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
  ) {}
}
```

**Guards, Pipes, Interceptors**:
```typescript
// Auth guard
@Injectable()
export class AuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean | Promise<boolean> {}
}

// Validation pipe
@Injectable()
export class ValidationPipe implements PipeTransform {
  transform(value: any, metadata: ArgumentMetadata) {}
}
```

Module `imports` array defines cross-module dependencies. `exports` defines the module's public API.

## ORM / Database Patterns

### Detection

| Package | ORM | Detection |
|---------|-----|-----------|
| `prisma`, `@prisma/client` | Prisma | `prisma/schema.prisma` file |
| `typeorm` | TypeORM | `ormconfig.*` or `DataSource` config, `*.entity.ts` files |
| `sequelize` | Sequelize | `.sequelizerc`, `models/index.js` |
| `drizzle-orm` | Drizzle | `drizzle.config.ts`, `*.schema.ts` files |
| `knex` | Knex (query builder) | `knexfile.*`, `migrations/` directory |
| `mongoose` | Mongoose (MongoDB) | `*.model.ts` with `Schema` definitions |

### Prisma Patterns
```typescript
// prisma/schema.prisma — model definitions
model User {
  id    String @id @default(cuid())
  email String @unique
  name  String
  posts Post[]
}

// Service usage
const user = await prisma.user.findUnique({ where: { email } })
const users = await prisma.user.findMany({ include: { posts: true } })
```

### TypeORM Patterns
```typescript
// Entity definition
@Entity()
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string

  @Column({ unique: true })
  email: string

  @OneToMany(() => Post, (post) => post.author)
  posts: Post[]
}

// Repository pattern
const userRepo = dataSource.getRepository(User)
const user = await userRepo.findOneBy({ email })
```

### Drizzle Patterns
```typescript
// Schema definition
export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: varchar('name', { length: 255 }),
})

// Query usage
const result = await db.select().from(users).where(eq(users.email, email))
```

### Repository / Service Pattern
```typescript
// Common abstraction over any ORM
interface UserRepository {
  findById(id: string): Promise<User | null>
  findByEmail(email: string): Promise<User | null>
  create(data: CreateUserDto): Promise<User>
  update(id: string, data: UpdateUserDto): Promise<User>
  delete(id: string): Promise<void>
}
```

Detection: look for `Repository`, `Repo`, or `DAO` suffixed classes/interfaces. Service classes that inject repositories indicate the service-repository pattern.

## Testing Patterns

### Test Framework Detection

| Package | Framework | Config File |
|---------|-----------|-------------|
| `jest` | Jest | `jest.config.*`, `"jest"` in `package.json` |
| `vitest` | Vitest | `vitest.config.*`, `vite.config.*` with test config |
| `mocha` | Mocha | `.mocharc.*`, `"mocha"` in `package.json` |
| `@playwright/test` | Playwright | `playwright.config.*` |
| `cypress` | Cypress | `cypress.config.*`, `cypress/` directory |
| `supertest` | Supertest (HTTP) | Used alongside other frameworks |

### Test File Organization

```
# Co-located tests
src/
  services/
    user.service.ts
    user.service.test.ts        # or .spec.ts

# Dedicated test directory
src/
  services/
    user.service.ts
__tests__/                      # or test/, tests/
  services/
    user.service.test.ts

# E2E tests
e2e/                            # or tests/e2e/
  user.e2e.test.ts
```

Detection patterns:
- `*.test.ts`, `*.spec.ts`, `*.test.js`, `*.spec.js` — unit/integration tests
- `__tests__/` directories — Jest convention
- `e2e/`, `cypress/`, `tests/e2e/` — end-to-end tests
- `*.e2e-spec.ts` — NestJS e2e convention
- `__mocks__/` — Jest manual mocks

### Common Test Patterns

```typescript
// Jest / Vitest
describe('UserService', () => {
  let service: UserService

  beforeEach(() => { service = new UserService(mockRepo) })

  it('should create a user', async () => {
    const user = await service.create({ name: 'Test', email: 'test@example.com' })
    expect(user).toBeDefined()
    expect(user.email).toBe('test@example.com')
  })
})

// Supertest for HTTP endpoints
import request from 'supertest'
it('GET /users returns 200', async () => {
  const res = await request(app).get('/users')
  expect(res.status).toBe(200)
})
```

Exclude all test files from documentation output. Test files are detection-only (used to identify what is tested, not documented as API).

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

### Barrel Files (Index Re-exports)

```typescript
// src/services/index.ts — barrel file
export { UserService } from './user.service'
export { OrderService } from './order.service'
export { PaymentService } from './payment.service'
```

Detection: `index.ts` or `index.js` files that consist primarily of `export { ... } from` statements. Barrel files define the public API of a directory/module.

### Module Organization Patterns

**By feature (vertical slices)**:
```
src/
  users/
    user.controller.ts
    user.service.ts
    user.repository.ts
    user.dto.ts
    user.module.ts
  orders/
    order.controller.ts
    order.service.ts
    order.repository.ts
```

**By layer (horizontal slices)**:
```
src/
  controllers/
    user.controller.ts
    order.controller.ts
  services/
    user.service.ts
    order.service.ts
  repositories/
    user.repository.ts
```

Detection: if directories are named after domain concepts (users, orders, payments), the project uses feature-based organization. If directories are named after architectural layers (controllers, services, models), it uses layer-based organization.

### Dependency Injection (Non-NestJS)

```typescript
// Manual DI via constructor
class UserController {
  constructor(
    private userService: UserService,
    private logger: Logger,
  ) {}
}

// DI containers (tsyringe, inversify, awilix)
@injectable()
class UserService {
  constructor(@inject('UserRepository') private repo: UserRepository) {}
}
```

Detection: `tsyringe`, `inversify`, `awilix`, or `typedi` in dependencies. Look for `@injectable()`, `@inject()`, `container.register()` patterns.

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
