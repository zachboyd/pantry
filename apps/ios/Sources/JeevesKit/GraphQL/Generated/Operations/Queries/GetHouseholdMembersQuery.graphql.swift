// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension JeevesGraphQL {
    class GetHouseholdMembersQuery: GraphQLQuery {
        public static let operationName: String = "GetHouseholdMembers"
        public static let operationDocument: ApolloAPI.OperationDocument = .init(
            definition: .init(
                #"query GetHouseholdMembers($input: GetHouseholdMembersInput!) { householdMembers(input: $input) { __typename ...HouseholdMemberFields } }"#,
                fragments: [HouseholdMemberFields.self],
            ))

        public var input: GetHouseholdMembersInput

        public init(input: GetHouseholdMembersInput) {
            self.input = input
        }

        public var __variables: Variables? { ["input": input] }

        public struct Data: JeevesGraphQL.SelectionSet {
            public let __data: DataDict
            public init(_dataDict: DataDict) { __data = _dataDict }

            public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.Query }
            public static var __selections: [ApolloAPI.Selection] { [
                .field("householdMembers", [HouseholdMember].self, arguments: ["input": .variable("input")]),
            ] }

            public var householdMembers: [HouseholdMember] { __data["householdMembers"] }

            /// HouseholdMember
            ///
            /// Parent Type: `HouseholdMember`
            public struct HouseholdMember: JeevesGraphQL.SelectionSet {
                public let __data: DataDict
                public init(_dataDict: DataDict) { __data = _dataDict }

                public static var __parentType: any ApolloAPI.ParentType { JeevesGraphQL.Objects.HouseholdMember }
                public static var __selections: [ApolloAPI.Selection] { [
                    .field("__typename", String.self),
                    .fragment(HouseholdMemberFields.self),
                ] }

                public var id: JeevesGraphQL.ID { __data["id"] }
                public var household_id: String { __data["household_id"] }
                public var user_id: String { __data["user_id"] }
                public var role: String { __data["role"] }
                public var joined_at: JeevesGraphQL.DateTime { __data["joined_at"] }

                public struct Fragments: FragmentContainer {
                    public let __data: DataDict
                    public init(_dataDict: DataDict) { __data = _dataDict }

                    public var householdMemberFields: HouseholdMemberFields { _toFragment() }
                }
            }
        }
    }
}
