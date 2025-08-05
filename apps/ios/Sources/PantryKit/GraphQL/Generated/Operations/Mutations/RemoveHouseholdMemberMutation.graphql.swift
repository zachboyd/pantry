// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension PantryGraphQL {
  public class RemoveHouseholdMemberMutation: GraphQLMutation {
    public static let operationName: String = "RemoveHouseholdMember"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation RemoveHouseholdMember($input: RemoveHouseholdMemberInput!) { removeHouseholdMember(input: $input) }"#
      ))

    public var input: RemoveHouseholdMemberInput

    public init(input: RemoveHouseholdMemberInput) {
      self.input = input
    }

    public var __variables: Variables? { ["input": input] }

    public struct Data: PantryGraphQL.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { PantryGraphQL.Objects.Mutation }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("removeHouseholdMember", Bool.self, arguments: ["input": .variable("input")]),
      ] }

      public var removeHouseholdMember: Bool { __data["removeHouseholdMember"] }
    }
  }

}