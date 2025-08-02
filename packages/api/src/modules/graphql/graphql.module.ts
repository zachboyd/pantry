import { Module, Logger } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { join } from 'path';

@Module({
  imports: [
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: join(process.cwd(), 'src/generated/schema.gql'),
      playground: process.env.NODE_ENV === 'development',
      introspection: true,
      path: '/graphql',
      context: ({ req, res }) => ({ req, res }),
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
