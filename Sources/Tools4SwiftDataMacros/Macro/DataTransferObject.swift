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
/// data transfer pipeline of an `@Model` class.
///
/// **Member expansion** adds to the class:
/// - `ConfigurableType` and `TransferableType` type aliases
/// - the `Transferable` struct (immutable snapshot)
/// - the `Configurable` struct (mutable draft)
/// - `init(_:in:)`, which builds a model from a draft
/// - `update(using:in:)`, which applies a draft to an existing model
///
/// **Extension expansion** adds the `SwiftDataPersistable` conformance,
/// unless the class already declares it.
///
/// The macro accepts an `orphans:` argument (an `OrphanPolicy`, `.detach` by
/// default) that decides what happens to the elements removed from a to-many
/// relationship during an update.
///
/// - Note: The generated structs conform to `Hashable` and `Sendable`, so
///   every attribute type of the model must conform to both.
public struct DataTransferObject: MemberMacro, ExtensionMacro {

    /// Generates the member declarations for a `@Model` class.
    ///
    /// Emits `MacroDiagnostic.onlyClasses` and generates nothing when the
    /// declaration is not a class.
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let expander = PersistableExpander(attribute: node, declaration: declaration) else {
            context.diagnose(Diagnostic(node: Syntax(node), message: MacroDiagnostic.onlyClasses))
            return []
        }

        return expander.expand()
    }

    /// Generates the `SwiftDataPersistable` conformance.
    ///
    /// The extension body is empty: the requirements are satisfied by the
    /// members added by the member expansion. The compiler only lists in
    /// `protocols` the conformances the type does not already have, so an
    /// explicit conformance written by the user produces no extension.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        guard declaration.is(ClassDeclSyntax.self), !protocols.isEmpty else { return [] }

        let extensionDecl = try ExtensionDeclSyntax(
            "extension \(type.trimmed): SwiftDataPersistable",
            membersBuilder: {}
        )

        return [extensionDecl]
    }
}
