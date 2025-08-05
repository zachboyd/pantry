// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension PantryGraphQL {
  public class GetCurrentUserQuery: GraphQLQuery {
    public static let operationName: String = "GetCurrentUser"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query GetCurrentUser { currentUser { __typename id auth_user_id email first_name last_name display_name avatar_url phone birth_date managed_by relationship_to_manager created_at updated_at } }"#
      ))

    public init() {}

    public struct Data: PantryGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { PantryGraphQL.Objects.Query }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("currentUser", CurrentUser.self),
      ] }

      public var currentUser: CurrentUser { __data["currentUser"] }

      /// CurrentUser
      ///
      /// Parent Type: `User`
      public struct CurrentUser: PantryGraphQL.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { PantryGraphQL.Objects.User }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", String.self),
          .field("auth_user_id", String?.self),
          .field("email", String?.self),
          .field("first_name", String.self),
          .field("last_name", String.self),
          .field("display_name", String?.self),
          .field("avatar_url", String?.self),
          .field("phone", String?.self),
          .field("birth_date", PantryGraphQL.DateTime?.self),
          .field("managed_by", String?.self),
          .field("relationship_to_manager", String?.self),
          .field("created_at", PantryGraphQL.DateTime.self),
          .field("updated_at", PantryGraphQL.DateTime.self),
        ] }

        public var id: String { __data["id"] }
        public var auth_user_id: String? { __data["auth_user_id"] }
        public var email: String? { __data["email"] }
        public var first_name: String { __data["first_name"] }
        public var last_name: String { __data["last_name"] }
        public var display_name: String? { __data["display_name"] }
        public var avatar_url: String? { __data["avatar_url"] }
        public var phone: String? { __data["phone"] }
        public var birth_date: PantryGraphQL.DateTime? { __data["birth_date"] }
        public var managed_by: String? { __data["managed_by"] }
        public var relationship_to_manager: String? { __data["relationship_to_manager"] }
        public var created_at: PantryGraphQL.DateTime { __data["created_at"] }
        public var updated_at: PantryGraphQL.DateTime { __data["updated_at"] }
      }
    }
  }

}