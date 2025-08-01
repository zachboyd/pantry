import type { HouseholdRecord, HouseholdMemberRecord } from '../household.types.js';
import type { UserRecord } from '../../user/user.types.js';

export class HouseholdCreatedEvent {
  constructor(
    public readonly household: HouseholdRecord,
    public readonly creator: string,
    public readonly aiUser: UserRecord,
  ) {}
}

export class HouseholdMemberAddedEvent {
  constructor(
    public readonly householdId: string,
    public readonly member: HouseholdMemberRecord,
    public readonly addedBy: string,
  ) {}
}

export class HouseholdMemberRemovedEvent {
  constructor(
    public readonly householdId: string,
    public readonly removedMember: HouseholdMemberRecord,
    public readonly removedBy: string,
  ) {}
}

export class HouseholdMemberRoleChangedEvent {
  constructor(
    public readonly householdId: string,
    public readonly member: HouseholdMemberRecord,
    public readonly previousRole: string,
    public readonly changedBy: string,
  ) {}
}