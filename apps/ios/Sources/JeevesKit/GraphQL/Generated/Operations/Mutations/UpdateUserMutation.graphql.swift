// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension JeevesGraphQL {
  class UpdateUserMutation: GraphQLMutation {
    public static let operationName: String = "UpdateUser"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UpdateUser($input: UpdateUserInput!) { updateUser(input: $input) { __typename ...UserFields } }"#,
        fragments: [UserFields.self]
      ))

    public var input: UpdateUserInput

    public init(input: UpdateUserInput) {
      self.input = input
    }

    public var __variables: Variables? { ["input": input] }

    public struct Data: JeevesGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.Mutation }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("updateUser", UpdateUser.self, arguments: ["input": .variable("input")]),
      ] }

      public var updateUser: UpdateUser { __data["updateUser"] }

      /// UpdateUser
      ///
      /// Parent Type: `User`
      public struct UpdateUser: JeevesGraphQL.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.User }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .fragment(UserFields.self),
        ] }

        public var id: JeevesGraphQL.ID { __data["id"] }
        public var auth_user_id: String? { __data["auth_user_id"] }
        public var email: String? { __data["email"] }
        public var first_name: String { __data["first_name"] }
        public var last_name: String { __data["last_name"] }
        public var display_name: String? { __data["display_name"] }
        public var avatar_url: String? { __data["avatar_url"] }
        public var phone: String? { __data["phone"] }
        public var birth_date: JeevesGraphQL.DateTime? { __data["birth_date"] }
        public var managed_by: String? { __data["managed_by"] }
        public var relationship_to_manager: String? { __data["relationship_to_manager"] }
        public var primary_household_id: String? { __data["primary_household_id"] }
        public var is_ai: Bool { __data["is_ai"] }
        public var created_at: JeevesGraphQL.DateTime { __data["created_at"] }
        public var updated_at: JeevesGraphQL.DateTime { __data["updated_at"] }

        public struct Fragments: FragmentContainer {
          public let __data: DataDict
          public init(_dataDict: DataDict) { __data = _dataDict }

          public var userFields: UserFields { _toFragment() }
        }
      }
    }
  }

}