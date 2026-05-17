//
//  TransferableBuilder.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import SwiftSyntax

/// A concrete implementation of `DynamicMemberBuilder` that generates an immutable
/// `Transferable` struct for a given model class.
///
/// `TransferableBuilder` produces a `public struct Transferable` that conforms
/// to `SwiftDataTransferable` (along with `Hashable`, `Equatable` and `Identifiable`). The
/// generated struct is immutable (`let`), making it suitable for serialization,
/// network transfer, or consumption by code that only needs to read model data.
///
/// The generated `Transferable` type:
/// - Defines `PersistableType` and `ConfigurableType` associated type aliases
/// - Includes a non-optional `persistentModelID` property, ensuring the
///   transferable always represents a persisted entity
/// - Declares all non-ignored properties with their builder types
/// - Provides a designated initializer that constructs the struct from a
///   `Persistable` object (the original `@Model` class)
///
/// This builder is used by macros that generate transferable types for
/// `@Model` classes, enabling the data workflow where a persistent model
/// is converted to a transferable format for API responses, caching,
/// or cross-process communication.
///
/// The key difference from `ConfigurableBuilder` is that `Transferable`
/// is immutable (`let` properties) and has a non-optional `persistentModelID`,
/// reflecting that transferable types represent finalized, persisted state
/// rather than mutable drafts.
///
/// - Parameter originalClassName: The name of the class being processed (typically
///   the `@Model` class).
/// - Parameter originalClassProps: The list of `StoredProperty` instances extracted
///   from the class's stored properties via SwiftSyntax parsing.
struct TransferableBuilder: DynamicMemberBuilder {
        
    let originalClassName: String
    
    let originalClassProps: [StoredProperty]
    
    /// The builder metadata used by the default implementation's methods.
    ///
    /// Declares the generated type as `Transferable`, with `let` declarations
    /// (immutable), and specifies that it initializes from the original
    /// `@Model` class directly.
    var builderProps: DynamicMemberBuilderProps { .init(
        declarationKind: .immutable,
        finalProductName: "Transferable",
        initFromTypeName: originalClassName
    )}
    
    /// Generates the `Transferable` struct declaration.
    ///
    /// The generated struct conforms to `SwiftDataTransferable` (along with
    /// `Hashable`, `Equatable` and `Identifiable`). It includes
    /// the associated type aliases, a non-optional `persistentModelID`
    /// property, the synthesized property declarations, and the designated
    /// initializer.
    ///
    /// Unlike `Configurable`, the generated `Transferable` does not include
    /// a `validate(for:)` method or a default-value initializer, as
    /// transferable types are designed to be created from persisted data
    /// and do not support direct construction with defaults.
    ///
    /// - Returns: A `DeclSyntax` representing the generated `Transferable` struct.
    func generate() -> DeclSyntax {
                
        let protoProps = buildProtocolConformanceProps()
        let protocols = protoProps.protocols.union(["SwiftDataTransferable"])
                                .joined(separator: ", ")
        
        return """
        public struct Transferable: \(raw: protocols) {
            public typealias PersistableType = \(raw: originalClassName)
            public typealias ConfigurableType = \(raw: originalClassName).Configurable

            public let persistentModelID: PersistentIdentifier
            \(raw: protoProps.properties)
            \(raw: protoProps.methods)
            \(raw: makePropertyDeclarations().joined(separator: "\n"))
            
            \(makeDesignatedInitializer())
        }
        """
    }
    
    /// Initializes a `TransferableBuilder` with the class metadata.
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
