import {
  Resolver,
  Mutation,
  Query,
  Args,
  ResolveField,
  Parent,
} from '@nestjs/graphql';
import { Inject } from '@nestjs/common';
import { ObjectType, Field, InputType, ID } from '@nestjs/graphql';
import { CurrentUser } from '../../auth/auth.decorator.js';
import { TOKENS } from '../../../common/tokens.js';
import type { UserRecord } from '../../user/user.types.js';
import {
  GuardedHouseholdService,
  CreateHouseholdInput as CreateHouseholdRequest,
  UpdateHouseholdInput as UpdateHouseholdRequest,
} from './guarded-household.service.js';

// GraphQL Types
@ObjectType()
export class Household {
  @Field(() => ID)
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

  @Field({ nullable: true })
  memberCount?: number;
}

@ObjectType()
export class HouseholdMember {
  @Field(() => ID)
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
export class CreateHouseholdInput implements CreateHouseholdRequest {
  @Field()
  name: string;

  @Field({ nullable: true })
  description?: string;
}

@InputType()
export class GetHouseholdInput {
  @Field()
  id: string;
}

@InputType()
export class AddHouseholdMemberInput {
  @Field()
  householdId: string;

  @Field()
  userId: string;

  @Field()
  role: string;
}

@InputType()
export class RemoveHouseholdMemberInput {
  @Field()
  householdId: string;

  @Field()
  userId: string;
}

@InputType()
export class ChangeHouseholdMemberRoleInput {
  @Field()
  householdId: string;

  @Field()
  userId: string;

  @Field()
  newRole: string;
}

@InputType()
export class GetHouseholdMembersInput {
  @Field()
  householdId: string;
}

@InputType()
export class UpdateHouseholdInput implements UpdateHouseholdRequest {
  @Field()
  id: string;

  @Field({ nullable: true })
  name?: string;

  @Field(() => String, { nullable: true })
  description?: string | null;
}

@Resolver(() => Household)
export class HouseholdResolver {
  constructor(
    @Inject(TOKENS.HOUSEHOLD.GUARDED_SERVICE)
    private readonly guardedHouseholdService: GuardedHouseholdService,
  ) {}

  @Mutation(() => Household)
  async createHousehold(
    @Args('input') input: CreateHouseholdInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<Household> {
    const result = await this.guardedHouseholdService.createHousehold(
      input,
      user,
    );
    return result.household;
  }

  @Query(() => Household)
  async household(
    @Args('input') input: GetHouseholdInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<Household> {
    const result = await this.guardedHouseholdService.getHousehold(
      input.id,
      user,
    );
    return result.household;
  }

  @Query(() => [Household])
  async households(
    @CurrentUser() user: UserRecord | null,
  ): Promise<Household[]> {
    const result = await this.guardedHouseholdService.listHouseholds(user);
    return result.households;
  }

  @Query(() => [HouseholdMember])
  async householdMembers(
    @Args('input') input: GetHouseholdMembersInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<HouseholdMember[]> {
    const result = await this.guardedHouseholdService.getHouseholdMembers(
      input.householdId,
      user,
    );
    return result.members;
  }

  @Mutation(() => HouseholdMember)
  async addHouseholdMember(
    @Args('input') input: AddHouseholdMemberInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<HouseholdMember> {
    return this.guardedHouseholdService.addHouseholdMember(
      input.householdId,
      { userId: input.userId, role: input.role },
      user,
    );
  }

  @Mutation(() => Boolean)
  async removeHouseholdMember(
    @Args('input') input: RemoveHouseholdMemberInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<boolean> {
    await this.guardedHouseholdService.removeHouseholdMember(
      input.householdId,
      { userId: input.userId },
      user,
    );
    return true;
  }

  @Mutation(() => HouseholdMember)
  async changeHouseholdMemberRole(
    @Args('input') input: ChangeHouseholdMemberRoleInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<HouseholdMember> {
    return this.guardedHouseholdService.changeHouseholdMemberRole(
      input.householdId,
      { userId: input.userId, newRole: input.newRole },
      user,
    );
  }

  @Mutation(() => Household)
  async updateHousehold(
    @Args('input') input: UpdateHouseholdInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<Household> {
    const result = await this.guardedHouseholdService.updateHousehold(
      input,
      user,
    );
    return result.household;
  }

  @ResolveField(() => Number)
  async memberCount(
    @Parent() household: Household,
    @CurrentUser() user: UserRecord | null,
  ): Promise<number> {
    return this.guardedHouseholdService.getHouseholdMemberCount(
      household.id,
      user,
    );
  }
}
