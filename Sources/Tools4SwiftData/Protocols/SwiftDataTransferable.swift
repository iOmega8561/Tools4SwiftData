//
//  SwiftDataTransferable.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 31/12/24.
//

import SwiftData

/// A protocol that represents a model suitable for data transfer.
///
/// Conforming types are expected to initialize from a persistent model,
/// allowing data to be transformed into a transferable format. This protocol
/// uses an associated type, `PersistableType`, which must conform to
/// `SwiftDataPersistable`.
///
/// This protocol is intended for scenarios where persistent data needs to be
/// converted into a form suitable for transfer over a network or other
/// external usage.
public protocol SwiftDataTransferable: Sendable {
    
    /// The associated persistent type that this transferable model requires
    /// for initialization.
    associatedtype PersistableType: SwiftDataPersistable
    
    var persistentModelID: PersistentIdentifier { get }
    
    /// Initializes the transferable model with a persistent model.
    ///
    /// - Parameter persistentModel: An instance conforming to
    ///   `SwiftDataPersistent`.
    ///
    /// Conforming types should use the provided `persistentModel` to
    /// initialize properties needed for data transfer. This ensures that
    /// all transferred models are based on validated, persistent data.
    init(_ persistentModel: PersistableType)
}
