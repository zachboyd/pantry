import { Resolver, Query, Mutation, Subscription, Args } from '@nestjs/graphql';
import { Inject } from '@nestjs/common';
import { ObjectType, Field, InputType, ID } from '@nestjs/graphql';
import { GraphQLJSON } from 'graphql-type-json';
import { CurrentUser } from '../../auth/auth.decorator.js';
import { TOKENS } from '../../../common/tokens.js';
import type {
  UserRecord,
  UserPreferences,
  UserPermissions,
} from '../user.types.js';
import type { PubSubService } from '../../pubsub/pubsub.types.js';
import { GuardedUserService } from './guarded-user.service.js';

// GraphQL Types

@ObjectType()
export class User {
  @Field(() => ID)
  id: string;

  @Field({ nullable: true })
  auth_user_id?: string;

  @Field({ nullable: true })
  email?: string;

  @Field()
  first_name: string;

  @Field()
  last_name: string;

  @Field({ nullable: true })
  display_name?: string;

  @Field({ nullable: true })
  avatar_url?: string;

  @Field({ nullable: true })
  phone?: string;

  @Field({ nullable: true })
  birth_date?: Date;

  @Field({ nullable: true })
  managed_by?: string;

  @Field({ nullable: true })
  relationship_to_manager?: string;

  @Field({ nullable: true })
  primary_household_id?: string;

  @Field(() => GraphQLJSON, { nullable: true })
  permissions?: UserPermissions;

  @Field(() => GraphQLJSON, { nullable: true })
  preferences?: UserPreferences;

  @Field()
  is_ai: boolean;

  @Field()
  created_at: Date;

  @Field()
  updated_at: Date;
}

@InputType()
export class GetUserInput {
  @Field()
  id: string;
}

@InputType()
export class UpdateUserInput {
  @Field()
  id: string;

  @Field({ nullable: true })
  first_name?: string;

  @Field({ nullable: true })
  last_name?: string;

  @Field({ nullable: true })
  display_name?: string;

  @Field({ nullable: true })
  avatar_url?: string;

  @Field({ nullable: true })
  phone?: string;

  @Field({ nullable: true })
  birth_date?: Date;

  @Field({ nullable: true })
  email?: string;

  @Field({ nullable: true })
  primary_household_id?: string;

  @Field(() => GraphQLJSON, { nullable: true })
  preferences?: UserPreferences;
}

@Resolver(() => User)
export class UserResolver {
  constructor(
    @Inject(TOKENS.USER.GUARDED_SERVICE)
    private readonly guardedUserService: GuardedUserService,
    @Inject(TOKENS.PUBSUB.SERVICE)
    private readonly pubsubService: PubSubService,
  ) {}

  private transformUserForGraphQL(user: UserRecord): User {
    return {
      ...user,
      permissions: user.permissions as UserPermissions,
      preferences: user.preferences as UserPreferences,
    };
  }

  @Query(() => User)
  async user(
    @Args('input') input: GetUserInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<User> {
    const result = await this.guardedUserService.getUser(input.id, user);
    return this.transformUserForGraphQL(result.user);
  }

  @Query(() => User)
  async currentUser(@CurrentUser() user: UserRecord | null): Promise<User> {
    const result = await this.guardedUserService.getCurrentUser(user);
    return this.transformUserForGraphQL(result.user);
  }

  @Mutation(() => User)
  async updateUser(
    @Args('input') input: UpdateUserInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<User> {
    const result = await this.guardedUserService.updateUser(input, user);
    return this.transformUserForGraphQL(result.user);
  }

  @Subscription(() => User)
  async userUpdated(@CurrentUser() user: UserRecord | null) {
    if (!user) {
      throw new Error('You must be authenticated to subscribe to user updates');
    }

    return this.pubsubService.getUserUpdatedIterator(user.id);
  }
}
