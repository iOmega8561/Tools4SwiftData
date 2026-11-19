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
//  TestSupport.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import SwiftParser
import SwiftSyntax
import XCTest

#if canImport(Tools4SwiftDataMacros)
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
@testable import Tools4SwiftDataMacros

/// The macros under test, keyed by the name used in source.
///
/// `DataTransferObject` declares the `SwiftDataPersistable` conformance, as
/// the real macro declaration does: without it the extension expansion
/// would receive no protocols and generate nothing.
let testMacros: [String: MacroSpec] = [
    "DataTransferObject": MacroSpec(type: DataTransferObject.self, conformances: ["SwiftDataPersistable"]),
    "IgnoredByDTO": MacroSpec(type: IgnoredByDTO.self)
]
#endif

/// The error thrown by every test when the macro module cannot be imported.
///
/// Macros run on the host: when the tests are built for another platform
/// (an iOS destination, for instance) the macro module is not available and
/// the tests are reported as skipped instead of disappearing.
func macrosUnavailable() -> XCTSkip {
    XCTSkip("Macros are only supported when running tests for the host platform")
}

/// Parses a type, for the unit tests of the type helpers.
func parseType(_ source: String) -> TypeSyntax {
    var parser = Parser(source)
    return TypeSyntax.parse(from: &parser)
}

/// Parses a class declaration, for the unit tests of the extractor.
func parseClass(_ source: String) -> ClassDeclSyntax {
    let file = Parser.parse(source: source)
    for statement in file.statements {
        if let classDecl = statement.item.as(ClassDeclSyntax.self) {
            return classDecl
        }
    }
    fatalError("No class declaration in source")
}
