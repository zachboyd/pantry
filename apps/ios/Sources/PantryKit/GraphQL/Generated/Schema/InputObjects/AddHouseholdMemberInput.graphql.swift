// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension PantryGraphQL {
  struct AddHouseholdMemberInput: InputObject {
    public private(set) var __data: InputDict

    public init(_ data: InputDict) {
      __data = data
    }

    public init(
      householdId: String,
      userId: String,
      role: String
    ) {
      __data = InputDict([
        "householdId": householdId,
        "userId": userId,
        "role": role
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

    public var role: String {
      get { __data["role"] }
      set { __data["role"] = newValue }
    }
  }

}