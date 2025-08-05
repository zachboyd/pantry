// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension PantryGraphQL {
  public struct GetHouseholdMembersInput: InputObject {
    public private(set) var __data: InputDict

    public init(_ data: InputDict) {
      __data = data
    }

    public init(
      householdId: String
    ) {
      __data = InputDict([
        "householdId": householdId
      ])
    }

    public var householdId: String {
      get { __data["householdId"] }
      set { __data["householdId"] = newValue }
    }
  }

}