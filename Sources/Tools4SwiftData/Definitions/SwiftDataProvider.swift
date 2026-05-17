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

/// The SwiftDataProvider class
///
/// @brief
///    Struct acting as the main provider for the `SwiftData` shared persistence container.
///    The associated `persistenceContainer` property is an instance of the sendable `ModelContainer` class.
///
///    - Note: This approach works because while `ModelContainer` is, in fact, `Sendable`, `ModelContext` is not,
///    so we just leave it to the `SwiftDataManager`, that will create it's own context while keeping it concurrency safe.
public struct SwiftDataProvider<Persistable: SwiftDataPersistable>: Sendable {

    /// This property holds the `ModelContainer` instance.
    public let persistenceContainer: ModelContainer
    
    /// Creates a `SwiftDataManager` instance using the shared `ModelContainer`.
    ///
    /// - Returns: A `SwiftDataManager` instance configured using the above persistence container.
    ///
    /// - Note: This method simplifies access to the data manager, ensuring all operations
    ///   are consistent with the shared persistence container.
    public func createManager() -> SwiftDataManager<Persistable> {
        return SwiftDataManager(modelContainer: persistenceContainer)
    }
    
    /// Initializes the `SwiftDataProvider` with a specified file location for data storage.
    ///
    /// - Parameters:
    ///   - location: The location URL where the persistent store file will be created. **Should point to a directory**.
    ///   - migrationPlan: The schema migration plan type, if provided. Defaults to nil
    /// - Throws: An error if the `ModelContainer` initialization fails.
    ///
    /// - Important: The initializer is public to allow external creation of `SwiftDataProvider` instances,
    ///   but proper error handling should be implemented to manage initialization failures.
    /// - Note: This initializer uses the associated `Persistable.self` type to compute the database file name.
    ///   **Renaming the `Persistable` class will cause `ModelConfiguration` to point to a different location on disk.**
    public init(
        writingAt location: URL,
        migrationPlan: SchemaMigrationPlan.Type? = nil
    ) throws {
        let name = String(describing: Persistable.self)
        
        let modelConfiguration = ModelConfiguration(
            url: location.appendingPathComponent(name + ".sqlite")
        )
        
        self.persistenceContainer = try ModelContainer(
            for: Persistable.self,
            migrationPlan: migrationPlan,
            configurations: modelConfiguration
        )
    }
}
