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

/// A macro that expands an `@Model` class to automatically generate
/// `Transferable` and `Configurable` structs, along with the required
/// `SwiftDataPersistable` protocol conformances.
///
/// When applied to a class annotated with `@Model`, this macro:
/// - Generates a `Transferable` struct (immutable snapshot) for data transfer
/// - Generates a `Configurable` struct (mutable draft) for in-place editing
/// - Injects `init(_ configurableModel:)` and `update(using:)` methods
/// - Adds `ConfigurableType` and `TransferableType` type aliases
/// - Attaches a `SwiftDataPersistable` conformance extension
///
/// The macro automatically handles relationship arrays and scalar properties,
/// generating appropriate conversion logic between `Persistable`, `Configurable`,
/// and `Transferable` types.
///
/// - Note: All property types in the annotated `@Model` class must conform
///   to `Hashable` and `Equatable` for the generated code to compile.
@attached(member, names:
    named(Transferable),
    named(Configurable),
    named(update),
    named(init),             // <--- Mancava questo
    named(ConfigurableType), // <--- Mancava questo
    named(TransferableType)  // <--- Mancava questo
)
@attached(extension, conformances: SwiftDataPersistable)
public macro DataTransferObject() = #externalMacro(module: "Tools4SwiftDataMacros", type: "DataTransferObject")

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
