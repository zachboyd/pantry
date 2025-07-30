# Pantry API - Development Patterns

## 1. Interface + Implementation Pattern

All services follow a consistent interface-based pattern for better testability and dependency injection.

```typescript
// module.types.ts
export interface ServiceName {
  methodName(): ReturnType;
}

// service.ts
@Injectable()
export class ServiceNameImpl implements ServiceName {
  constructor(@Inject(TOKENS.MODULE.DEPENDENCY) private dep: Dependency) {}

  methodName(): ReturnType {
    // implementation
  }
}

// module.ts
@Module({
  providers: [
    {
      provide: TOKENS.MODULE.SERVICE,
      useClass: ServiceNameImpl,
    }
  ],
  exports: [TOKENS.MODULE.SERVICE],
})
```

## 2. Centralized Token Management

All dependency injection tokens are centralized in `common/tokens.ts` for consistency and avoiding conflicts.

```typescript
// common/tokens.ts
export const TOKENS = {
  DATABASE: {
    CONNECTION: 'DATABASE_CONNECTION',
    SERVICE: 'DATABASE_SERVICE'
  },
  AUTH: {
    SERVICE: 'AUTH_SERVICE',
    FACTORY: 'AUTH_FACTORY'
  },
} as const;

// Usage in services
constructor(@Inject(TOKENS.MODULE.SERVICE) private service: ServiceInterface) {}

// No convenience exports - always use full token paths
```

## 3. Migration Context Pattern

CLI scripts (migrations, seeds, reset) use a minimal NestJS context to access the same services as the main application.

```typescript
// CLI scripts (seed.ts, reset.ts, etc.)
import {
  createMigrationContext,
  closeMigrationContext,
} from './migration-context.js';

async function myCliScript() {
  const app = await createMigrationContext();

  try {
    // Access services via DI - same as main app
    const authFactory = app.get<AuthFactory>(TOKENS.AUTH.FACTORY);
    const db = app.get<Kysely<DB>>(TOKENS.DATABASE.CONNECTION);

    // Use services...
  } finally {
    await closeMigrationContext(app);
  }
}
```

## 4. Database Types Reference

Always consult `src/generated/database.ts` when working with database operations. This file contains the authoritative type definitions including which fields are `Generated<T>` (handled automatically by the database) vs. user-provided fields.

**Always check for existing types first** before using `any`. Kysely provides comprehensive utility types:

- `Insertable<T>` - For insert operations (excludes Generated fields)
- `Updateable<T>` - For update operations (all fields optional)
- `Selectable<T>` - For select results (includes Generated fields)

**Avoid `any` at all costs.** Use proper types, `unknown`, or create specific interfaces. Example:

```typescript
// ❌ Bad
const insertData: any = { household_id: '123', user_id: '456' };

// ✅ Good
const insertData: Insertable<TypingIndicator> = {
  household_id: '123',
  user_id: '456',
};
```
