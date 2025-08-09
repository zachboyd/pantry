import { Module, Logger } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { join } from 'path';
import { SafeDateTimeScalar } from './safe-datetime.scalar.js';

@Module({
  providers: [SafeDateTimeScalar],
  imports: [
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: join(process.cwd(), 'src/generated/schema.gql'),
      introspection: true,
      path: '/graphql',
      context: (context) => {
        // HTTP requests
        if ('req' in context && context.req) {
          return { req: context.req, res: context.res };
        }

        // WebSocket connections (graphql-ws)
        // Build a minimal request-like object so guards/decorators can read cookies/headers
        const headers: Record<string, unknown> = {};

        // Prefer headers passed explicitly via connectionParams
        if (
          context.connectionParams &&
          typeof context.connectionParams === 'object'
        ) {
          const cp = context.connectionParams as Record<string, unknown>;
          if (cp.headers && typeof cp.headers === 'object') {
            Object.assign(headers, cp.headers as Record<string, unknown>);
          }
          if (cp.cookie && typeof cp.cookie === 'string') {
            headers['cookie'] = cp.cookie;
          }
          if (cp.authorization && typeof cp.authorization === 'string') {
            headers['authorization'] = cp.authorization;
          }
        }

        // Fallback to upgrade request headers if available
        const wsReq = (context as any)?.extra?.request;
        if (wsReq?.headers && typeof wsReq.headers === 'object') {
          Object.assign(headers, wsReq.headers);
        }

        return { req: { headers } } as unknown;
      },
      subscriptions: {
        'graphql-ws': true,
      },
      formatError: (error) => {
        // Log errors in development
        if (process.env.NODE_ENV === 'development') {
          const logger = new Logger('GraphQL');
          logger.error(error.message);
        }
        return {
          message: error.message,
          code: error.extensions?.code,
          path: error.path,
        };
      },
    }),
  ],
})
export class AppGraphQLModule {}
