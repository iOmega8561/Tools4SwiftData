//
//  ManagedQuery.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import SwiftUI
import SwiftData

/// A property wrapper that manages a collection of `QueryResult` instances
/// and exposes CRUD operations through a proxy pattern.
///
/// `ManagedQuery` wraps a `SwiftDataManager<Persistable>` to fetch, insert,
/// update, and delete models. It holds a `@State` array of `QueryResult`
/// instances, each of which manages its own draft state.
///
/// The wrapper conforms to `DynamicProperty` and is annotated with `@MainActor`
/// to ensure all state mutations occur on the main thread, which is required
/// by SwiftUI. The `projectedValue` exposes a `QueryProxy` that provides
/// read-only access to the array and a set of async CRUD methods.
///
/// `ManagedQuery` works in conjunction with `QueryResult` to form a complete
/// read-edit-update workflow:
/// 1. `ManagedQuery` fetches data and creates `QueryResult` instances, injecting
///    the `commit` callback into each one.
/// 2. `QueryResult` holds a draft (`configurable`) and an original snapshot.
/// 3. Users edit drafts through `$draft.propertyName` bindings.
/// 4. Commits are triggered individually (`query.commit(item:)`) or in batch,
///    allowing flexible persistence strategies.
///
/// The proxy pattern (`QueryProxy`) prevents direct mutation of the `@State`
/// array from outside the wrapper, ensuring that all CRUD operations go through
/// `SwiftDataManager` for consistency and that the UI remains in sync with
/// the underlying persistence layer.
///
/// - Type Parameter `Persistable`: The persistent model type managed by this
///   query wrapper. Must conform to `SwiftDataPersistable`.
@propertyWrapper @MainActor
public struct ManagedQuery<Persistable: SwiftDataPersistable>: DynamicProperty {
    
    private let dataManager: SwiftDataManager<Persistable>
    
    /// The current collection of query results, including draft states.
    @State
    private var items: [QueryResult<Persistable>] = []
    
    /// Initializes a `ManagedQuery` with a data manager.
    ///
    /// - Parameter dataManager: The `SwiftDataManager` responsible for all
    ///   persistence operations.
    public init(dataManager: SwiftDataManager<Persistable>) {
        self.dataManager = dataManager
    }
    
    /// Read-only access to the query results.
    public var wrappedValue: [QueryResult<Persistable>] {
        items
    }
    
    /// A proxy object that exposes CRUD operations and bindings.
    public var projectedValue: QueryProxy {
        QueryProxy(binding: $items, dataManager: dataManager)
    }
    
    /// A proxy struct that provides read-only access to the array and
    /// async CRUD operations.
    ///
    /// This proxy enforces a controlled mutation pattern: all insertions,
    /// updates, and deletions must go through its methods, which delegate
    /// to `SwiftDataManager` and update the internal `@State` array
    /// accordingly. This prevents race conditions and ensures the UI
    /// stays in sync with the persistence layer.
    @MainActor
    public struct QueryProxy {
        private let binding: Binding<[QueryResult<Persistable>]>
        private let dataManager: SwiftDataManager<Persistable>
        
        fileprivate init(
            binding: Binding<[QueryResult<Persistable>]>,
            dataManager: SwiftDataManager<Persistable>
        ) {
            self.binding = binding
            self.dataManager = dataManager
        }
        
        /// Exposes the internal binding for inline editing in `ForEach`.
        public var elements: Binding<[QueryResult<Persistable>]> { binding }
        
        /// Refreshes the collection by re-fetching from the persistent store.
        ///
        /// This method replaces all existing `QueryResult` instances with fresh
        /// snapshots. In advanced scenarios with complex forms, consider merging
        /// uncommitted drafts instead of a full refresh to avoid losing user edits.
        public func refresh() async throws {
            let fetched = try await dataManager.fetch()
            binding.wrappedValue = fetched.map { QueryResult(original: $0, commit) }
        }
        
        /// Inserts a new draft into the collection.
        ///
        /// The draft is persisted via `SwiftDataManager`, and the resulting
        /// `QueryResult` is appended to the collection without requiring a
        /// full refresh. This provides immediate UI feedback while the
        /// database operation completes in the background.
        ///
        /// - Parameter draft: A validated `ConfigurableType` to insert.
        public func insert(_ draft: Persistable.ConfigurableType) async throws {
            let newlySaved: Persistable.TransferableType = try await dataManager.addItem(draft)
            binding.wrappedValue.append(QueryResult(original: newlySaved, commit))
        }
        
        /// Commits a specific `QueryResult` instance.
        ///
        /// The draft is persisted, and the result is replaced with a fresh
        /// snapshot from the database to reset the draft state and ensure
        /// consistency.
        ///
        /// - Parameter item: The `QueryResult` instance to commit.
        public func commit(item: QueryResult<Persistable>) async throws {
            guard let index = binding.wrappedValue.firstIndex(where: { $0.id == item.id }) else { return }
            let draftToSave = item.wrappedValue
            
            let updated = try await dataManager.updateItem(id: item.id, configurable: draftToSave)
            binding.wrappedValue[index] = QueryResult(original: updated, commit)
        }
        
        /// Commits a `QueryResult` by its identifier.
        ///
        /// - Parameter id: The `PersistentIdentifier` of the item to commit.
        public func commit(id: PersistentIdentifier) async throws {
            guard let index = binding.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
            let draftToSave = binding.wrappedValue[index].wrappedValue
            
            let updated = try await dataManager.updateItem(id: id, configurable: draftToSave)
            binding.wrappedValue[index] = QueryResult(original: updated, commit)
        }
        
        /// Deletes an item by its identifier.
        ///
        /// - Parameter id: The `PersistentIdentifier` of the item to delete.
        public func delete(id: PersistentIdentifier) async throws {
            try await dataManager.deleteItem(id: id)
            binding.wrappedValue.removeAll { $0.id == id }
        }
        
        /// Deletes items at the specified indices.
        ///
        /// - Parameter offsets: The `IndexSet` of items to delete.
        public func delete(at offsets: IndexSet) async throws {
            let idsToDelete = offsets.map { binding.wrappedValue[$0].id }
            for id in idsToDelete {
                try await dataManager.deleteItem(id: id)
            }
            binding.wrappedValue.remove(atOffsets: offsets)
        }
    }
}
