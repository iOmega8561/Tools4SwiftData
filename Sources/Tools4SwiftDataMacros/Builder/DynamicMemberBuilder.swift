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
//  DynamicMemberBuilder.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import Foundation
import SwiftSyntax

/// A protocol that provides a default implementation for generating dynamic
/// member lookup builders or proxies based on model class structure.
///
/// `DynamicMemberBuilder` defines the contract for types that synthesize
/// code representations of model properties. Conforming types receive a
/// `DynamicMemberBuilderProps` instance that contains the metadata needed
/// to generate declarations, initializers, and protocol conformances.
///
/// The protocol is designed to be implemented once per macro expansion,
/// with the default implementation providing the core generation logic.
/// Specific conformances typically customize the `generate()` method while
/// reusing the shared helper methods from the default implementation.
///
/// - Parameter builderProps: Metadata about the generated type, including
///   the target name and initialization source type.
/// - Parameter originalClassName: The name of the class being processed by
///   the macro (typically the `@Model` class).
/// - Parameter originalClassProps: The list of `StoredProperty` instances
///   extracted from the class's stored properties via SwiftSyntax parsing.
///
/// - Returns: A `DeclSyntax` representing the synthesized declaration.
protocol DynamicMemberBuilder: Sendable {
    
    var builderProps: DynamicMemberBuilderProps { get }
    
    var originalClassName: String { get }
    
    var originalClassProps: [StoredProperty] { get }
    
    /// Generates the final declaration syntax for the macro output.
    func generate() -> DeclSyntax
}

extension DynamicMemberBuilder {
    
    /// Constructs the type label for a property declaration.
    ///
    /// For relationship properties, the label includes the `finalProductName`
    /// suffix to indicate that the type is a builder/proxy variant. For
    /// array relationships, the element type is also prefixed. Regular
    /// properties use their raw type string.
    ///
    /// - Parameter prop: The property to generate a label for.
    ///
    /// - Returns: A string like `"name: String"` or `"messages: [Message.Builder]"`.
    func makeDeclarationLabel(for prop: StoredProperty) -> String {
        var label: String = "\(prop.name): "
        
        if prop.isRelationship && prop.isArray {
            label += "[\(prop.sanitizedType).\(builderProps.finalProductName)]"
        } else if prop.isRelationship {
            label += "\(prop.sanitizedType).\(builderProps.finalProductName)"
        } else {
            label += "\(prop.type)"
        }
        
        return label
    }
    
    /// Generates public property declarations for all non-ignored properties.
    ///
    /// Uses `builderProps.declarationKind` to determine whether declarations
    /// are `var` or `let`. Properties marked with `isIgnored == true` are
    /// excluded from the generated output.
    ///
    /// - Returns: An array of declaration strings, one per non-ignored property.
    func makePropertyDeclarations() -> [String] {
        originalClassProps.compactMap { prop in
            guard !prop.isIgnored else {
                return nil
            }
            
            return "public \(builderProps.declarationKind.rawValue) \(makeDeclarationLabel(for: prop))"
        }
    }
    
    /// Generates a designated initializer that takes an object of the source
    /// type and assigns all non-ignored properties.
    ///
    /// Relationship properties are handled specially:
    /// - Array relationships: each element is mapped to the `finalProductName`
    ///   initializer, producing a collection of builder instances.
    /// - Single relationships: the relationship object is passed to the
    ///   `finalProductName` initializer to produce a builder instance.
    /// - Regular properties: values are assigned directly.
    ///
    /// The initializer always sets `persistentModelID` from the source object.
    ///
    /// - Returns: A `DeclSyntax` representing the generated initializer.
    func makeDesignatedInitializer() -> DeclSyntax {
        let assignments: [String] = originalClassProps.compactMap { field in
            guard !field.isIgnored else { return nil }
            
            var assignment = "self.\(field.name) = "
            
            if field.isRelationship,
               let element = field.elementTypeName {
                assignment += "obj.\(field.name).map { \(element).\(builderProps.finalProductName)($0) }"
            } else if field.isRelationship {
                assignment += "\(field.sanitizedType).\(builderProps.finalProductName)(obj.\(field.name))"
            } else {
                assignment += "obj.\(field.name)"
            }
            
            return assignment
        }
        
        return """
        public init(_ obj: \(raw: builderProps.initFromTypeName)) {
            self.persistentModelID = obj.persistentModelID
            \(raw: assignments.joined(separator: "\n"))
        }
        """
    }
    
    /// Generates a convenience initializer with default values for all
    /// non-ignored properties.
    ///
    /// Properties with a `defaultValue` (e.g., from `@Model` annotations
    /// or explicit defaults) receive a parameter with that default.
    /// Properties without defaults are still included as parameters but
    /// have no default value.
    ///
    /// - Returns: A `DeclSyntax` representing the generated initializer.
    func makeDefaultValueInitializer() -> DeclSyntax {
        var assignments: [String] = []
        var parameters: [String] = []
        
        originalClassProps.forEach { prop in
            guard !prop.isIgnored else { return }
            
            let assignment: String
            var parameter: String = makeDeclarationLabel(for: prop)
            
            if let defaultValue = prop.defaultValue {
                parameter += " = \(defaultValue)"
            }
            
            assignments.append("self.\(prop.name) = \(prop.name)")
            parameters.append(parameter)
        }
        
        return """
        public init(\(raw: parameters.joined(separator: ",\n"))) {
            \(raw: assignments.joined(separator: "\n"))
        }
        """
    }
    
    /// Constructs `ProtocolConformanceProps` for the generated type.
    ///
    /// The generated type always conforms to `Hashable` and `Equatable`.
    /// When `declarationKind` is `.immutable`, it additionally conforms
    /// to `Identifiable` with a computed `id` property. When `declarationKind`
    /// is `.mutable`, the `id` property is optional.
    ///
    /// If the original class already declares an `id` property, the generated
    /// type adopts `Identifiable` but does not generate a duplicate `id`
    /// property. Otherwise, a computed `id` property is added that forwards
    /// to `persistentModelID`.
    ///
    /// - Returns: A `ProtocolConformanceProps` containing the protocols and
    ///   any additional property declarations needed for conformance.
    /// - Important: This default implementation **does not** generate custom protocol required methods.
    ///   All property types from the original `@Model` class **must be suitable for Swift's automatic Hashable/Equatable synthesis**.
    func buildProtocolConformanceProps() -> ProtocolConformanceProps {
        let persistentIdentifierType: String
        var finalProductProtocols: Set<String> = ["Hashable", "Equatable"]

        switch builderProps.declarationKind {
        case .immutable:
            persistentIdentifierType = "PersistentIdentifier"
            finalProductProtocols.insert("Identifiable")
        case .mutable:
            persistentIdentifierType = "PersistentIdentifier?"
        }
        
        var identifiableProperty: String = ""
        if originalClassProps.first(where: { $0.name == "id" }) == nil {
           identifiableProperty = """
               public var id: \(persistentIdentifierType) { 
                   self.persistentModelID 
               }
           """
        } else {
            finalProductProtocols.insert("Identifiable")
        }
        
        return ProtocolConformanceProps(
            protocols: finalProductProtocols,
            properties: identifiableProperty
        )
    }
}
