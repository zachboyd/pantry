// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension PantryGraphQL {
  public struct GetHouseholdInput: InputObject {
    public private(set) var __data: InputDict

    public init(_ data: InputDict) {
      __data = data
    }

    public init(
      id: String
    ) {
      __data = InputDict([
        "id": id
      ])
    }

    public var id: String {
      get { __data["id"] }
      set { __data["id"] = newValue }
    }
  }

}