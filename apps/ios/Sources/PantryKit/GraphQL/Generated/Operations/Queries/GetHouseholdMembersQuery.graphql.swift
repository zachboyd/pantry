// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension PantryGraphQL {
  public class GetHouseholdMembersQuery: GraphQLQuery {
    public static let operationName: String = "GetHouseholdMembers"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query GetHouseholdMembers($input: GetHouseholdMembersInput!) { householdMembers(input: $input) { __typename id household_id user_id role joined_at } }"#
      ))

    public var input: GetHouseholdMembersInput

    public init(input: GetHouseholdMembersInput) {
      self.input = input
    }

    public var __variables: Variables? { ["input": input] }

    public struct Data: PantryGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { PantryGraphQL.Objects.Query }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("householdMembers", [HouseholdMember].self, arguments: ["input": .variable("input")]),
      ] }

      public var householdMembers: [HouseholdMember] { __data["householdMembers"] }

      /// HouseholdMember
      ///
      /// Parent Type: `HouseholdMember`
      public struct HouseholdMember: PantryGraphQL.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { PantryGraphQL.Objects.HouseholdMember }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", String.self),
          .field("household_id", String.self),
          .field("user_id", String.self),
          .field("role", String.self),
          .field("joined_at", PantryGraphQL.DateTime.self),
        ] }

        public var id: String { __data["id"] }
        public var household_id: String { __data["household_id"] }
        public var user_id: String { __data["user_id"] }
        public var role: String { __data["role"] }
        public var joined_at: PantryGraphQL.DateTime { __data["joined_at"] }
      }
    }
  }

}