//
//  Household+Equatable.swift
//  JeevesKit
//
//  Extension to make Household conform to Equatable
//

import Foundation

extension Household: Equatable {
    public static func == (lhs: Household, rhs: Household) -> Bool {
        lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.createdBy == rhs.createdBy &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt &&
            lhs.members == rhs.members
    }
}
