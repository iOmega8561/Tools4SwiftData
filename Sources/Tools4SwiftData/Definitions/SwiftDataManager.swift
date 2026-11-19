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
//  SwiftDataManager.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 05/10/24.
//

import Foundation
import SwiftData

/// The actor responsible for every read and write on a `SwiftData` store
/// for one persistable type.
///
/// `SwiftDataManager` owns a `ModelContext` that never leaves the actor:
/// models are read and written inside it, and only `Sendable` snapshots
/// (`Transferable`) and drafts (`Configurable`) cross its boundary.
///
/// Every write either succeeds and is saved, or fails and is rolled back:
/// a failed operation never leaves pending changes in the context that a
/// later save would persist by accident.
///
/// - Important: A `@ModelActor` runs its work on the thread its context was
///   created on. A manager created from the main actor therefore does its
///   work on the main thread. Use
///   `SwiftDataProvider.createBackgroundManager(for:)` to get a manager that
///   works off the main thread.
@ModelActor
public final actor SwiftDataManager<Persistable: SwiftDataPersistable> {

    // MARK: - Type Aliases

    /// The snapshot type of `Persistable`.
    public typealias Transferable = Persistable.TransferableType

    /// The draft type of `Persistable`.
    public typealias Configurable = Persistable.ConfigurableType

    // MARK: - Fetching Data

    /// Fetches every model.
    ///
    /// - Returns: The snapshots of all the models.
    /// - Throws: An error if the fetch fails.
    public func fetch() throws -> [Transferable] {
        try fetch(FetchDescriptor())
    }

    /// Fetches the models matching a descriptor.
    ///
    /// Build the descriptor right before the call: a descriptor created on
    /// the spot can be sent to the actor even where `FetchDescriptor` is not
    /// `Sendable`, while one stored and reused elsewhere cannot.
    ///
    /// - Parameter descriptor: The predicate, sorting and limits of the fetch.
    /// - Returns: The snapshots of the matching models.
    /// - Throws: An error if the fetch fails.
    public func fetch(_ descriptor: FetchDescriptor<Persistable>) throws -> [Transferable] {
        try modelContext.fetch(descriptor).map { Transferable($0) }
    }

    /// Fetches a single model by identifier.
    ///
    /// - Parameter id: The identifier of the model.
    /// - Returns: The snapshot of the model, or `nil` if it does not exist.
    /// - Throws: An error if the fetch fails.
    public func fetch(id: PersistentIdentifier) throws -> Transferable? {
        try modelContext.existingModel(for: id, as: Persistable.self).map { Transferable($0) }
    }

    // MARK: - Inserting Data

    /// Inserts a new model built from a draft.
    ///
    /// - Parameters:
    ///   - configurable: The draft of the new model.
    ///   - skipValidation: Skips the validation of the draft itself. Nested
    ///     drafts of to-many relationships are validated anyway.
    /// - Returns: The snapshot of the saved model. Its identifier is the
    ///   permanent one assigned by the save.
    /// - Throws: A validation error, a `Tools4SwiftDataError`, or an error
    ///   from the store. Nothing is saved when an error is thrown.
    /// - Important: Setting `skipValidation` to `true` is meant for advanced
    ///   scenarios only.
    @discardableResult
    public func insert(_ configurable: Configurable, skipValidation: Bool = false) throws -> Transferable {
        try persist {
            if !skipValidation {
                try configurable.validate(for: .creation)
            }
            let model = try Persistable(configurable, in: modelContext)
            modelContext.insert(model)
            return model
        }
    }

    // MARK: - Updating Data

    /// Applies a draft to an existing model.
    ///
    /// - Parameters:
    ///   - id: The identifier of the model to update.
    ///   - configurable: The draft to apply. If it carries an identifier, it
    ///     must be `id`.
    /// - Returns: The snapshot of the updated model.
    /// - Throws: `Tools4SwiftDataError.notFound` if the model does not exist,
    ///   `Tools4SwiftDataError.identifierMismatch` if the draft belongs to a
    ///   different model, a validation error or an error from the store.
    ///   Nothing is saved when an error is thrown.
    @discardableResult
    public func update(id: PersistentIdentifier, with configurable: Configurable) throws -> Transferable {
        if let draftID = configurable.persistentModelID, draftID != id {
            throw Tools4SwiftDataError.identifierMismatch(expected: id, found: draftID)
        }

        return try persist {
            let model = try existingModel(id: id)
            try configurable.validate(for: .update)
            try model.update(using: configurable, in: modelContext)
            return model
        }
    }

    /// Updates an existing model with a closure.
    ///
    /// The closure runs inside the actor and receives the model itself: use
    /// it for changes a draft cannot express.
    ///
    /// - Parameters:
    ///   - id: The identifier of the model to update.
    ///   - handler: The closure that modifies the model.
    /// - Returns: The snapshot of the updated model.
    /// - Throws: `Tools4SwiftDataError.notFound` if the model does not exist,
    ///   the error thrown by `handler` or an error from the store. Nothing is
    ///   saved when an error is thrown.
    @discardableResult
    public func update(
        id: PersistentIdentifier,
        handler: @Sendable (Persistable) throws -> Void
    ) throws -> Transferable {
        try persist {
            let model = try existingModel(id: id)
            try handler(model)
            return model
        }
    }

    // MARK: - Deleting Data

    /// Deletes a model.
    ///
    /// - Parameters:
    ///   - id: The identifier of the model to delete.
    ///   - ignoreNonExistent: Whether deleting a model that does not exist is
    ///     a no-op (the default) or an error.
    /// - Throws: `Tools4SwiftDataError.notFound` if the model does not exist
    ///   and `ignoreNonExistent` is `false`, or an error from the store.
    public func delete(id: PersistentIdentifier, ignoreNonExistent: Bool = true) throws {
        guard let model = try modelContext.existingModel(for: id, as: Persistable.self) else {
            if ignoreNonExistent { return }
            throw Tools4SwiftDataError.notFound(id)
        }

        do {
            modelContext.delete(model)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Helpers

    /// Looks up the model to work on, failing if it does not exist.
    private func existingModel(id: PersistentIdentifier) throws -> Persistable {
        guard let model = try modelContext.existingModel(for: id, as: Persistable.self) else {
            throw Tools4SwiftDataError.notFound(id)
        }
        return model
    }

    /// Runs a write, saves it and returns the snapshot of the written model.
    ///
    /// The snapshot is taken after the save, so it carries the permanent
    /// identifier of a newly inserted model. On any error the context is
    /// rolled back.
    private func persist(_ write: () throws -> Persistable) throws -> Transferable {
        do {
            let model = try write()
            try modelContext.save()
            return Transferable(model)
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
