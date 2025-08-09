// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension PantryGraphQL {
  struct HouseholdFields: PantryGraphQL.SelectionSet, Fragment {
    public static var fragmentDefinition: StaticString {
      #"fragment HouseholdFields on Household { __typename id name description created_by created_at updated_at }"#
    }

    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { PantryGraphQL.Objects.Household }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("__typename", String.self),
      .field("id", String.self),
      .field("name", String.self),
      .field("description", String?.self),
      .field("created_by", String.self),
      .field("created_at", PantryGraphQL.DateTime.self),
      .field("updated_at", PantryGraphQL.DateTime.self),
    ] }

    public var id: String { __data["id"] }
    public var name: String { __data["name"] }
    public var description: String? { __data["description"] }
    public var created_by: String { __data["created_by"] }
    public var created_at: PantryGraphQL.DateTime { __data["created_at"] }
    public var updated_at: PantryGraphQL.DateTime { __data["updated_at"] }
  }

}