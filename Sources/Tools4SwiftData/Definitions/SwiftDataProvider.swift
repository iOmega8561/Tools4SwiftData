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
//  SwiftDataProvider.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 17/07/24.
//

import Foundation
import SwiftData

/// The owner of the `ModelContainer` shared by the app's managers.
///
/// A provider wraps one container, which can hold any number of model types
/// in a single store: relationships between them work as usual. Managers are
/// created per persistable type and all share the same container.
///
/// `ModelContainer` is `Sendable` while `ModelContext` is not, so the provider
/// can be passed around freely and each `SwiftDataManager` creates and keeps
/// its own context.
public struct SwiftDataProvider: Sendable {

    /// The shared container.
    public let persistenceContainer: ModelContainer

    /// Wraps an existing container.
    ///
    /// Use this initializer when the container needs a configuration the
    /// other initializers do not expose (CloudKit, App Groups, multiple
    /// configurations...).
    public init(container: ModelContainer) {
        self.persistenceContainer = container
    }

    /// Creates a provider whose store lives in a file.
    ///
    /// - Parameters:
    ///   - schema: The model types of the store. Use `Schema(versionedSchema:)`
    ///     together with `migrationPlan` for versioned schemas.
    ///   - storeName: The name of the store file, without extension. It is the
    ///     identity of the store on disk: changing it points the provider to a
    ///     new, empty store.
    ///   - directory: The directory that contains the store file.
    ///   - migrationPlan: The migration plan of the schema, if any.
    /// - Throws: An error if the container cannot be created.
    public init(
        schema: Schema,
        storeName: String,
        in directory: URL,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil
    ) throws {
        let configuration = ModelConfiguration(
            schema: schema,
            url: directory.appendingPathComponent(storeName + ".sqlite")
        )

        self.persistenceContainer = try ModelContainer(
            for: schema,
            migrationPlan: migrationPlan,
            configurations: [configuration]
        )
    }

    /// Creates a provider whose store lives in a file.
    ///
    /// - Parameters:
    ///   - types: The model types of the store. Related types are included
    ///     automatically.
    ///   - storeName: The name of the store file, without extension.
    ///   - directory: The directory that contains the store file.
    /// - Throws: An error if the container cannot be created.
    public init(
        for types: [any PersistentModel.Type],
        storeName: String,
        in directory: URL
    ) throws {
        try self.init(schema: Schema(types), storeName: storeName, in: directory)
    }

    /// Creates a provider whose store lives only in memory, for tests and
    /// SwiftUI previews.
    ///
    /// - Parameter types: The model types of the store.
    /// - Throws: An error if the container cannot be created.
    public static func inMemory(for types: [any PersistentModel.Type]) throws -> SwiftDataProvider {
        let schema = Schema(types)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return SwiftDataProvider(container: try ModelContainer(for: schema, configurations: [configuration]))
    }

    /// Creates a manager for a persistable type.
    ///
    /// - Important: The manager works on the thread this method is called
    ///   from: called from the main actor, it works on the main thread. Use
    ///   `createBackgroundManager(for:)` for heavy work.
    public func createManager<Persistable: SwiftDataPersistable>(
        for type: Persistable.Type = Persistable.self
    ) -> SwiftDataManager<Persistable> {
        SwiftDataManager(modelContainer: persistenceContainer)
    }

    /// Creates a manager for a persistable type that works off the main thread.
    ///
    /// The manager is created from a detached task, so its context is not
    /// bound to the caller's thread.
    public func createBackgroundManager<Persistable: SwiftDataPersistable>(
        for type: Persistable.Type = Persistable.self
    ) async -> SwiftDataManager<Persistable> {
        let container = persistenceContainer
        return await Task.detached {
            SwiftDataManager<Persistable>(modelContainer: container)
        }.value
    }
}
