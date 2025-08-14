// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension JeevesGraphQL {
    struct HouseholdMemberFields: JeevesGraphQL.SelectionSet, Fragment {
        public static var fragmentDefinition: StaticString {
            #"fragment HouseholdMemberFields on HouseholdMember { __typename id household_id user_id role joined_at }"#
        }

        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.HouseholdMember }
        public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("id", JeevesGraphQL.ID.self),
            .field("household_id", String.self),
            .field("user_id", String.self),
            .field("role", String.self),
            .field("joined_at", JeevesGraphQL.DateTime.self),
        ] }

        public var id: JeevesGraphQL.ID { __data["id"] }
        public var household_id: String { __data["household_id"] }
        public var user_id: String { __data["user_id"] }
        public var role: String { __data["role"] }
        public var joined_at: JeevesGraphQL.DateTime { __data["joined_at"] }
    }
}
