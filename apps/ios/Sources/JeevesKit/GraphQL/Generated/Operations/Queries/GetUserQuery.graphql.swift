// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension JeevesGraphQL {
    class GetUserQuery: GraphQLQuery {
        public static let operationName: String = "GetUser"
        public static let operationDocument: ApolloAPI.OperationDocument = .init(
            definition: .init(
                #"query GetUser($input: GetUserInput!) { user(input: $input) { __typename ...UserFields } }"#,
                fragments: [UserFields.self],
            ))

        public var input: GetUserInput

        public init(input: GetUserInput) {
            self.input = input
        }

        public var __variables: Variables? { ["input": input] }

        public struct Data: JeevesGraphQL.SelectionSet {
            public let __data: DataDict
            public init(_dataDict: DataDict) { __data = _dataDict }

            public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.Query }
            public static var __selections: [ApolloAPI.Selection] { [
                .field("user", User.self, arguments: ["input": .variable("input")]),
            ] }

            public var user: User { __data["user"] }

            /// User
            ///
            /// Parent Type: `User`
            public struct User: JeevesGraphQL.SelectionSet {
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
                public var permissions: JeevesGraphQL.JSON? { __data["permissions"] }
                public var preferences: JeevesGraphQL.JSON? { __data["preferences"] }
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
