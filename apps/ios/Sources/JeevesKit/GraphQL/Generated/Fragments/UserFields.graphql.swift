// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension JeevesGraphQL {
  struct UserFields: JeevesGraphQL.SelectionSet, Fragment {
    public static var fragmentDefinition: StaticString {
      #"fragment UserFields on User { __typename id auth_user_id email first_name last_name display_name avatar_url phone birth_date managed_by relationship_to_manager primary_household_id preferences is_ai created_at updated_at }"#
    }

    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.User }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("__typename", String.self),
      .field("id", JeevesGraphQL.ID.self),
      .field("auth_user_id", String?.self),
      .field("email", String?.self),
      .field("first_name", String.self),
      .field("last_name", String.self),
      .field("display_name", String?.self),
      .field("avatar_url", String?.self),
      .field("phone", String?.self),
      .field("birth_date", JeevesGraphQL.DateTime?.self),
      .field("managed_by", String?.self),
      .field("relationship_to_manager", String?.self),
      .field("primary_household_id", String?.self),
      .field("preferences", JeevesGraphQL.JSON?.self),
      .field("is_ai", Bool.self),
      .field("created_at", JeevesGraphQL.DateTime.self),
      .field("updated_at", JeevesGraphQL.DateTime.self),
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
    public var preferences: JeevesGraphQL.JSON? { __data["preferences"] }
    public var is_ai: Bool { __data["is_ai"] }
    public var created_at: JeevesGraphQL.DateTime { __data["created_at"] }
    public var updated_at: JeevesGraphQL.DateTime { __data["updated_at"] }
  }

}