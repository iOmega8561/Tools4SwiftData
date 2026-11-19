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
//  TypeInspectorTests.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import SwiftSyntax
import XCTest
#if canImport(Tools4SwiftDataMacros)
@testable import Tools4SwiftDataMacros
#endif

/// Unit tests of `TypeInspector`, which classifies types from their syntax.
final class TypeInspectorTests: XCTestCase {

    func testOptionalSpellings() throws {
        #if canImport(Tools4SwiftDataMacros)
        let optional = ["Int?", "Int!", "Optional<Int>", "Swift.Optional<Int>", "[Int]?", "Book?"]
        for type in optional {
            XCTAssertTrue(TypeInspector.isOptional(parseType(type)), type)
        }

        let nonOptional = ["Int", "[Int?]", "[String: Int?]", "Optional", "MyModule.Optional<Int>", "(Int?, Int)"]
        for type in nonOptional {
            XCTAssertFalse(TypeInspector.isOptional(parseType(type)), type)
        }
        #else
        throw macrosUnavailable()
        #endif
    }

    func testUnwrapOptionalRemovesOneSugaredLevel() throws {
        #if canImport(Tools4SwiftDataMacros)
        let (wrapped, isOptional) = TypeInspector.unwrapOptional(parseType("Int??"))
        XCTAssertTrue(isOptional)
        XCTAssertEqual(wrapped.trimmedDescription, "Int?")

        let (plain, plainIsOptional) = TypeInspector.unwrapOptional(parseType("Int"))
        XCTAssertFalse(plainIsOptional)
        XCTAssertEqual(plain.trimmedDescription, "Int")
        #else
        throw macrosUnavailable()
        #endif
    }

    func testNominalNames() throws {
        #if canImport(Tools4SwiftDataMacros)
        XCTAssertEqual(TypeInspector.nominalName(parseType("Book")), "Book")
        XCTAssertEqual(TypeInspector.nominalName(parseType("Library.Book")), "Library.Book")
        XCTAssertEqual(TypeInspector.nominalName(parseType("A.B.Book")), "A.B.Book")

        for type in ["Array<Book>", "[Book]", "Book?", "(Book, Book)", "any Book", "Library.Box<Book>"] {
            XCTAssertNil(TypeInspector.nominalName(parseType(type)), type)
        }
        #else
        throw macrosUnavailable()
        #endif
    }

    func testSupportedRelationshipShapes() throws {
        #if canImport(Tools4SwiftDataMacros)
        let expectations: [(String, PropertyShape)] = [
            ("Book", .toOne(target: "Book", isOptional: false)),
            ("Book?", .toOne(target: "Book", isOptional: true)),
            ("Book!", .toOne(target: "Book", isOptional: true)),
            ("Library.Book?", .toOne(target: "Library.Book", isOptional: true)),
            ("[Book]", .toMany(element: "Book", isOptional: false)),
            ("[Book]?", .toMany(element: "Book", isOptional: true)),
            ("[Library.Book]", .toMany(element: "Library.Book", isOptional: false)),
        ]
        for (type, shape) in expectations {
            XCTAssertEqual(TypeInspector.relationshipShape(of: parseType(type)), shape, type)
        }
        #else
        throw macrosUnavailable()
        #endif
    }

    func testUnsupportedRelationshipShapes() throws {
        #if canImport(Tools4SwiftDataMacros)
        let unsupported = [
            "[String: Book]", "Array<Book>", "Set<Book>", "Optional<Book>",
            "(Book, Book)", "[Book?]", "[[Book]]", "Book??", "any Book"
        ]
        for type in unsupported {
            XCTAssertNil(TypeInspector.relationshipShape(of: parseType(type)), type)
        }
        #else
        throw macrosUnavailable()
        #endif
    }
}
