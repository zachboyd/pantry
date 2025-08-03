# Testing Guide

## Overview

The API uses a multi-layered testing approach with both unit tests and integration tests.

## Test Types

### Unit Tests
- Test individual components in isolation
- Use mocks for dependencies
- Fast execution (milliseconds)
- Run with: `npm run test:unit`

### Integration Tests  
- Test full request-to-response flows
- Use real database and services
- Slower execution (seconds)
- Run with: `npm run test:integration`

## Docker-Based Integration Testing

Integration tests now use Docker Compose to spin up fresh, isolated databases for each test run.

### Benefits
- ✅ **Clean State**: Fresh database for every test run
- ✅ **No Dependencies**: No need for existing database setup
- ✅ **Isolation**: Tests don't interfere with development data
- ✅ **Speed**: Uses tmpfs (in-memory) for fast database operations
- ✅ **CI/CD Ready**: Self-contained for automated environments

### How it Works

1. **Global Setup**: `vitest` runs `src/test/setup/global-setup.ts` once before all tests
2. **Docker Start**: Spins up PostgreSQL and Redis containers using `docker-compose.test.yml`
3. **Tests Run**: Integration tests connect to Docker database on port 5433
4. **Global Teardown**: `src/test/setup/global-teardown.ts` cleans up containers after all tests

### Test Commands

```bash
# Run all tests (unit + integration)
npm test

# Run only unit tests (fast)
npm run test:unit

# Run only integration tests (with Docker)
npm run test:integration

# Run integration tests in watch mode
npm run test:integration:watch

# Run all tests with Docker setup
npm run test:docker
```

### Requirements

- Docker Desktop or Docker Engine with Docker Compose
- Ports 5433 and 6380 available (for test database and Redis)

### Configuration Files

- `docker-compose.test.yml` - Test-specific Docker services
- `src/test/setup/global-setup.ts` - Starts Docker services
- `src/test/setup/global-teardown.ts` - Stops Docker services
- `src/test/utils/docker-test-manager.ts` - Docker lifecycle management
- `vitest.config.ts` - Global setup/teardown configuration

### Database Performance Optimizations

The test database uses several optimizations for speed:
- `tmpfs` mount (in-memory database)
- Optimized PostgreSQL settings
- Fast health checks (2s intervals)
- Connection pooling

### Example Integration Test

```typescript
describe('User Resolver Integration Tests', () => {
  // Fresh database for each test suite
  // No manual setup required - Docker handles everything
  
  it('should create and retrieve user', async () => {
    const { userId, sessionToken } = await IntegrationTestModuleFactory.signUpTestUser(testRequest, {
      first_name: 'Test',
      last_name: 'User',
    }, db);

    const response = await GraphQLTestUtils.executeAuthenticatedQuery(
      testRequest,
      GraphQLTestUtils.QUERIES.GET_USER,
      sessionToken,
      GraphQLTestUtils.createGetUserInput(userId),
    );

    expect(response.status).toBe(200);
    expect(response.data.user.first_name).toBe('Test');
  });
});
```

## Best Practices

1. **Use Docker for Integration Tests**: Ensures clean, isolated test environment
2. **Keep Unit Tests Fast**: Mock external dependencies
3. **Test Both Layers**: Unit tests catch component bugs, integration tests catch flow bugs
4. **Clean Test Data**: Each integration test gets a fresh database
5. **Test Security**: Verify permission checks and authentication flows