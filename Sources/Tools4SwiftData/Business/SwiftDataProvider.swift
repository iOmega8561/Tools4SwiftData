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
///    so we just leave it to the `SwiftDataManager`, that will craete it's own while keeping it concurrency safe
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
    /// - Parameter writeDataStoreAt: The directory where the persistent store file will be created.
    /// - Throws: An error if the `ModelContainer` initialization fails.
    ///
    /// - Important: The initializer is public to allow external creation of `SwiftDataProvider` instances,
    ///   but proper error handling should be implemented to manage initialization failures.
    public init(writeDataStoreAt: URL) throws {
        
        let fileName = Transferable.PersistableType.filePrefix + ".sqlite"
        
        let modelConfiguration = ModelConfiguration(
            url: writeDataStoreAt.appendingPathComponent(fileName)
        )
        
        self.persistenceContainer = try ModelContainer(
            for: Transferable.PersistableType.self,
            configurations: modelConfiguration
        )
    }
}
