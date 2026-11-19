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
//  SwiftDataTransferable.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 31/12/24.
//

import SwiftData

/// A protocol that represents an immutable, `Sendable` snapshot of a
/// persistable model.
///
/// Snapshots are what leaves the `SwiftDataManager` actor: unlike models,
/// they can cross isolation domains freely.
public protocol SwiftDataTransferable: Hashable, Sendable {

    associatedtype PersistableType: SwiftDataPersistable where PersistableType.TransferableType == Self

    associatedtype ConfigurableType: SwiftDataConfigurable where ConfigurableType.TransferableType == Self

    /// The identifier of the model this snapshot was taken from.
    var persistentModelID: PersistentIdentifier { get }

    /// Takes a snapshot of a model.
    ///
    /// - Parameter persistentModel: The model to copy.
    init(_ persistentModel: PersistableType)
}
