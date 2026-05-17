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
//  DataTransferObject.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// A combined `MemberMacro` and `ExtensionMacro` that generates the full
/// protocol conformances and methods required by `SwiftDataPersistable` for
/// an `@Model` class.
///
/// `DataTransferObject` is applied to classes annotated with `@Model` and
/// expands them into a complete data transfer pipeline:
///
/// **Member expansion** (MemberMacro):
/// Generates the following declarations inside the class:
/// - `public typealias ConfigurableType = Configurable`
/// - `public typealias TransferableType = Transferable`
/// - The `Configurable` struct (mutable draft)
/// - The `Transferable` struct (immutable snapshot)
/// - `init(_ configurableModel: Configurable)` — converts a configurable draft
///   into a persistable model
/// - `update(using:)` — updates the model's state from a configurable draft,
///   handling scalar assignments and relationship array diffing
///
/// **Extension expansion** (ExtensionMacro):
/// Adds a `SwiftDataPersistable` conformance extension to the class,
/// enabling the generated types to be used within the persistence protocol
/// hierarchy.
///
/// If the target declaration is not a class (e.g., a struct or enum), the
/// macro emits a `MacroDiagnostic.onlyClasses` error and produces no output.
///
/// This macro is the entry point of the macro system — applying it to an
/// `@Model` class automatically generates the entire configurable/transferable
/// infrastructure, enabling the `Transferable → Configurable → Persistable`
/// conversion workflow without manual boilerplate.
/// 
/// - Note: The generated `Configurable` and `Transferable` structs conform
///   to `Hashable` and `Equatable` automatically. All property types from the
///   original `@Model` class **must be suitable for Swift's automatic
///   Hashable/Equatable synthesis**. If a property type does not conform to
///   `Hashable` or `Equatable`, the generated code will fail to compile.
public struct DataTransferObject: MemberMacro, ExtensionMacro {
    
    /// Generates the member declarations for a `@Model` class.
    ///
    /// Validates that the declaration is a class, then delegates to
    /// `PersistableExpander` to produce the synthesized declarations.
    /// If validation fails, emits a diagnostic and returns an empty array.
    ///
    /// - Parameter node: The `@DataTransferObject` attribute syntax.
    /// - Parameter declaration: The declaration the attribute is attached to.
    /// - Parameter context: The macro expansion context for diagnostics.
    ///
    /// - Returns: An array of `DeclSyntax` elements representing the expanded
    ///   class members.
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let expander = PersistableExpander(
            originalDeclaration: declaration
        ) else {
            let message = MacroDiagnostic.onlyClasses
            let diagnostic = Diagnostic(node: Syntax(node), message: message)
            context.diagnose(diagnostic)
            return []
        }
        
        return expander.expand()
    }
    
    /// Generates the `SwiftDataPersistable` extension for a `@Model` class.
    ///
    /// This extension enables the generated `init(_:)` and `update(using:)`
    /// methods to satisfy the protocol requirements. The extension is empty
    /// of body members because the methods are already injected as class
    /// members by the `MemberMacro` expansion.
    ///
    /// - Parameter node: The `@DataTransferObject` attribute syntax.
    /// - Parameter declaration: The declaration the attribute is attached to.
    /// - Parameter type: The type to extend (the class name).
    /// - Parameter protocols: The protocols to conform to (`SwiftDataPersistable`).
    /// - Parameter context: The macro expansion context.
    ///
    /// - Returns: A single `ExtensionDeclSyntax` conforming to
    ///   `SwiftDataPersistable`, or an empty array if the declaration is
    ///   not a class.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else { return [] }
        let className = classDecl.name.text
        
        let ext: ExtensionDeclSyntax = try ExtensionDeclSyntax(
            "extension \(raw: className): SwiftDataPersistable",
            membersBuilder: {}
        )
        
        return [ext]
    }
}
