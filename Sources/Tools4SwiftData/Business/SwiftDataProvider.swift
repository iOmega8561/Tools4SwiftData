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
///    Using a `@MainActor` pinned, singleton, instance of this class, we basically have the foundation to
///    Create a `ModelContext` whevener it's needed, using the same `ModelContainer`.
///
///    - Important: Sendable conformation is achieved through `@MainActor` pinning of the singleton instance.
public struct SwiftDataProvider<Transferable: SwiftDataTransferable>: Sendable {

    /// The `ModelContainer` computed property. Initializes the `ModelConfiguration` and tries to
    /// create the shared model container. Presents the exception, eventually, and terminates the application as needed.
    ///
    /// - Important: `@MainActor` pinning is necessary since the closure is synchronous within the main thread.
    public let persistenceContainer: ModelContainer
    
    /// A useful method to generate a `SwiftDataManager` instance using the shared model container.
    public func managerCreator() -> SwiftDataManager<Transferable> {
        return SwiftDataManager(modelContainer: persistenceContainer)
    }
    
    /// The initializer needs to be private so that only the shared instance can be used.
    ///
    /// - Important: `@MainActor` pinning is necessary because the static property (which uses this init()), is also `@MainActor` pinned.
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
