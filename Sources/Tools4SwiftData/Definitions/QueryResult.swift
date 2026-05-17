//
//  QueryResult.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 17/05/2026.
//

import SwiftData
import SwiftUI

/// A property wrapper that represents a single model instance with draft-state support.
///
/// `QueryResult` decouples the original persisted state from the editable draft,
/// enabling safe in-place editing within SwiftUI views without triggering
/// immediate persistence. It conforms to `DynamicProperty` to integrate seamlessly
/// with SwiftUI's rendering pipeline and to the `Identifiable` protocol for use
/// with `ForEach`.
///
/// The wrapper maintains two parallel states:
/// - `original`: The snapshot of the model as it exists in the database, used as
///   a source of truth for diffing and conflict detection.
/// - `configurable`: A mutable draft instance that the user can edit inline.
///
/// Editing is exposed through `wrappedValue` (the configurable draft) and
/// `projectedValue` (a `ProjectedWrapper` providing `$draft.propertyName` bindings).
///
/// A `commitCallback` is injected at initialization, allowing the wrapper to remain
/// decoupled from actual persistence logic. This design enables flexible commit
/// strategies such as batch saves, optimistic updates, or conflict resolution,
/// without requiring `QueryResult` to know about `SwiftDataManager` or database
/// operations.
///
/// The reason for using a `struct` with `DynamicProperty` instead of a class
/// annotated with `@Observable` is twofold:
/// 1. `@State` in property wrappers requires `DynamicProperty` conformance, and
///    structs work naturally with SwiftUI's value semantics, avoiding the
///    reference-based mutation complexity of `@Observable` classes.
/// 2. `@Observable` introduces automatic dependency tracking that can trigger
///    unnecessary re-renders when combined with a dual-state pattern. A struct
///    gives explicit control over what triggers updates and when.
///
/// The `commitCallback` pattern solves the problem of where commit logic lives.
/// By capturing it at initialization, `QueryResult` can defer persistence to the
/// caller, enabling patterns such as:
/// - Single-item commit: each item saves independently
/// - Batch commit: collect multiple `QueryResult` instances and persist them
///   together, reducing round-trips
/// - Conflict resolution: compare `original` against `configurable` before
///   committing to detect drift
///
/// - Type Parameter `Persistable`: The persistent model type that this wrapper
///   manages. Must conform to `SwiftDataPersistable`.
@propertyWrapper
public struct QueryResult<Persistable: SwiftDataPersistable>: DynamicProperty, Identifiable, Sendable {

    private let commitCallback: @Sendable (QueryResult<Persistable>) async throws -> Void
    
    public let original: Persistable.TransferableType

    @State
    public var configurable: Persistable.ConfigurableType
    
    public var id: PersistentIdentifier {
        original.persistentModelID
    }
    
    /// Commits the current draft to the persistent store.
    ///
    /// This method invokes the `commitCallback` provided at initialization.
    /// It is intended to be called when the user confirms changes, e.g. via a
    /// "Save" button or automatic debounced save.
    ///
    /// - Throws: An error from the persistence layer if the commit fails.
    public func commit() async throws {
        try await commitCallback(self)
    }
    
    /// The editable draft instance.
    public var wrappedValue: Persistable.ConfigurableType {
        get { configurable }
        nonmutating set { configurable = newValue }
    }
    
    /// A projected wrapper exposing bindings and a commit action.
    public var projectedValue: ProjectedWrapper {
        ProjectedWrapper(
            binding: $configurable,
            saveAction: commit
        )
    }
    
    /// A helper struct that provides `$draft.propertyName` bindings and a
    /// convenience `commit()` method.
    ///
    /// This wrapper enables inline editing in SwiftUI views:
    /// ```swift
    /// TextField($result.$draft.name) {
    ///     await result.commit()
    /// }
    /// ```
    @dynamicMemberLookup
    public struct ProjectedWrapper: Sendable {
        private let binding: Binding<Persistable.ConfigurableType>
        private let saveAction: @Sendable () async throws -> Void
        
        fileprivate init(
            binding: Binding<Persistable.ConfigurableType>,
            saveAction: @Sendable @escaping () async throws -> Void
        ) {
            self.binding = binding
            self.saveAction = saveAction
        }
        
        /// Exposes a binding to a specific property on the draft.
        public subscript<V>(dynamicMember keyPath: WritableKeyPath<Persistable.ConfigurableType, V>) -> Binding<V> {
            binding[dynamicMember: keyPath]
        }
        
        /// Convenience alias for committing the draft.
        @discardableResult
        public func commit() async throws {
            try await saveAction()
        }
    }
    
    /// Initializes a new `QueryResult` with an original snapshot and a commit callback.
    ///
    /// - Parameter original: The transferable snapshot loaded from the persistent store.
    /// - Parameter commitCallback: A closure that receives this `QueryResult` and
    ///   persists the draft. The callback is captured to allow decoupled commit strategies.
    public init(
        original: Persistable.TransferableType,
        _ commitCallback: @Sendable @escaping (QueryResult<Persistable>) async throws -> Void
    ) {
        self.original = original
        self.configurable = .init(original)
        self.commitCallback = commitCallback
    }
}

/// A conditional conformance that enables equality comparison for `QueryResult`
/// instances when both the configurable and transferable types support it.
///
/// Two `QueryResult` instances are considered equal when both their
/// `configurable` (draft) and `original` (snapshot) states match. This allows
/// views to detect whether a user's edits have changed since the last load,
/// or whether two results represent the same logical item.
///
/// This conformance is conditional on `ConfigurableType` conforming to
/// `Equatable`, ensuring that equality is only available when the underlying
/// types support it. This keeps the protocol requirements flexible and allows
/// `QueryResult` to be used with any model type, regardless of whether it
/// defines equality semantics.
///
/// - Parameter lhs: The left-hand side instance to compare.
/// - Parameter rhs: The right-hand side instance to compare.
///
/// - Returns: `true` if both the draft and original states match; `false`
///   otherwise.
extension QueryResult: Equatable where Persistable.ConfigurableType: Equatable,
                                       Persistable.TransferableType: Equatable {
    public static func == (
        lhs: QueryResult<Persistable>,
        rhs: QueryResult<Persistable>
    ) -> Bool {
        lhs.configurable == rhs.configurable &&
        lhs.original == rhs.original
    }
}

/// A conditional conformance that enables hashing for `QueryResult`
/// instances when both the configurable and transferable types support it.
///
/// Hashing is required for use in sets and dictionaries, and is also useful
/// for identifying unique items in SwiftUI's `ForEach`, which relies on
/// `Identifiable` for diffing but benefits from `Hashable` for internal
/// caching and lookup optimizations.
///
/// The hash is computed from both the `configurable` and `original` states,
/// ensuring that any change to either the draft or the snapshot produces a
/// different hash. This prevents stale cache entries and ensures that views
/// correctly detect modifications.
///
/// This conformance is conditional on `ConfigurableType` and
/// `TransferableType` both conforming to `Hashable`, maintaining the same
/// flexibility as the `Equatable` conformance.
///
/// - Parameter hasher: The `Hasher` to combine the instance's properties into.
extension QueryResult: Hashable where Persistable.ConfigurableType: Hashable,
                                      Persistable.TransferableType: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(configurable)
        hasher.combine(original)
    }
}

