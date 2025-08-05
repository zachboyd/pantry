// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension PantryGraphQL {
  public struct RemoveHouseholdMemberInput: InputObject {
    public private(set) var __data: InputDict

    public init(_ data: InputDict) {
      __data = data
    }

    public init(
      householdId: String,
      userId: String
    ) {
      __data = InputDict([
        "householdId": householdId,
        "userId": userId
      ])
    }

    public var householdId: String {
      get { __data["householdId"] }
      set { __data["householdId"] = newValue }
    }

    public var userId: String {
      get { __data["userId"] }
      set { __data["userId"] = newValue }
    }
  }

}