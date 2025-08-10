// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension JeevesGraphQL {
    struct UpdateUserInput: InputObject {
        public private(set) var __data: InputDict

        public init(_ data: InputDict) {
            __data = data
        }

        public init(
            id: String,
            firstName: GraphQLNullable<String> = nil,
            lastName: GraphQLNullable<String> = nil,
            displayName: GraphQLNullable<String> = nil,
            avatarUrl: GraphQLNullable<String> = nil,
            phone: GraphQLNullable<String> = nil,
            birthDate: GraphQLNullable<DateTime> = nil,
            email: GraphQLNullable<String> = nil,
            primaryHouseholdId: GraphQLNullable<String> = nil,
            preferences: GraphQLNullable<JSON> = nil
        ) {
            __data = InputDict([
                "id": id,
                "first_name": firstName,
                "last_name": lastName,
                "display_name": displayName,
                "avatar_url": avatarUrl,
                "phone": phone,
                "birth_date": birthDate,
                "email": email,
                "primary_household_id": primaryHouseholdId,
                "preferences": preferences,
            ])
        }

        public var id: String {
            get { __data["id"] }
            set { __data["id"] = newValue }
        }

        public var firstName: GraphQLNullable<String> {
            get { __data["first_name"] }
            set { __data["first_name"] = newValue }
        }

        public var lastName: GraphQLNullable<String> {
            get { __data["last_name"] }
            set { __data["last_name"] = newValue }
        }

        public var displayName: GraphQLNullable<String> {
            get { __data["display_name"] }
            set { __data["display_name"] = newValue }
        }

        public var avatarUrl: GraphQLNullable<String> {
            get { __data["avatar_url"] }
            set { __data["avatar_url"] = newValue }
        }

        public var phone: GraphQLNullable<String> {
            get { __data["phone"] }
            set { __data["phone"] = newValue }
        }

        public var birthDate: GraphQLNullable<DateTime> {
            get { __data["birth_date"] }
            set { __data["birth_date"] = newValue }
        }

        public var email: GraphQLNullable<String> {
            get { __data["email"] }
            set { __data["email"] = newValue }
        }

        public var primaryHouseholdId: GraphQLNullable<String> {
            get { __data["primary_household_id"] }
            set { __data["primary_household_id"] = newValue }
        }

        public var preferences: GraphQLNullable<JSON> {
            get { __data["preferences"] }
            set { __data["preferences"] = newValue }
        }
    }
}
