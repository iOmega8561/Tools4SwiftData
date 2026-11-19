//
//  Copyright 2026 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  -----------------------------------------------------------------------
//
//  StoredProperty.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import SwiftSyntax

/// The role a stored property plays inside the data transfer pipeline.
///
/// The shape decides how a property is declared in the generated
/// `Transferable` and `Configurable` structs and how it is converted in
/// `init(_:in:)` and `update(using:in:)`.
enum PropertyShape: Equatable, Sendable {

    /// A plain attribute (scalar, `Codable` value, collection of values...).
    ///
    /// Attributes are copied verbatim in every direction.
    case attribute

    /// A to-one relationship towards another `@Model` class.
    ///
    /// To-one relationships are represented in both DTOs by the
    /// `PersistentIdentifier` of the related model. This breaks the value-type
    /// recursion that bidirectional relationships would otherwise create.
    ///
    /// - Parameters:
    ///   - target: The related model type, as written in source.
    ///   - isOptional: Whether the relationship is optional in the model.
    case toOne(target: String, isOptional: Bool)

    /// A to-many relationship towards another `@Model` class.
    ///
    /// To-many relationships are embedded by value: the `Transferable` holds
    /// `[Element.Transferable]` and the `Configurable` holds
    /// `[Element.Configurable]`.
    ///
    /// - Parameters:
    ///   - element: The related model type, as written in source.
    ///   - isOptional: Whether the relationship array is optional in the model.
    case toMany(element: String, isOptional: Bool)
}

/// Metadata about a stored property of a `@Model` class that takes part in
/// the data transfer pipeline.
///
/// Properties excluded from the pipeline (`@IgnoredByDTO`, `@Transient`,
/// static or computed properties) never become a `StoredProperty`.
struct StoredProperty: Sendable {

    /// The property's identifier.
    let name: String

    /// The property's type, exactly as written in source.
    let type: String

    /// Whether the property's type is optional.
    let isOptional: Bool

    /// How the property participates in the generated code.
    let shape: PropertyShape

    /// The default value for the generated memberwise initializer, if any.
    ///
    /// This is the property's initializer expression, or `nil` (the literal)
    /// for optional properties declared without one.
    let defaultValue: String?
}

/// Helpers that inspect `TypeSyntax` nodes.
///
/// Working on the syntax tree instead of on the textual description of a type
/// keeps dictionaries, nested generics and optionals apart without fragile
/// string manipulation.
enum TypeInspector {

    /// Removes one level of sugared optionality (`T?` or `T!`).
    ///
    /// - Returns: The wrapped type and whether a wrapper was removed.
    static func unwrapOptional(_ type: TypeSyntax) -> (wrapped: TypeSyntax, isOptional: Bool) {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return (optional.wrappedType, true)
        }
        if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return (iuo.wrappedType, true)
        }
        return (type, false)
    }

    /// Whether the type is optional, in sugared (`T?`, `T!`) or generic
    /// (`Optional<T>`, `Swift.Optional<T>`) spelling.
    static func isOptional(_ type: TypeSyntax) -> Bool {
        if unwrapOptional(type).isOptional {
            return true
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text == "Optional" && identifier.genericArgumentClause != nil
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text == "Optional"
                && member.baseType.trimmedDescription == "Swift"
                && member.genericArgumentClause != nil
        }
        return false
    }

    /// The name of a plain nominal type (`Message`, `MyModule.Message`).
    ///
    /// - Returns: The type name as written, or `nil` for generic, composite
    ///   or structural types.
    static func nominalName(_ type: TypeSyntax) -> String? {
        if let identifier = type.as(IdentifierTypeSyntax.self),
           identifier.genericArgumentClause == nil {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self),
           member.genericArgumentClause == nil,
           nominalName(member.baseType) != nil {
            return member.trimmedDescription
        }
        return nil
    }

    /// Classifies the type of a `@Relationship` property.
    ///
    /// Supported spellings are `Model`, `Model?`, `[Model]` and `[Model]?`.
    ///
    /// - Returns: The relationship shape, or `nil` when the type is not a
    ///   supported relationship type (dictionaries, sets, tuples, generic
    ///   spellings such as `Array<Model>`...).
    static func relationshipShape(of type: TypeSyntax) -> PropertyShape? {
        let (wrapped, isOptional) = unwrapOptional(type)

        if let array = wrapped.as(ArrayTypeSyntax.self) {
            guard let element = nominalName(array.element) else { return nil }
            return .toMany(element: element, isOptional: isOptional)
        }
        if let target = nominalName(wrapped) {
            return .toOne(target: target, isOptional: isOptional)
        }
        return nil
    }
}
