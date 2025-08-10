// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension JeevesGraphQL {
    struct CreateHouseholdInput: InputObject {
        public private(set) var __data: InputDict

        public init(_ data: InputDict) {
            __data = data
        }

        public init(
            name: String,
            description: GraphQLNullable<String> = nil
        ) {
            __data = InputDict([
                "name": name,
                "description": description,
            ])
        }

        public var name: String {
            get { __data["name"] }
            set { __data["name"] = newValue }
        }

        public var description: GraphQLNullable<String> {
            get { __data["description"] }
            set { __data["description"] = newValue }
        }
    }
}
