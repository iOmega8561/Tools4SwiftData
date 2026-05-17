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

/// A diagnostic message emitted by macro expansions when a declaration does not
/// satisfy the requirements of a given macro.
///
/// `MacroDiagnostic` conforms to Swift's `DiagnosticMessage` protocol, enabling
/// it to be integrated with the Swift compiler's diagnostic system. Each
/// diagnostic case represents a specific constraint violation, such as applying
/// a macro to a class that does not use `@Model`, or applying it to a
/// non-class type.
///
/// This structure is used by macro implementations to validate input
/// declarations before proceeding with code generation. If a diagnostic is
/// emitted, the macro expansion is halted and the error is reported to the
/// developer with a clear explanation of the violation.
///
/// - onlyClasses: The `@DataTransferObject` macro can only be applied to
///   classes that use the SwiftData `@Model` macro.
enum MacroDiagnostic: String, Error, DiagnosticMessage {
    
    case onlyClasses = "@DataTransferObject can only be applied on classes that use the SwiftData @Model macro."
    
    public var severity: DiagnosticSeverity {
        .error
    }
    
    public var diagnosticID: MessageID {
        MessageID(domain: "Tools4SwiftData", id: rawValue)
    }
    
    public var message: String { rawValue }
}
