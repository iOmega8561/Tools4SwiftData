//
//  Copyright 2025 Giuseppe Rocco
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
//  SwiftDataConfigurable.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 31/12/24.
//

import Foundation
import SwiftData

/// A protocol that represents the mutable draft of a persistable model.
///
/// A draft is either created from scratch, to insert a new model, or from a
/// `TransferableType` snapshot, to update an existing one. In the latter case
/// `persistentModelID` identifies the model the draft refers to.
///
/// Drafts are validated before being persisted. The default `validate(for:)`
/// accepts every draft; to add rules, implement it in an extension:
///
/// ```swift
/// extension Item.Configurable {
///     func validate(for scope: SwiftDataValidationScope) throws {
///         guard !name.isEmpty else { throw ItemError.emptyName }
///     }
/// }
/// ```
public protocol SwiftDataConfigurable: Hashable, Sendable {

    associatedtype PersistableType: SwiftDataPersistable where PersistableType.ConfigurableType == Self

    associatedtype TransferableType: SwiftDataTransferable where PersistableType.TransferableType == TransferableType

    /// The identifier of the model this draft refers to, `nil` for new models.
    var persistentModelID: PersistentIdentifier? { get }

    /// Validates the draft.
    ///
    /// - Parameter scope: Whether the draft is about to create or update a model.
    /// - Throws: An error describing why the draft is not valid.
    func validate(for scope: SwiftDataValidationScope) throws

    /// Initializes a draft from a snapshot of an existing model.
    ///
    /// - Parameter transferable: The snapshot to copy.
    init(_ transferable: TransferableType)
}

extension SwiftDataConfigurable {

    /// Accepts every draft. Implement `validate(for:)` on the conforming type
    /// to add validation rules.
    public func validate(for scope: SwiftDataValidationScope) throws {}
}
