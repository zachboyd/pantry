// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public protocol PantryGraphQL_SelectionSet: ApolloAPI.SelectionSet & ApolloAPI.RootSelectionSet
where Schema == PantryGraphQL.SchemaMetadata {}

public protocol PantryGraphQL_InlineFragment: ApolloAPI.SelectionSet & ApolloAPI.InlineFragment
where Schema == PantryGraphQL.SchemaMetadata {}

public protocol PantryGraphQL_MutableSelectionSet: ApolloAPI.MutableRootSelectionSet
where Schema == PantryGraphQL.SchemaMetadata {}

public protocol PantryGraphQL_MutableInlineFragment: ApolloAPI.MutableSelectionSet & ApolloAPI.InlineFragment
where Schema == PantryGraphQL.SchemaMetadata {}

public extension PantryGraphQL {
  public typealias SelectionSet = PantryGraphQL_SelectionSet

  public typealias InlineFragment = PantryGraphQL_InlineFragment

  public typealias MutableSelectionSet = PantryGraphQL_MutableSelectionSet

  public typealias MutableInlineFragment = PantryGraphQL_MutableInlineFragment

  public enum SchemaMetadata: ApolloAPI.SchemaMetadata {
    public static let configuration: any ApolloAPI.SchemaConfiguration.Type = SchemaConfiguration.self

    public static func objectType(forTypename typename: String) -> ApolloAPI.Object? {
      switch typename {
      case "Household": return PantryGraphQL.Objects.Household
      case "HouseholdMember": return PantryGraphQL.Objects.HouseholdMember
      case "Mutation": return PantryGraphQL.Objects.Mutation
      case "Query": return PantryGraphQL.Objects.Query
      case "User": return PantryGraphQL.Objects.User
      default: return nil
      }
    }
  }

  public enum Objects {}
  public enum Interfaces {}
  public enum Unions {}

}