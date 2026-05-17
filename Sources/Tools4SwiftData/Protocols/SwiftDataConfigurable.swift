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
//  SwiftDataConfigurable.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 31/12/24.
//

import Foundation
import SwiftData

/// A protocol that represents a configurable model in a data workflow.
/// Types conforming to `SwiftDataConfigurable` must implement validation
/// logic to ensure the model's state is appropriate for usage.
///
/// This protocol is intended to be used as a configuration step in data
/// persistence or transfer processes.
public protocol SwiftDataConfigurable: Sendable {
    
    associatedtype PersistableType: SwiftDataPersistable where PersistableType.ConfigurableType == Self
    
    associatedtype TransferableType: SwiftDataTransferable where PersistableType.TransferableType == TransferableType
    
    var persistentModelID: PersistentIdentifier? { get }
    
    /// Validates the current instance's state.
    ///
    /// - Parameter scope: The scope for which the configurable should be validated.
    ///
    /// - Throws: An error if the instance fails to meet validation requirements.
    ///
    /// Implementing types should define validation logic that checks for
    /// correctness and completeness of the model's data. For example, ensuring
    /// all required fields are populated or verifying that values are within
    /// acceptable ranges. Typically, this is called before attempting to use
    /// the model in a persistence or transfer operation.
    func validate(for scope: SwiftDataValidationScope) throws
    
    /// Initializes the configurable model from a transferable model.
    ///
    /// - Parameter dto: A transferable model instance.
    ///
    /// Conforming types should use the provided `dto` to
    /// initialize the configurable model's properties.
    init(_ dto: TransferableType)
}
