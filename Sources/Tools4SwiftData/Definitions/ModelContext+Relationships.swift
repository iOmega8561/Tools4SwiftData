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
//  ModelContext+Relationships.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import Foundation
import SwiftData

/// What happens to the models removed from a to-many relationship when a
/// draft is applied with `update(using:in:)`.
///
/// Pass it to `@DataTransferObject(orphans:)`.
public enum OrphanPolicy: Sendable {

    /// The models are only removed from the relationship and stay in the
    /// store. Their fate is left to the relationship's delete rule and to the
    /// inverse relationship, if any. This is the default, and the only safe
    /// choice for many-to-many relationships or shared models.
    case detach

    /// The models are deleted from the context.
    case delete
}

// MARK: - Relationship resolution

extension ModelContext {

    /// Looks up a model by identifier.
    ///
    /// Models already registered in the context are returned without hitting
    /// the store. Unlike `model(for:)`, an identifier that does not match any
    /// stored model returns `nil` instead of a placeholder.
    ///
    /// - Parameters:
    ///   - id: The identifier of the model.
    ///   - type: The expected model type.
    /// - Returns: The model, or `nil` if no model of that type has that identifier.
    public func existingModel<Model: PersistentModel>(
        for id: PersistentIdentifier,
        as type: Model.Type = Model.self
    ) throws -> Model? {
        if let registered: Model = registeredModel(for: id) {
            return registered
        }

        var descriptor = FetchDescriptor<Model>(
            predicate: #Predicate { $0.persistentModelID == id }
        )
        descriptor.fetchLimit = 1

        return try fetch(descriptor).first
    }

    /// Resolves an optional to-one relationship from its identifier.
    ///
    /// - Returns: `nil` when `id` is `nil`, the related model otherwise.
    /// - Throws: An error if `id` does not identify an existing model.
    public func resolveRelationship<Model: PersistentModel>(
        _ id: PersistentIdentifier?,
        as type: Model.Type
    ) throws -> Model? {
        guard let id else { return nil }

        guard let model = try existingModel(for: id, as: type) else {
            throw Tools4SwiftData.internalError
        }
        return model
    }

    /// Resolves a required to-one relationship from its identifier.
    ///
    /// - Throws: An error if `id` is `nil` or does not identify an existing model.
    public func resolveRequiredRelationship<Model: PersistentModel>(
        _ id: PersistentIdentifier?,
        as type: Model.Type
    ) throws -> Model {
        guard let model = try resolveRelationship(id, as: type) else {
            throw Tools4SwiftData.internalError
        }
        return model
    }
}

// MARK: - To-many reconciliation

extension ModelContext {

    /// Computes the new content of a to-many relationship from a list of drafts.
    ///
    /// For every draft, in order:
    /// - a draft with a `persistentModelID` already in `current` updates that
    ///   model in place;
    /// - a draft with a `persistentModelID` not in `current` (a model moved
    ///   from another relationship) is looked up in the context and updated;
    /// - a draft without `persistentModelID` becomes a new model, inserted
    ///   into the context.
    ///
    /// Every draft is validated before being applied. The models of `current`
    /// that no draft refers to are orphans: they are deleted when `orphans` is
    /// `.delete` and left untouched otherwise.
    ///
    /// - Parameters:
    ///   - current: The current content of the relationship.
    ///   - drafts: The desired content of the relationship.
    ///   - orphans: The policy for the models that leave the relationship.
    /// - Returns: The models to assign to the relationship, in draft order.
    /// - Throws: A validation error, or an error if a draft refers to a model
    ///   that does not exist.
    public func reconcile<Element: SwiftDataPersistable>(
        _ current: [Element],
        with drafts: [Element.ConfigurableType],
        orphans: OrphanPolicy
    ) throws -> [Element] {

        var remaining = Dictionary(
            current.map { ($0.persistentModelID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var result: [Element] = []
        result.reserveCapacity(drafts.count)

        for draft in drafts {
            guard let id = draft.persistentModelID else {
                try draft.validate(for: .creation)
                let model = try Element(draft, in: self)
                insert(model)
                result.append(model)
                continue
            }

            try draft.validate(for: .update)

            let model: Element
            if let existing = remaining.removeValue(forKey: id) {
                model = existing
            } else if let moved = try existingModel(for: id, as: Element.self) {
                model = moved
            } else {
                throw Tools4SwiftData.internalError
            }

            try model.update(using: draft, in: self)
            result.append(model)
        }

        if orphans == .delete {
            for orphan in remaining.values {
                delete(orphan)
            }
        }

        return result
    }

    /// Computes the new content of an optional to-many relationship.
    ///
    /// A `nil` list of drafts empties the relationship (every current model
    /// is an orphan); otherwise this behaves like the non-optional overload.
    public func reconcile<Element: SwiftDataPersistable>(
        _ current: [Element]?,
        with drafts: [Element.ConfigurableType]?,
        orphans: OrphanPolicy
    ) throws -> [Element]? {

        guard let drafts else {
            if orphans == .delete {
                for orphan in current ?? [] {
                    delete(orphan)
                }
            }
            return nil
        }

        return try reconcile(current ?? [], with: drafts, orphans: orphans)
    }
}
