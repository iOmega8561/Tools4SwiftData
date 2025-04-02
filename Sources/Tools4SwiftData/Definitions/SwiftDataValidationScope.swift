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
//  SwifDataValidationScope.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 04/01/25.
//

/// An enumeration that defines the scope of validation for a `SwiftDataConfigurable` model.
///
/// Use `SwiftDataValidationScope` to specify whether validation is being performed
/// for a creation or update operation. This allows the `SwiftDataConfigurable` conforming
/// types to tailor their validation logic based on the context of the operation.
///
/// - SeeAlso: `SwiftDataConfigurable`
public enum SwiftDataValidationScope {

    /// Validation scope for creating a new model instance.
    ///
    /// When this scope is used, the validation logic should ensure that:
    /// - All required fields are populated.
    /// - All constraints that must hold for the initial creation of the model are satisfied.
    ///
    /// Example scenarios:
    /// - Validating that required fields, such as IDs or names, are present.
    /// - Ensuring default or initial values meet domain-specific constraints.
    case creation

    /// Validation scope for updating an existing model instance.
    ///
    /// When this scope is used, the validation logic should ensure that:
    /// - Only fields that are mutable can be changed.
    /// - All fields required for the update operation are valid.
    ///
    /// Example scenarios:
    /// - Validating that immutable fields, such as unique identifiers, are not modified.
    /// - Ensuring updated values conform to business logic or constraints.
    case update
}
