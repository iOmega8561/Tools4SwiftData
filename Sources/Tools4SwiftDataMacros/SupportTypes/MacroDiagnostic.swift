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
//  MacroDiagnostic.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import Foundation
import SwiftDiagnostics

/// A diagnostic message emitted by `@DataTransferObject` when a declaration
/// does not satisfy its requirements.
///
/// Every case is an error: when one is emitted the macro generates nothing,
/// so the developer sees the actual cause instead of cascading errors inside
/// the expanded code.
enum MacroDiagnostic: Error, DiagnosticMessage {

    /// The macro is attached to something other than a class.
    case onlyClasses

    /// The class is not annotated with SwiftData's `@Model`.
    case missingModel

    /// A participating stored property has no explicit type annotation.
    case missingTypeAnnotation(property: String)

    /// A property excluded from the DTOs has no default value.
    case excludedWithoutDefault(property: String)

    /// A `@Relationship` property has a type the macro cannot handle.
    case unsupportedRelationship(property: String, type: String)

    var severity: DiagnosticSeverity {
        .error
    }

    var diagnosticID: MessageID {
        let id: String = switch self {
        case .onlyClasses: "onlyClasses"
        case .missingModel: "missingModel"
        case .missingTypeAnnotation: "missingTypeAnnotation"
        case .excludedWithoutDefault: "excludedWithoutDefault"
        case .unsupportedRelationship: "unsupportedRelationship"
        }
        return MessageID(domain: "Tools4SwiftData", id: id)
    }

    var message: String {
        switch self {
        case .onlyClasses:
            "@DataTransferObject can only be applied to classes."
        case .missingModel:
            "@DataTransferObject requires a class annotated with SwiftData's @Model."
        case .missingTypeAnnotation(let property):
            "'\(property)' needs an explicit type annotation to be part of the DTOs; add one or mark it @IgnoredByDTO."
        case .excludedWithoutDefault(let property):
            "'\(property)' is excluded from the DTOs, so it needs a default value: the generated initializer does not set it."
        case .unsupportedRelationship(let property, let type):
            "'\(property)' has unsupported relationship type '\(type)'; use Model, Model?, [Model] or [Model]?."
        }
    }
}
