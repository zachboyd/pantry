import { Resolver, Mutation, Query, Args } from '@nestjs/graphql';
import { Inject } from '@nestjs/common';
import { ObjectType, Field, InputType } from '@nestjs/graphql';
import { User } from '../../auth/auth.decorator.js';
import { TOKENS } from '../../../common/tokens.js';
import type { UserRecord } from '../../user/user.types.js';
import type { HouseholdApi, CreateHouseholdInput } from './household.api.js';

// GraphQL Types
@ObjectType()
export class Household {
  @Field()
  id: string;

  @Field()
  name: string;

  @Field({ nullable: true })
  description?: string;

  @Field()
  created_by: string;

  @Field()
  created_at: Date;

  @Field()
  updated_at: Date;
}

@InputType()
export class CreateHouseholdInputGql implements CreateHouseholdInput {
  @Field()
  name: string;

  @Field({ nullable: true })
  description?: string;
}

@Resolver(() => Household)
export class HouseholdResolver {
  constructor(
    @Inject(TOKENS.HOUSEHOLD.API)
    private readonly householdApi: HouseholdApi,
  ) {}

  @Mutation(() => Household)
  async createHousehold(
    @Args('input') input: CreateHouseholdInputGql,
    @User() user: UserRecord | null,
  ): Promise<Household> {
    const result = await this.householdApi.createHousehold(input, user);
    return result.household;
  }

  @Query(() => Household)
  async household(
    @Args('id') id: string,
    @User() user: UserRecord | null,
  ): Promise<Household> {
    const result = await this.householdApi.getHousehold(id, user);
    return result.household;
  }
}