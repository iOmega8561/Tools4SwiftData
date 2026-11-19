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
//  SwiftDataPersistable.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 31/12/24.
//

import SwiftData

/// A protocol that represents a model capable of persisting data.
///
/// A persistable model is created from, and updated with, a draft of its
/// `ConfigurableType`, and is read through snapshots of its `TransferableType`.
/// The `@DataTransferObject` macro generates the whole conformance; it can
/// also be implemented by hand.
///
/// Both requirements receive the `ModelContext` that owns the operation, so
/// that relationships expressed as identifiers in the drafts can be resolved
/// to models of the same context.
public protocol SwiftDataPersistable: PersistentModel {

    /// The mutable draft type used to create and update this model.
    associatedtype ConfigurableType: SwiftDataConfigurable where ConfigurableType.PersistableType == Self

    /// The immutable snapshot type used to read this model across isolation domains.
    associatedtype TransferableType: SwiftDataTransferable where TransferableType.PersistableType == Self

    /// Initializes the model from a draft.
    ///
    /// The new model is not inserted into `context`: the caller decides when
    /// to insert it. Related models created along the way are inserted, so the
    /// whole graph becomes persistent together with this model.
    ///
    /// - Parameters:
    ///   - configurable: The draft to build the model from.
    ///   - context: The context used to resolve relationships.
    /// - Throws: An error if a relationship cannot be resolved.
    init(_ configurable: ConfigurableType, in context: ModelContext) throws

    /// Applies a draft to the model.
    ///
    /// Implementations decide which properties to update; the generated
    /// implementation updates every property that changed.
    ///
    /// - Parameters:
    ///   - configurable: The draft to apply.
    ///   - context: The context used to resolve relationships.
    /// - Throws: An error if a relationship cannot be resolved.
    func update(using configurable: ConfigurableType, in context: ModelContext) throws
}
