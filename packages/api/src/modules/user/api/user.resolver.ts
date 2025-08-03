import { Resolver, Query, Args } from '@nestjs/graphql';
import { Inject } from '@nestjs/common';
import { ObjectType, Field, InputType } from '@nestjs/graphql';
import { CurrentUser } from '../../auth/auth.decorator.js';
import { TOKENS } from '../../../common/tokens.js';
import type { UserRecord } from '../user.types.js';
import { GuardedUserService } from './guarded-user.service.js';

// GraphQL Types
@ObjectType()
export class User {
  @Field()
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

@Resolver(() => User)
export class UserResolver {
  constructor(
    @Inject(TOKENS.USER.GUARDED_SERVICE)
    private readonly guardedUserService: GuardedUserService,
  ) {}

  @Query(() => User)
  async user(
    @Args('input') input: GetUserInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<User> {
    const result = await this.guardedUserService.getUser(input.id, user);
    return result.user;
  }

  @Query(() => User)
  async currentUser(@CurrentUser() user: UserRecord | null): Promise<User> {
    const result = await this.guardedUserService.getCurrentUser(user);
    return result.user;
  }
}