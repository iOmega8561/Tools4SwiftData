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
    
    /// Updates the current instance based on submitted configurable object
    ///
    /// This method should implement the necessary logic that better suits the use case.
    /// It's up to who will implement the actual function to decide whether all instance properties
    /// should be updated or just a small part of it.
    func update(using configurable: ConfigurableType) throws
    
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
