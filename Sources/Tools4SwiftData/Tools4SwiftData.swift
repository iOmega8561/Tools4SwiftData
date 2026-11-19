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

/// A peer macro that marks a property to be excluded from the
/// `DataTransferObject` macro expansion.
///
/// Properties annotated with `@IgnoredByDTO` are ignored during code
/// generation — they will not appear in the generated `Configurable`
/// or `Transferable` structs, and will be skipped in `init(_:)` and
/// `update(using:)` implementations.
///
/// This is useful for private state, transient values, or properties
/// that are managed separately from the data transfer pipeline.
@attached(peer)
public macro IgnoredByDTO() = #externalMacro(module: "Tools4SwiftDataMacros", type: "IgnoredByDTO")

// MARK: - End of macro declarations

public enum Tools4SwiftData: LocalizedError {
    case internalError
    
    public var errorDescription: String? {
        
        switch self {
        case .internalError:
            return String(localized: "error-swiftdata", bundle: .module)
        }
    }
}
