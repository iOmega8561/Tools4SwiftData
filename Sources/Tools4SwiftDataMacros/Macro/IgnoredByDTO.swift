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
//  IgnoredByDTO.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// A `PeerMacro` that marks a property to be ignored by the
/// `DataTransferObject` macro during code generation.
///
/// `IgnoredByDTO` does not generate any code itself; it serves purely as
/// metadata within the AST. `PropertyExtractor` skips properties annotated
/// with `@IgnoredByDTO` (or `@Tools4SwiftData.IgnoredByDTO`), so they are
/// excluded from:
/// - the generated `Configurable` and `Transferable` structs
/// - `init(_:in:)`, which is why they need a default value
/// - `update(using:in:)`
///
/// Typical uses are caches, transient state, and one side of a many-to-many
/// relationship, which would otherwise be embedded recursively.
public struct IgnoredByDTO: PeerMacro {
    
    /// Generates no code for the annotated declaration.
    ///
    /// The macro's role is purely metadata; the actual effect is observed
    /// by `PersistableExpander` during its AST traversal.
    ///
    /// - Parameter node: The `@IgnoredByDTO` attribute syntax.
    /// - Parameter declaration: The declaration the attribute is attached to.
    /// - Parameter context: The macro expansion context.
    ///
    /// - Returns: An empty array of declarations.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return []
    }
}
