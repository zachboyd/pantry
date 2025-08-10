// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension JeevesGraphQL {
  class GetHouseholdQuery: GraphQLQuery {
    public static let operationName: String = "GetHousehold"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query GetHousehold($input: GetHouseholdInput!) { household(input: $input) { __typename ...HouseholdFields } }"#,
        fragments: [HouseholdFields.self]
      ))

    public var input: GetHouseholdInput

    public init(input: GetHouseholdInput) {
      self.input = input
    }

    public var __variables: Variables? { ["input": input] }

    public struct Data: JeevesGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.Query }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("household", Household.self, arguments: ["input": .variable("input")]),
      ] }

      public var household: Household { __data["household"] }

      /// Household
      ///
      /// Parent Type: `Household`
      public struct Household: JeevesGraphQL.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.Household }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .fragment(HouseholdFields.self),
        ] }

        public var id: JeevesGraphQL.ID { __data["id"] }
        public var name: String { __data["name"] }
        public var description: String? { __data["description"] }
        public var created_by: String { __data["created_by"] }
        public var created_at: JeevesGraphQL.DateTime { __data["created_at"] }
        public var updated_at: JeevesGraphQL.DateTime { __data["updated_at"] }
        public var memberCount: Double? { __data["memberCount"] }

        public struct Fragments: FragmentContainer {
          public let __data: DataDict
          public init(_dataDict: DataDict) { __data = _dataDict }

          public var householdFields: HouseholdFields { _toFragment() }
        }
      }
    }
  }

}