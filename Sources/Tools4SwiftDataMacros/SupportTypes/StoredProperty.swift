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

import Foundation

/// A structure that encapsulates metadata about a single property declared in
/// a model class, extracted during macro expansion via SwiftSyntax.
///
/// `StoredProperty` captures the essential attributes of each property: its
/// name, type, whether it represents a relationship, whether it should be
/// ignored by the generated code, and an optional default value. It also
/// provides convenience computed properties to work with array-typed properties
/// and sanitized type representations.
///
/// This structure is used internally by macro implementations to traverse the
/// AST of a model class, collect all its stored properties, and generate
/// appropriate protocol conformances or method implementations based on their
/// characteristics.
///
/// - Parameter name: The property's identifier.
/// - Parameter type: The property's type as a string (e.g., `"String"`, `"[Message]"`).
/// - Parameter isRelationship: Whether this property represents a relationship
///   (e.g., a foreign key or `@Relationship`-annotated property).
/// - Parameter isIgnored: Whether this property should be excluded from
///   generated code (e.g., private properties or transient fields).
/// - Parameter defaultValue: An optional literal representing the default value
///   of the property, if one was explicitly declared.
struct StoredProperty: Sendable {
    
    let name: String
    let type: String
    let isRelationship: Bool
    let isIgnored: Bool
    let defaultValue: String?

    /// Extracts the element type from array-typed properties.
    ///
    /// For types like `"[Message]"`, this returns `"Message"`, enabling
    /// generated code to handle collection properties correctly (e.g.,
    /// producing `forEach` loops or collection-specific initializers).
    var elementTypeName: String? {
        isArray ? type
            .trimmingCharacters(in: .init(charactersIn: "[]"))
            .trimmingCharacters(in: .whitespaces) : nil
    }
    
    /// Indicates whether the type represents an array collection.
    var isArray: Bool {
        type.hasPrefix("[") && type.hasSuffix("]")
    }
    
    /// Produces a sanitized version of the type, stripping optional markers
    /// (`?` and `!`) and whitespace.
    ///
    /// This is useful for generating type names in protocol conformances,
    /// method signatures, or generic parameters where the optional nature
    /// of the type is not relevant.
    var sanitizedType: String {
        (elementTypeName ?? type)
            .trimmingCharacters(in: .init(charactersIn: "?!"))
            .trimmingCharacters(in: .whitespaces)
    }
}
