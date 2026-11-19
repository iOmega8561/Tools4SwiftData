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
//  Tools4SwiftData.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 15/05/2026.
//

import Foundation
import SwiftData

// MARK: - Start of macro declarations

/// A macro that expands an `@Model` class into a complete data transfer
/// pipeline.
///
/// Applied to a class annotated with `@Model`, this macro generates:
/// - a `Transferable` struct, the immutable `Sendable` snapshot of the model
/// - a `Configurable` struct, the mutable draft used to create and update it
/// - `init(_:in:)` and `update(using:in:)`
/// - the `SwiftDataPersistable` conformance
///
/// Relationships must be declared with an explicit `@Relationship` attribute.
/// To-one relationships are represented in the DTOs by the related model's
/// `PersistentIdentifier`; to-many relationships are embedded by value as
/// arrays of the related model's DTOs. The related model must use
/// `@DataTransferObject` too.
///
/// Embedding by value means that a many-to-many relationship would recurse
/// forever: mark one of its two sides with `@IgnoredByDTO`.
///
/// - Parameter orphans: What happens to the models removed from a to-many
///   relationship during an update. Defaults to `.detach`.
///
/// - Note: Every attribute type of the model must conform to `Hashable` and
///   `Sendable`, because the generated structs do.
/// - Note: The class still needs an initializer of its own: `@Model` checks
///   the source of the class and cannot see the generated `init(_:in:)`.
@attached(member, names:
    named(Transferable),
    named(Configurable),
    named(ConfigurableType),
    named(TransferableType),
    named(init),
    named(update)
)
@attached(extension, conformances: SwiftDataPersistable)
public macro DataTransferObject(
    orphans: OrphanPolicy = .detach
) = #externalMacro(module: "Tools4SwiftDataMacros", type: "DataTransferObject")

/// A peer macro that excludes a property from the `@DataTransferObject`
/// expansion.
///
/// Properties annotated with `@IgnoredByDTO` do not appear in the generated
/// `Configurable` and `Transferable` structs and are skipped by
/// `init(_:in:)` and `update(using:in:)`. They must have a default value.
///
/// SwiftData's `@Transient` properties are excluded automatically.
///
/// Use it for caches, transient values, and one side of a many-to-many
/// relationship.
@attached(peer)
public macro IgnoredByDTO() = #externalMacro(module: "Tools4SwiftDataMacros", type: "IgnoredByDTO")

// MARK: - End of macro declarations

/// The errors thrown by Tools4SwiftData.
public enum Tools4SwiftDataError: LocalizedError, Equatable {

    /// No model of the expected type has the given identifier.
    case notFound(PersistentIdentifier)

    /// A draft was applied to a model other than the one it was taken from.
    case identifierMismatch(expected: PersistentIdentifier, found: PersistentIdentifier)

    /// A draft that should refer to an existing model has no identifier.
    case missingIdentifier

    /// A required to-one relationship has no identifier in the draft.
    case missingRelationship

    /// A relationship identifier does not match any model of the related type.
    case unresolvedRelationship(PersistentIdentifier)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            String(localized: "error-not-found", bundle: .module)
        case .identifierMismatch:
            String(localized: "error-identifier-mismatch", bundle: .module)
        case .missingIdentifier:
            String(localized: "error-missing-identifier", bundle: .module)
        case .missingRelationship:
            String(localized: "error-missing-relationship", bundle: .module)
        case .unresolvedRelationship:
            String(localized: "error-unresolved-relationship", bundle: .module)
        }
    }
}
