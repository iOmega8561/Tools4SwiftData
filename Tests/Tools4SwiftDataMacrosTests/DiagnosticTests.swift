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
//  DiagnosticTests.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import SwiftSyntaxMacrosTestSupport
import XCTest

/// Tests of the diagnostics emitted by `@DataTransferObject`.
///
/// When a diagnostic is emitted the macro generates neither members nor
/// the conformance extension: the expanded source is the original one
/// without the macro attribute.
final class DiagnosticTests: XCTestCase {

    /// The macro only applies to classes.
    func testStructIsRejected() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @DataTransferObject
            struct Item {
                var name: String
            }
            """#,
            expandedSource: #"""
            struct Item {
                var name: String
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "@DataTransferObject can only be applied to classes.", line: 1, column: 1)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }

    /// The macro only applies to classes.
    func testEnumIsRejected() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @DataTransferObject
            enum Item {
                case one
            }
            """#,
            expandedSource: #"""
            enum Item {
                case one
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "@DataTransferObject can only be applied to classes.", line: 1, column: 1)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }

    /// Actors are not classes: `@Model` cannot be applied to them either.
    func testActorIsRejected() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @DataTransferObject
            actor Item {
                var name: String = ""
            }
            """#,
            expandedSource: #"""
            actor Item {
                var name: String = ""
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "@DataTransferObject can only be applied to classes.", line: 1, column: 1)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }

    /// A class without `@Model` is rejected at its name.
    func testMissingModelIsRejected() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @DataTransferObject
            final class Item {
                var name: String = ""
            }
            """#,
            expandedSource: #"""
            final class Item {
                var name: String = ""
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "@DataTransferObject requires a class annotated with SwiftData's @Model.", line: 2, column: 13)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }

    /// An inferred type cannot be read by the macro.
    func testMissingTypeAnnotationIsRejected() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Item {
                var count = 0
            }
            """#,
            expandedSource: #"""
            @Model
            final class Item {
                var count = 0
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "'count' needs an explicit type annotation to be part of the DTOs; add one or mark it @IgnoredByDTO.", line: 3, column: 9)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }

    /// The generated initializer cannot set an excluded property.
    func testIgnoredPropertyWithoutDefaultIsRejected() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Item {
                @IgnoredByDTO var cache: Int
            }
            """#,
            expandedSource: #"""
            @Model
            final class Item {
                var cache: Int
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "'cache' is excluded from the DTOs, so it needs a default value: the generated initializer does not set it.", line: 3, column: 23)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }

    /// `@Transient` properties are excluded like `@IgnoredByDTO` ones.
    func testTransientPropertyWithoutDefaultIsRejected() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Item {
                @Transient var scratch: String
            }
            """#,
            expandedSource: #"""
            @Model
            final class Item {
                @Transient var scratch: String
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "'scratch' is excluded from the DTOs, so it needs a default value: the generated initializer does not set it.", line: 3, column: 20)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }

    /// Only `Model`, `Model?`, `[Model]` and `[Model]?` are supported, in sugared spelling.
    func testUnsupportedRelationshipTypesAreRejected() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Item {
                @Relationship var byName: [String: Book]
                @Relationship var generic: Array<Book>
                @Relationship var set: Set<Book>
                @Relationship var optional: Optional<Book>
                @Relationship var pair: (Book, Book)
            }
            """#,
            expandedSource: #"""
            @Model
            final class Item {
                @Relationship var byName: [String: Book]
                @Relationship var generic: Array<Book>
                @Relationship var set: Set<Book>
                @Relationship var optional: Optional<Book>
                @Relationship var pair: (Book, Book)
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "'byName' has unsupported relationship type '[String: Book]'; use Model, Model?, [Model] or [Model]?.", line: 3, column: 31),
                DiagnosticSpec(message: "'generic' has unsupported relationship type 'Array<Book>'; use Model, Model?, [Model] or [Model]?.", line: 4, column: 32),
                DiagnosticSpec(message: "'set' has unsupported relationship type 'Set<Book>'; use Model, Model?, [Model] or [Model]?.", line: 5, column: 28),
                DiagnosticSpec(message: "'optional' has unsupported relationship type 'Optional<Book>'; use Model, Model?, [Model] or [Model]?.", line: 6, column: 33),
                DiagnosticSpec(message: "'pair' has unsupported relationship type '(Book, Book)'; use Model, Model?, [Model] or [Model]?.", line: 7, column: 29)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }

    /// Every problem is reported at once, and nothing is generated.
    func testEveryProblemIsReported() throws {
        #if canImport(Tools4SwiftDataMacros)
        assertMacroExpansion(
            #"""
            @DataTransferObject
            final class Item {
                var count = 0
                @IgnoredByDTO var cache: Int
                @Relationship var byName: [String: Book]
            }
            """#,
            expandedSource: #"""
            final class Item {
                var count = 0
                var cache: Int
                @Relationship var byName: [String: Book]
            }
            """#,
            diagnostics: [
                DiagnosticSpec(message: "@DataTransferObject requires a class annotated with SwiftData's @Model.", line: 2, column: 13),
                DiagnosticSpec(message: "'count' needs an explicit type annotation to be part of the DTOs; add one or mark it @IgnoredByDTO.", line: 3, column: 9),
                DiagnosticSpec(message: "'cache' is excluded from the DTOs, so it needs a default value: the generated initializer does not set it.", line: 4, column: 23),
                DiagnosticSpec(message: "'byName' has unsupported relationship type '[String: Book]'; use Model, Model?, [Model] or [Model]?.", line: 5, column: 31)
            ],
            macroSpecs: testMacros
        )
        #else
        throw macrosUnavailable()
        #endif
    }
}
