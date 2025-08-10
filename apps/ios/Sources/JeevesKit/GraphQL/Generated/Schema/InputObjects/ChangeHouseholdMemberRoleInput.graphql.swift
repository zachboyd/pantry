// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension JeevesGraphQL {
    struct ChangeHouseholdMemberRoleInput: InputObject {
        public private(set) var __data: InputDict

        public init(_ data: InputDict) {
            __data = data
        }

        public init(
            householdId: String,
            userId: String,
            newRole: String
        ) {
            __data = InputDict([
                "householdId": householdId,
                "userId": userId,
                "newRole": newRole,
            ])
        }

        public var householdId: String {
            get { __data["householdId"] }
            set { __data["householdId"] = newValue }
        }

        public var userId: String {
            get { __data["userId"] }
            set { __data["userId"] = newValue }
        }

        public var newRole: String {
            get { __data["newRole"] }
            set { __data["newRole"] = newValue }
        }
    }
}
