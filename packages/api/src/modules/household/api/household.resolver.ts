import { Resolver, Mutation, Query, Args } from '@nestjs/graphql';
import { Inject } from '@nestjs/common';
import { ObjectType, Field, InputType } from '@nestjs/graphql';
import { User } from '../../auth/auth.decorator.js';
import { TOKENS } from '../../../common/tokens.js';
import type { UserRecord } from '../../user/user.types.js';
import {
  GuardedHouseholdService,
  CreateHouseholdInput,
  AddHouseholdMemberInput,
  ChangeHouseholdMemberRoleInput,
} from './guarded-household.service.js';

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

@ObjectType()
export class HouseholdMember {
  @Field()
  id: string;

  @Field()
  household_id: string;

  @Field()
  user_id: string;

  @Field()
  role: string;

  @Field()
  joined_at: Date;
}

@InputType()
export class CreateHouseholdInputGql implements CreateHouseholdInput {
  @Field()
  name: string;

  @Field({ nullable: true })
  description?: string;
}

@InputType()
export class AddHouseholdMemberInputGql implements AddHouseholdMemberInput {
  @Field()
  userId: string;

  @Field()
  role: string;
}

@InputType()
export class ChangeHouseholdMemberRoleInputGql
  implements ChangeHouseholdMemberRoleInput
{
  @Field()
  userId: string;

  @Field()
  newRole: string;
}

@Resolver(() => Household)
export class HouseholdResolver {
  constructor(
    @Inject(TOKENS.HOUSEHOLD.GUARDED_SERVICE)
    private readonly guardedHouseholdService: GuardedHouseholdService,
  ) {}

  @Mutation(() => Household)
  async createHousehold(
    @Args('input') input: CreateHouseholdInputGql,
    @User() user: UserRecord | null,
  ): Promise<Household> {
    const result = await this.guardedHouseholdService.createHousehold(
      input,
      user,
    );
    return result.household;
  }

  @Query(() => Household)
  async household(
    @Args('id') id: string,
    @User() user: UserRecord | null,
  ): Promise<Household> {
    const result = await this.guardedHouseholdService.getHousehold(id, user);
    return result.household;
  }

  @Mutation(() => HouseholdMember)
  async addHouseholdMember(
    @Args('householdId') householdId: string,
    @Args('input') input: AddHouseholdMemberInputGql,
    @User() user: UserRecord | null,
  ): Promise<HouseholdMember> {
    return this.guardedHouseholdService.addHouseholdMember(
      householdId,
      input,
      user,
    );
  }

  @Mutation(() => Boolean)
  async removeHouseholdMember(
    @Args('householdId') householdId: string,
    @Args('userId') userId: string,
    @User() user: UserRecord | null,
  ): Promise<boolean> {
    await this.guardedHouseholdService.removeHouseholdMember(
      householdId,
      { userId },
      user,
    );
    return true;
  }

  @Mutation(() => HouseholdMember)
  async changeHouseholdMemberRole(
    @Args('householdId') householdId: string,
    @Args('input') input: ChangeHouseholdMemberRoleInputGql,
    @User() user: UserRecord | null,
  ): Promise<HouseholdMember> {
    return this.guardedHouseholdService.changeHouseholdMemberRole(
      householdId,
      input,
      user,
    );
  }
}
