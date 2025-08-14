// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension JeevesGraphQL {
    struct UpdateHouseholdInput: InputObject {
        public private(set) var __data: InputDict

        public init(_ data: InputDict) {
            __data = data
        }

        public init(
            id: String,
            name: GraphQLNullable<String> = nil,
            description: GraphQLNullable<String> = nil
        ) {
            __data = InputDict([
                "id": id,
                "name": name,
                "description": description,
            ])
        }

        public var id: String {
            get { __data["id"] }
            set { __data["id"] = newValue }
        }

        public var name: GraphQLNullable<String> {
            get { __data["name"] }
            set { __data["name"] = newValue }
        }

        public var description: GraphQLNullable<String> {
            get { __data["description"] }
            set { __data["description"] = newValue }
        }
    }
}
