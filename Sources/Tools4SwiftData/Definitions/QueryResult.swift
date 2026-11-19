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
//  QueryResult.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 17/05/2026.
//

import Foundation
import SwiftData
import SwiftUI

/// A property wrapper that represents a single model with an editable draft.
///
/// `QueryResult` pairs the snapshot loaded from the store (`original`) with a
/// draft (`wrappedValue`) kept in `@State`. Declare it on the view that edits
/// the item, so that SwiftUI installs its state:
///
/// ```swift
/// struct ItemRow: View {
///     @QueryResult var item: Item.Configurable
///
///     init(result: QueryResult<Item>) {
///         _item = result
///     }
///
///     var body: some View {
///         TextField("Name", text: $item.name)
///             .onSubmit { Task { try await $item.commit() } }
///     }
/// }
/// ```
///
/// Only instances installed on a view keep the user's edits: the copies held
/// by `ManagedQuery`'s array always report the draft they were created with.
///
/// ## Following the original
///
/// When a view receives a new `QueryResult` for the same item (after a
/// commit or a refresh), SwiftUI keeps the existing state and ignores the
/// new initial value. To keep the draft in sync anyway, the state stores the
/// draft together with the snapshot it was derived from (its baseline):
/// - a draft without changes follows `original`, so the view shows fresh data;
/// - a draft with changes is kept, and `hasConflict` reports whether
///   `original` changed underneath it.
///
/// Draft and snapshot are compared through `Configurable(original)`, which
/// is rebuilt on each access: keep this in mind for models with very large
/// to-many relationships.
@propertyWrapper
public struct QueryResult<Persistable: SwiftDataPersistable>: DynamicProperty, Identifiable, Sendable {

    public typealias Transferable = Persistable.TransferableType
    public typealias Configurable = Persistable.ConfigurableType

    /// The draft together with the snapshot it was derived from.
    private struct DraftState: Sendable {
        var baseline: Transferable
        var draft: Configurable
    }

    private let commitCallback: @Sendable (QueryResult<Persistable>) async throws -> Void

    /// The snapshot of the item as loaded from the store.
    public let original: Transferable

    @State
    private var state: DraftState

    public var id: PersistentIdentifier {
        original.persistentModelID
    }

    /// Whether the draft has no changes of its own, and therefore mirrors
    /// `original`.
    private var isFollowingOriginal: Bool {
        state.draft == Configurable(state.baseline) || state.draft == Configurable(original)
    }

    /// The editable draft.
    public var wrappedValue: Configurable {
        get {
            isFollowingOriginal ? Configurable(original) : state.draft
        }
        nonmutating set {
            let baseline = isFollowingOriginal ? original : state.baseline
            state = DraftState(baseline: baseline, draft: newValue)
        }
    }

    /// A binding to the draft.
    public var binding: Binding<Configurable> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }

    /// Whether the draft differs from `original`.
    public var hasChanges: Bool {
        wrappedValue != Configurable(original)
    }

    /// Whether the draft has changes and `original` changed since the draft
    /// was started, so committing would overwrite someone else's changes.
    public var hasConflict: Bool {
        !isFollowingOriginal && state.baseline != original
    }

    /// Discards the changes and makes the draft follow `original` again.
    public func reset() {
        state = DraftState(baseline: original, draft: Configurable(original))
    }

    /// Commits the draft through the callback provided at initialization.
    ///
    /// - Throws: An error from the persistence layer if the commit fails.
    public func commit() async throws {
        try await commitCallback(self)
    }

    /// The bindings to the draft's properties and the item's actions.
    public var projectedValue: ProjectedWrapper {
        ProjectedWrapper(result: self)
    }

    /// Provides `$item.property` bindings and the item's actions.
    @dynamicMemberLookup
    public struct ProjectedWrapper: Sendable {

        private let result: QueryResult<Persistable>

        fileprivate init(result: QueryResult<Persistable>) {
            self.result = result
        }

        /// A binding to a property of the draft.
        public subscript<V>(dynamicMember keyPath: WritableKeyPath<Configurable, V>) -> Binding<V> {
            result.binding[dynamicMember: keyPath]
        }

        /// A binding to the whole draft.
        public var binding: Binding<Configurable> { result.binding }

        /// Whether the draft differs from the stored item.
        public var hasChanges: Bool { result.hasChanges }

        /// Whether the stored item changed while the draft was being edited.
        public var hasConflict: Bool { result.hasConflict }

        /// Discards the changes to the draft.
        public func reset() { result.reset() }

        /// Commits the draft.
        public func commit() async throws {
            try await result.commit()
        }
    }

    /// Initializes a `QueryResult` from a snapshot and a commit callback.
    ///
    /// - Parameters:
    ///   - original: The snapshot loaded from the store.
    ///   - commitCallback: The closure that persists the draft. It receives
    ///     this `QueryResult`, so that the caller reads the draft from the
    ///     installed instance.
    public init(
        original: Transferable,
        _ commitCallback: @Sendable @escaping (QueryResult<Persistable>) async throws -> Void
    ) {
        self.original = original
        self._state = State(initialValue: DraftState(baseline: original, draft: Configurable(original)))
        self.commitCallback = commitCallback
    }
}

/// Two `QueryResult` values are equal when they wrap the same snapshot.
///
/// The draft is deliberately left out: it lives in view state, and the
/// copies held outside a view do not see it.
extension QueryResult: Equatable {
    public static func == (lhs: QueryResult<Persistable>, rhs: QueryResult<Persistable>) -> Bool {
        lhs.original == rhs.original
    }
}

extension QueryResult: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(original)
    }
}
