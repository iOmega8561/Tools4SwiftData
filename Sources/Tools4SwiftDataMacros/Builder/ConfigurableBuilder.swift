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
//  ConfigurableBuilder.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import SwiftSyntax

/// A concrete implementation of `DynamicMemberBuilder` that generates a mutable
/// `Configurable` struct for a given model class.
///
/// `ConfigurableBuilder` produces a `public struct Configurable` that conforms
/// to `SwiftDataConfigurable` (along with `Hashable` and `Equatable`). The
/// generated struct is mutable (`var`), meaning it supports in-place
/// modification, which is appropriate for the configurable/draft pattern.
///
/// The generated `Configurable` type:
/// - Defines `PersistableType` and `TransferableType` associated type aliases
/// - Includes a private `persistentModelID` property (set via the initializer)
/// - Declares all non-ignored properties with their builder types
/// - Provides both a default-value initializer and a designated initializer
///   that constructs the struct from a `Transferable` object
/// - Stubs a `validate(for:)` method for future implementation
///
/// This builder is used by macros that generate configurable types for
/// `@Model` classes, enabling the data workflow where a transferable model
/// is converted to a configurable draft before persistence.
///
/// - Parameter originalClassName: The name of the class being processed (typically
///   the `@Model` class).
/// - Parameter originalClassProps: The list of `StoredProperty` instances extracted
///   from the class's stored properties via SwiftSyntax parsing.
struct ConfigurableBuilder: DynamicMemberBuilder {
        
    let originalClassName: String
    
    let originalClassProps: [StoredProperty]
    
    /// The builder metadata used by the default implementation's methods.
    ///
    /// Declares the generated type as `Configurable`, with `var` declarations
    /// (mutable), and specifies that it initializes from the `Transferable`
    /// associated type of the original class.
    var builderProps: DynamicMemberBuilderProps { .init(
        declarationKind: .mutable,
        finalProductName: "Configurable",
        initFromTypeName: "\(originalClassName).Transferable"
    )}
    
    /// Generates the `Configurable` struct declaration.
    ///
    /// The generated struct conforms to `SwiftDataConfigurable` (and
    /// `Hashable`, `Equatable`, and optionally `Identifiable`). It includes
    /// the associated type aliases, the `persistentModelID` property, the
    /// synthesized property declarations, and both initializers. The
    /// `validate(for:)` method is included as a stub for future implementation.
    ///
    /// - Returns: A `DeclSyntax` representing the generated `Configurable` struct.
    func generate() -> DeclSyntax {
        
        let protoProps = buildProtocolConformanceProps()
        let protocols = protoProps.protocols.union(["SwiftDataConfigurable"])
                                .joined(separator: ", ")
        
        return """
        public struct Configurable: \(raw: protocols) {
            public typealias PersistableType = \(raw: originalClassName)
            public typealias TransferableType = \(raw: originalClassName).Transferable
        
            public private(set) var persistentModelID: PersistentIdentifier? = nil
            \(raw: protoProps.properties)
            \(raw: protoProps.methods)
            \(raw: makePropertyDeclarations().joined(separator: "\n"))
        
            public func validate(for scope: SwiftDataValidationScope) throws {
                // Upcoming implementation
            }
        
            \(makeDefaultValueInitializer())
            \(makeDesignatedInitializer())
        }
        """
    }
    
    /// Initializes a `ConfigurableBuilder` with the class metadata.
    ///
    /// - Parameter originalClassName: The name of the class being processed.
    /// - Parameter originalClassProps: The extracted stored properties.
    init(
        className originalClassName: String,
        props originalClassProps: [StoredProperty]
    ) {
        self.originalClassName = originalClassName
        self.originalClassProps = originalClassProps
    }
}
