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
///    This class is purposed to be a provider for the `SwiftData` shared persistence container.
///    Using this, we have the foundation to create a `ModelContainer` using structured concurrency.
///
///    - Note: This approach works because while `ModelContainer` is, in fact, `Sendable`, `ModelContext` is not,
///    so we just leave it to the `SwiftDataManager`, that will create it's own while keeping it concurrency safe
public struct SwiftDataProvider<Transferable: SwiftDataTransferable>: Sendable {

    /// This property holds the `ModelContainer` instance.
    public let persistenceContainer: ModelContainer
    
    /// Creates a `SwiftDataManager` instance using the shared `ModelContainer`.
    ///
    /// - Returns: A `SwiftDataManager` instance configured using the above persistence container.
    ///
    /// - Note: This method simplifies access to the data manager, ensuring all operations
    ///   are consistent with the shared persistence container.
    public func managerCreator() -> SwiftDataManager<Transferable> {
        return SwiftDataManager(modelContainer: persistenceContainer)
    }
    
    /// Initializes the `SwiftDataProvider` with a specified file location for data storage.
    ///
    /// - Parameters:
    ///   - writeDataStoreAt: The directory where the persistent store file will be created.
    ///   - migrationPlan: The schema migration plan type, if provided. Defaults to nil
    /// - Throws: An error if the `ModelContainer` initialization fails.
    ///
    /// - Important: The initializer is public to allow external creation of `SwiftDataProvider` instances,
    ///   but proper error handling should be implemented to manage initialization failures.
    public init(writeDataStoreAt: URL, migrationPlan: SchemaMigrationPlan.Type? = nil) throws {
        
        let fileName = Transferable.PersistableType.filePrefix + ".sqlite"
        
        let modelConfiguration = ModelConfiguration(
            url: writeDataStoreAt.appendingPathComponent(fileName)
        )
        
        self.persistenceContainer = try ModelContainer(
            for: Transferable.PersistableType.self,
            migrationPlan: migrationPlan,
            configurations: modelConfiguration
        )
    }
}
