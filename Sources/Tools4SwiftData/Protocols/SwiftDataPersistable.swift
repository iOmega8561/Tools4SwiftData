//
//  SwiftDataPersistable.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 31/12/24.
//

import SwiftData

/// A protocol that represents a model capable of persisting data.
///
/// Conforming types are expected to initialize using a validated instance of a
/// `SwiftDataConfigurable` type. This protocol also uses an associated type,
/// `ConfigurableType`, which must conform to `SwiftDataConfigurable`.
///
/// This protocol is intended to work as part of a data persistence layer,
/// where configurable models are validated before being persisted.
public protocol SwiftDataPersistable: PersistentModel {
    
    /// The associated configurable type that this persistent model requires
    /// for initialization.
    associatedtype ConfigurableType: SwiftDataConfigurable

    static var filePrefix: String { get }
    
    /// Initializes the persistent model with a validated configurable model.
    ///
    /// - Parameter configurableModel: A validated instance conforming to
    ///   `SwiftDataConfigurable`.
    ///
    /// Conforming types should use the provided `configurableModel` to
    /// initialize properties needed for persistence. This ensures that all
    /// persisted models are derived from validated configurations.
    init(_ configurableModel: ConfigurableType)
}