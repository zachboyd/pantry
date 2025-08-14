// @generated
// This file was automatically generated and should not be edited.

@preconcurrency @_exported import ApolloAPI

public extension JeevesGraphQL {
  class UpdateUserLocalCacheMutation: LocalCacheMutation {
    public static let operationType: GraphQLOperationType = .mutation

    public var input: UpdateUserInput

    public init(input: UpdateUserInput) {
      self.input = input
    }

    public var __variables: GraphQLOperation.Variables? { ["input": input] }

    public struct Data: JeevesGraphQL.MutableSelectionSet {
      public var __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.Mutation }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("updateUser", UpdateUser.self, arguments: ["input": .variable("input")]),
      ] }

      public var updateUser: UpdateUser {
        get { __data["updateUser"] }
        set { __data["updateUser"] = newValue }
      }

      public init(
        updateUser: UpdateUser
      ) {
        self.init(_dataDict: DataDict(
          data: [
            "__typename": JeevesGraphQL.Objects.Mutation.typename,
            "updateUser": updateUser._fieldData,
          ],
          fulfilledFragments: [
            ObjectIdentifier(UpdateUserLocalCacheMutation.Data.self),
          ]
        ))
      }

      /// UpdateUser
      ///
      /// Parent Type: `User`
      public struct UpdateUser: JeevesGraphQL.MutableSelectionSet {
        public var __data: DataDict
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
          .field("permissions", JeevesGraphQL.JSON?.self),
          .field("preferences", JeevesGraphQL.JSON?.self),
          .field("is_ai", Bool.self),
          .field("created_at", JeevesGraphQL.DateTime.self),
          .field("updated_at", JeevesGraphQL.DateTime.self),
        ] }

        public var id: JeevesGraphQL.ID {
          get { __data["id"] }
          set { __data["id"] = newValue }
        }

        public var auth_user_id: String? {
          get { __data["auth_user_id"] }
          set { __data["auth_user_id"] = newValue }
        }

        public var email: String? {
          get { __data["email"] }
          set { __data["email"] = newValue }
        }

        public var first_name: String {
          get { __data["first_name"] }
          set { __data["first_name"] = newValue }
        }

        public var last_name: String {
          get { __data["last_name"] }
          set { __data["last_name"] = newValue }
        }

        public var display_name: String? {
          get { __data["display_name"] }
          set { __data["display_name"] = newValue }
        }

        public var avatar_url: String? {
          get { __data["avatar_url"] }
          set { __data["avatar_url"] = newValue }
        }

        public var phone: String? {
          get { __data["phone"] }
          set { __data["phone"] = newValue }
        }

        public var birth_date: JeevesGraphQL.DateTime? {
          get { __data["birth_date"] }
          set { __data["birth_date"] = newValue }
        }

        public var managed_by: String? {
          get { __data["managed_by"] }
          set { __data["managed_by"] = newValue }
        }

        public var relationship_to_manager: String? {
          get { __data["relationship_to_manager"] }
          set { __data["relationship_to_manager"] = newValue }
        }

        public var primary_household_id: String? {
          get { __data["primary_household_id"] }
          set { __data["primary_household_id"] = newValue }
        }

        public var permissions: JeevesGraphQL.JSON? {
          get { __data["permissions"] }
          set { __data["permissions"] = newValue }
        }

        public var preferences: JeevesGraphQL.JSON? {
          get { __data["preferences"] }
          set { __data["preferences"] = newValue }
        }

        public var is_ai: Bool {
          get { __data["is_ai"] }
          set { __data["is_ai"] = newValue }
        }

        public var created_at: JeevesGraphQL.DateTime {
          get { __data["created_at"] }
          set { __data["created_at"] = newValue }
        }

        public var updated_at: JeevesGraphQL.DateTime {
          get { __data["updated_at"] }
          set { __data["updated_at"] = newValue }
        }

        public init(
          id: JeevesGraphQL.ID,
          auth_user_id: String? = nil,
          email: String? = nil,
          first_name: String,
          last_name: String,
          display_name: String? = nil,
          avatar_url: String? = nil,
          phone: String? = nil,
          birth_date: JeevesGraphQL.DateTime? = nil,
          managed_by: String? = nil,
          relationship_to_manager: String? = nil,
          primary_household_id: String? = nil,
          permissions: JeevesGraphQL.JSON? = nil,
          preferences: JeevesGraphQL.JSON? = nil,
          is_ai: Bool,
          created_at: JeevesGraphQL.DateTime,
          updated_at: JeevesGraphQL.DateTime
        ) {
          self.init(_dataDict: DataDict(
            data: [
              "__typename": JeevesGraphQL.Objects.User.typename,
              "id": id,
              "auth_user_id": auth_user_id,
              "email": email,
              "first_name": first_name,
              "last_name": last_name,
              "display_name": display_name,
              "avatar_url": avatar_url,
              "phone": phone,
              "birth_date": birth_date,
              "managed_by": managed_by,
              "relationship_to_manager": relationship_to_manager,
              "primary_household_id": primary_household_id,
              "permissions": permissions,
              "preferences": preferences,
              "is_ai": is_ai,
              "created_at": created_at,
              "updated_at": updated_at,
            ],
            fulfilledFragments: [
              ObjectIdentifier(UpdateUserLocalCacheMutation.Data.UpdateUser.self),
            ]
          ))
        }
      }
    }
  }
}
