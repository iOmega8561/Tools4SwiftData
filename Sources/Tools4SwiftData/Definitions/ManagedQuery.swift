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
//  ManagedQuery.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import Foundation
import SwiftUI
import SwiftData

/// A property wrapper that holds a collection of `QueryResult` values and
/// exposes CRUD operations through a proxy.
///
/// The collection starts empty: load it with `refresh()`, typically from a
/// `.task` modifier.
///
/// ```swift
/// struct ItemList: View {
///     @ManagedQuery var items: [QueryResult<Item>]
///
///     init(manager: SwiftDataManager<Item>) {
///         _items = ManagedQuery(dataManager: manager, sortBy: [SortDescriptor(\.name)])
///     }
///
///     var body: some View {
///         List(items) { ItemRow(result: $0) }
///             .task { try? await $items.refresh() }
///     }
/// }
/// ```
///
/// The array itself is read-only: insertions, commits and deletions go
/// through `QueryProxy` (`$items`), which persists them with
/// `SwiftDataManager` and then updates the array, so the UI always mirrors
/// the store.
@propertyWrapper @MainActor
public struct ManagedQuery<Persistable: SwiftDataPersistable>: DynamicProperty {

    private let dataManager: SwiftDataManager<Persistable>
    private let predicate: Predicate<Persistable>?
    private let sortBy: [SortDescriptor<Persistable>]

    @State
    private var items: [QueryResult<Persistable>] = []

    /// Initializes a `ManagedQuery`.
    ///
    /// - Parameters:
    ///   - dataManager: The manager that performs every persistence operation.
    ///   - filter: The predicate the items must match. All items by default.
    ///   - sortBy: The order of the items after a `refresh()`. Items inserted
    ///     later are appended at the end until the next refresh.
    public init(
        dataManager: SwiftDataManager<Persistable>,
        filter: Predicate<Persistable>? = nil,
        sortBy: [SortDescriptor<Persistable>] = []
    ) {
        self.dataManager = dataManager
        self.predicate = filter
        self.sortBy = sortBy
    }

    /// The items, read-only.
    public var wrappedValue: [QueryResult<Persistable>] {
        items
    }

    /// The proxy that exposes the CRUD operations.
    public var projectedValue: QueryProxy {
        QueryProxy(binding: $items, dataManager: dataManager, predicate: predicate, sortBy: sortBy)
    }

    /// The CRUD operations of a `ManagedQuery`.
    ///
    /// Every operation persists through `SwiftDataManager` first and updates
    /// the array only on success. Indices are always recomputed after the
    /// persistence call: other operations may have changed the array while
    /// it was suspended.
    @MainActor
    public struct QueryProxy {

        private let binding: Binding<[QueryResult<Persistable>]>
        private let dataManager: SwiftDataManager<Persistable>
        private let predicate: Predicate<Persistable>?
        private let sortBy: [SortDescriptor<Persistable>]

        fileprivate init(
            binding: Binding<[QueryResult<Persistable>]>,
            dataManager: SwiftDataManager<Persistable>,
            predicate: Predicate<Persistable>?,
            sortBy: [SortDescriptor<Persistable>]
        ) {
            self.binding = binding
            self.dataManager = dataManager
            self.predicate = predicate
            self.sortBy = sortBy
        }

        /// Reloads the items from the store.
        ///
        /// Views that installed a `QueryResult` keep their uncommitted
        /// changes; drafts without changes show the reloaded data.
        public func refresh() async throws {
            let descriptor = FetchDescriptor(predicate: predicate, sortBy: sortBy)
            let fetched = try await dataManager.fetch(descriptor)
            binding.wrappedValue = fetched.map(makeResult)
        }

        /// Persists a new item and appends it to the array.
        ///
        /// - Parameter draft: The draft of the new item.
        public func insert(_ draft: Persistable.ConfigurableType) async throws {
            let saved = try await dataManager.insert(draft)
            binding.wrappedValue.append(makeResult(saved))
        }

        /// Commits the draft of an item.
        ///
        /// Pass the `QueryResult` installed on the editing view: it is the
        /// only instance that sees the user's changes. On success its draft
        /// is reset, so it follows the saved snapshot.
        ///
        /// - Parameter item: The item to commit.
        public func commit(item: QueryResult<Persistable>) async throws {
            let updated = try await dataManager.update(id: item.id, with: item.wrappedValue)
            replace(with: updated)
            item.reset()
        }

        /// Commits a draft obtained elsewhere, for instance from a form that
        /// does not use `QueryResult`.
        ///
        /// - Parameter draft: The draft to commit. It must refer to an
        ///   existing item.
        /// - Throws: `Tools4SwiftDataError.missingIdentifier` if the draft has
        ///   no identifier, or any error from `SwiftDataManager.update(id:with:)`.
        public func commit(draft: Persistable.ConfigurableType) async throws {
            guard let id = draft.persistentModelID else {
                throw Tools4SwiftDataError.missingIdentifier
            }
            let updated = try await dataManager.update(id: id, with: draft)
            replace(with: updated)
        }

        /// Deletes an item.
        ///
        /// - Parameter id: The identifier of the item to delete.
        public func delete(id: PersistentIdentifier) async throws {
            try await dataManager.delete(id: id)
            binding.wrappedValue.removeAll { $0.id == id }
        }

        /// Deletes the items at the given positions, as reported by
        /// `onDelete`.
        ///
        /// The positions are resolved to identifiers before the first
        /// deletion. If a deletion fails, the items deleted so far are
        /// removed from the array and the error is thrown.
        ///
        /// - Parameter offsets: The positions of the items to delete.
        public func delete(at offsets: IndexSet) async throws {
            let ids = offsets.map { binding.wrappedValue[$0].id }
            for id in ids {
                try await delete(id: id)
            }
        }

        // MARK: - Helpers

        private func makeResult(_ transferable: Persistable.TransferableType) -> QueryResult<Persistable> {
            QueryResult(original: transferable, commit(item:))
        }

        /// Replaces the item with the same identifier, if still present.
        private func replace(with transferable: Persistable.TransferableType) {
            guard let index = binding.wrappedValue.firstIndex(where: { $0.id == transferable.persistentModelID }) else {
                return
            }
            binding.wrappedValue[index] = makeResult(transferable)
        }
    }
}
