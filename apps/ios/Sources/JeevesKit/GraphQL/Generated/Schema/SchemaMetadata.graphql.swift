// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public protocol JeevesGraphQL_SelectionSet: ApolloAPI.SelectionSet & ApolloAPI.RootSelectionSet
where Schema == JeevesGraphQL.SchemaMetadata {}

public protocol JeevesGraphQL_InlineFragment: ApolloAPI.SelectionSet & ApolloAPI.InlineFragment
where Schema == JeevesGraphQL.SchemaMetadata {}

public protocol JeevesGraphQL_MutableSelectionSet: ApolloAPI.MutableRootSelectionSet
where Schema == JeevesGraphQL.SchemaMetadata {}

public protocol JeevesGraphQL_MutableInlineFragment: ApolloAPI.MutableSelectionSet & ApolloAPI.InlineFragment
where Schema == JeevesGraphQL.SchemaMetadata {}

public extension JeevesGraphQL {
  typealias SelectionSet = JeevesGraphQL_SelectionSet

  typealias InlineFragment = JeevesGraphQL_InlineFragment

  typealias MutableSelectionSet = JeevesGraphQL_MutableSelectionSet

  typealias MutableInlineFragment = JeevesGraphQL_MutableInlineFragment

  enum SchemaMetadata: ApolloAPI.SchemaMetadata {
    public static let configuration: any ApolloAPI.SchemaConfiguration.Type = SchemaConfiguration.self

    public static func objectType(forTypename typename: String) -> ApolloAPI.Object? {
      switch typename {
      case "Household": return JeevesGraphQL.Objects.Household
      case "HouseholdMember": return JeevesGraphQL.Objects.HouseholdMember
      case "Mutation": return JeevesGraphQL.Objects.Mutation
      case "Query": return JeevesGraphQL.Objects.Query
      case "Subscription": return JeevesGraphQL.Objects.Subscription
      case "User": return JeevesGraphQL.Objects.User
      default: return nil
      }
    }
  }

  enum Objects {}
  enum Interfaces {}
  enum Unions {}

}