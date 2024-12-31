//
//  SwiftDataManager.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 05/10/24.
//

import Foundation

import SwiftData

/// The actor responsible for managing read/write operations on the `SwiftData` datastore.
///
/// `SwiftDataManager` provides concurrency-safe methods to perform CRUD (Create, Read, Update, Delete)
/// operations on the `SwiftData` datastore, ensuring that data integrity is maintained across
/// multiple contexts within the app.
///
/// - Note: This `@ModelActor` leverages Swift's strict concurrency checking to ensure thread-safety
///   when accessing the datastore.
/// - Warning: All methods within this actor should be called asynchronously to prevent concurrency issues.
@ModelActor public final actor SwiftDataManager<Transferable: SwiftDataTransferable> {
    
    // MARK: - Type Aliases
        
    /// The associated persistable type that conforms to `SwiftDataPersistent`, derived from the
    /// specified `Transferable` type.
    public typealias Persistable = Transferable.PersistableType
    
    /// The configurable type that conforms to `SwiftDataConfigurable`, used to initialize `Persistable`.
    public typealias Configurable = Persistable.ConfigurableType
    
    // MARK: - Fetching Data
        
    /// Retrieves all instances of the `Persistable` type from the datastore and maps them to `Transferable` objects.
    ///
    /// - Returns: An array of `Transferable` objects representing the data stored in the datastore.
    /// - Throws: An error if fetching from the datastore fails.
    ///
    /// This method provides a bulk fetch operation to retrieve all items from the datastore, converting
    /// each retrieved item into a transferable form for use in other app contexts.
    public func fetch() throws -> [Transferable] {
        
        let fetchDescriptor = FetchDescriptor<Persistable>()
        
        return try modelContext.fetch(fetchDescriptor)
            .map { item in
                Transferable(item)
            }
    }
    
    /// Fetches a single instance of `Persistable` by its identifier and returns it as a `Transferable` object.
    ///
    /// - Parameters:
    ///   - id: The `PersistentIdentifier` for the model instance to be fetched.
    /// - Returns: A `Transferable` instance if the model is found; otherwise, `nil`.
    ///
    /// This method performs a lookup for a single data model by its unique identifier, transforming it
    /// into a transferable representation if found.
    public func fetch(id: PersistentIdentifier) -> Transferable? {
        
        guard let item = self[id, as: Persistable.self] else {
            return nil
        }
        
        return Transferable(item)
    }
    
    // MARK: - Adding Data
        
    /// Adds a new item to the datastore using the provided configurable model.
    ///
    /// - Parameters:
    ///   - configurable: An instance of `Configurable` containing the configuration data for the new model.
    /// - Returns: The `PersistentIdentifier` of the newly inserted model.
    /// - Throws: An error if saving to the datastore fails.
    /// - Important: The `@discardableResult` attribute suppresses warnings if the return value is unused.
    ///
    /// This method takes a validated `Configurable` object, creates a `Persistable` model from it, inserts
    /// the model into the datastore, and commits the changes.
    @discardableResult
    public func addItem(_ configurable: Configurable) throws -> PersistentIdentifier {
        
        try configurable.validate()
        let item = Persistable(configurable)
        
        modelContext.insert(item)
        try modelContext.save()
        
        return item.persistentModelID
    }
    
    /// Adds a new item to the datastore and returns it as a `Transferable` object.
    ///
    /// - Parameters:
    ///   - configurable: An instance of `Configurable` containing the configuration data for the new model.
    /// - Returns: A `Transferable` instance representing the newly added model.
    /// - Throws: An error if saving to the datastore fails.
    ///
    /// This method provides a convenience function to add a new item to the datastore and
    /// immediately receive it back as a transferable data transfer object.
    public func addItem(_ configurable: Configurable) throws -> Transferable {
        
        try configurable.validate()
        let item = Persistable(configurable)
        
        modelContext.insert(item)
        try modelContext.save()
        
        return Transferable(item)
    }
    
    // MARK: - Deleting Data
        
    /// Deletes an item from the datastore by its identifier.
    ///
    /// - Parameters:
    ///   - id: The `PersistentIdentifier` of the model instance to delete.
    ///   - ignoreNonExistent: A Boolean value that determines whether to ignore the deletion attempt if the item does not exist.
    /// - Throws: A `Tools4SwiftData.internalError` if the item does not exist and `ignoreNonExistent` is set to `false`.
    ///
    /// This method safely removes an item from the datastore by its unique identifier, optionally
    /// throwing an error if the item does not exist and `ignoreNonExistent` is `false`.
    public func deleteItem(id: PersistentIdentifier, ignoreNonExistent: Bool = true) throws {
        
        guard let item = self[id, as: Persistable.self] else {
            if !ignoreNonExistent {
                throw Tools4SwiftData.internalError
            }
            
            return
        }
        
        modelContext.delete(item)
        try modelContext.save()
    }
    
    // MARK: - Updating Data
        
    /// Updates a specific item in the datastore.
    ///
    /// - Parameters:
    ///   - id: The `PersistentIdentifier` of the model instance to update.
    ///   - handler: A `@Sendable` closure that modifies the given `Persistable` model instance.
    /// - Returns: A `Transferable` instance representing the updated model.
    /// - Throws: A `Tools4SwiftData.internalError` if the item is not found or if saving fails.
    /// - Important: The `@discardableResult` attribute suppresses warnings if the return value is unused.
    ///
    /// This method enables controlled updates on a specified data model. A closure provides
    /// flexibility for modifying fields on the model, and changes are committed to the datastore
    /// after the closure completes.
    @discardableResult
    public func updateItem(
        id: PersistentIdentifier,
        handler: @Sendable (Persistable) -> Void
    ) throws -> Transferable {
        
        guard let item = self[id, as: Persistable.self] else {
            throw Tools4SwiftData.internalError
        }
        
        handler(item)
        try modelContext.save()
        
        return Transferable(item)
    }
}
