export class RecomputeUserPermissionsEvent {
  constructor(
    public readonly userId: string,
    public readonly reason?: string,
  ) {}
}