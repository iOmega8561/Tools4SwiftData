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
//  ProtocolConformanceProps.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import Foundation

/// A structure that encapsulates the metadata required to generate a
/// dynamic protocol conformance declaration.
///
/// `ProtocolConformanceProps` aggregates the list of protocols that a generated
/// type must conform to, along with the property and method implementations
/// that the macro will inject into the final declaration. This structure
/// serves as an intermediate representation during macro expansion, collecting
/// information from `StoredProperty` instances and other sources before
/// assembling the final synthesized AST.
///
/// The properties and methods strings contain the generated source code that
/// will be inserted into the conformance block, typically in the form of
/// property declarations or method implementations that delegate to or
/// transform the underlying `SwiftDataPersistable` types.
///
/// - Parameter protocols: A set of protocol names that the generated type
///   must conform to (e.g., `"SwiftDataTransferable"`, `"Codable"`).
/// - Parameter properties: Generated property declarations for the conformance.
/// - Parameter methods: Generated method implementations for the conformance.
struct ProtocolConformanceProps: Sendable {
    let protocols: Set<String>
    let properties: String
    let methods: String
    
    public init(
        protocols: Set<String> = .init(),
        properties: String = "",
        methods: String = ""
    ) {
        self.protocols = protocols
        self.properties = properties
        self.methods = methods
    }
}
