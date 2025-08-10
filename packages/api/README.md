# Jeeves API

## Technology Stack

- **Framework**: NestJS with Express
- **Database**: PostgreSQL with Kysely query builder
- **Authentication**: Better Auth with multiple providers
- **Documentation**: Swagger/OpenAPI auto-generated
- **Type Safety**: TypeScript throughout
- **Node.js**: 22+ required

## Quick Start

1. **Install dependencies**

   ```bash
   npm install
   ```

2. **Configure environment**

   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Start database**

   ```bash
   npm run docker:dev
   ```

4. **Run migrations**

   ```bash
   npm run db:migrate
   ```

5. **Start development server**

   ```bash
   npm run start:dev
   ```

6. **Visit API documentation**
   - Swagger UI: http://localhost:3000/api/docs
   - Generated OpenAPI spec: `src/generated/openapi.yaml`

## Development Commands

```bash
# Server
npm run start:dev          # Development server with hot reload
npm run build             # Build for production
npm run start:prod        # Start production server

# Database
npm run db:migrate        # Run pending migrations
npm run db:migrate:create # Create new migration
npm run db:migrate:down   # Rollback last migration
npm run db:reset          # Reset database (destructive!)
npm run db:seed           # Seed with test data
npm run db:generate       # Generate Kysely types from schema

# Testing & Quality
npm run test              # Run tests
npm run lint              # Run ESLint
npm run format            # Format code with Prettier
```

## Environment Variables

Required environment variables (see `.env.example`):

## API Documentation

- **Interactive Docs**: Visit `/api/docs` when server is running
- **OpenAPI Spec**: Auto-generated at `src/generated/openapi.yaml`
- **Authentication**: Session cookies

## Database

### Schema Management

- Migrations in `src/database/migrations/`
- Use `npm run db:migrate:create <name>` to create new migrations
- Database types auto-generated with `npm run db:generate`
