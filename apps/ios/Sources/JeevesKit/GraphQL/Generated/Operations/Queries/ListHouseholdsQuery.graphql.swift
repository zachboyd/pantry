// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension JeevesGraphQL {
  class ListHouseholdsQuery: GraphQLQuery {
    public static let operationName: String = "ListHouseholds"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query ListHouseholds { households { __typename ...HouseholdFields } }"#,
        fragments: [HouseholdFields.self]
      ))

    public init() {}

    public struct Data: JeevesGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.Query }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("households", [Household].self),
      ] }

      public var households: [Household] { __data["households"] }

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

        public var id: String { __data["id"] }
        public var name: String { __data["name"] }
        public var description: String? { __data["description"] }
        public var created_by: String { __data["created_by"] }
        public var created_at: JeevesGraphQL.DateTime { __data["created_at"] }
        public var updated_at: JeevesGraphQL.DateTime { __data["updated_at"] }

        public struct Fragments: FragmentContainer {
          public let __data: DataDict
          public init(_dataDict: DataDict) { __data = _dataDict }

          public var householdFields: HouseholdFields { _toFragment() }
        }
      }
    }
  }

}