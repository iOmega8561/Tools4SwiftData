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
//  PropertyExtractorTests.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import SwiftSyntax
import XCTest
#if canImport(Tools4SwiftDataMacros)
@testable import Tools4SwiftDataMacros
#endif

/// Unit tests of `PropertyExtractor` and of the attribute and modifier
/// parsing of `PersistableExpander`.
final class PropertyExtractorTests: XCTestCase {

    #if canImport(Tools4SwiftDataMacros)
    private func extract(_ source: String) -> PropertyExtractor.Result {
        PropertyExtractor(classDecl: parseClass(source)).extract()
    }
    #endif

    func testExtractedPropertiesKeepDeclarationOrderAndMetadata() throws {
        #if canImport(Tools4SwiftDataMacros)
        let result = extract("""
        final class Item {
            var name: String
            var count: Int = 42
            var note: String?
            @Relationship var owner: Owner?
            @Relationship var parts: [Part] = []
        }
        """)

        XCTAssertTrue(result.diagnostics.isEmpty)
        XCTAssertEqual(result.properties.map(\.name), ["name", "count", "note", "owner", "parts"])

        let byName = Dictionary(uniqueKeysWithValues: result.properties.map { ($0.name, $0) })
        XCTAssertNil(byName["name"]?.defaultValue)
        XCTAssertEqual(byName["count"]?.defaultValue, "42")
        XCTAssertEqual(byName["note"]?.defaultValue, "nil")
        XCTAssertEqual(byName["note"]?.isOptional, true)
        XCTAssertEqual(byName["name"]?.shape, .attribute)
        XCTAssertEqual(byName["owner"]?.shape, .toOne(target: "Owner", isOptional: true))
        XCTAssertEqual(byName["parts"]?.shape, .toMany(element: "Part", isOptional: false))
        XCTAssertEqual(byName["parts"]?.defaultValue, "[]")
        #else
        throw macrosUnavailable()
        #endif
    }

    func testCollectionAttributesAreNotRelationships() throws {
        #if canImport(Tools4SwiftDataMacros)
        let result = extract("""
        final class Item {
            var tags: [String] = []
            var scores: [String: Int] = [:]
            var parts: [Part] = []
        }
        """)

        XCTAssertEqual(result.properties.map(\.shape), [.attribute, .attribute, .attribute])
        #else
        throw macrosUnavailable()
        #endif
    }

    func testStorageDetection() throws {
        #if canImport(Tools4SwiftDataMacros)
        let result = extract("""
        final class Item {
            var stored: Int = 0
            var observed: Int = 0 { willSet { } didSet { } }
            var getter: Int { 0 }
            var explicitGetter: Int { get { 0 } }
            var getterSetter: Int { get { 0 } set { } }
            static var shared: Int = 0
            class var kind: String { "item" }
            func method() {}
        }
        """)

        XCTAssertEqual(result.properties.map(\.name), ["stored", "observed"])
        #else
        throw macrosUnavailable()
        #endif
    }

    func testMultipleBindingsShareTheTrailingAnnotation() throws {
        #if canImport(Tools4SwiftDataMacros)
        let result = extract("""
        final class Item {
            var a, b: Int
            var c: String, d: Double
        }
        """)

        XCTAssertEqual(result.properties.map(\.name), ["a", "b", "c", "d"])
        XCTAssertEqual(result.properties.map(\.type), ["Int", "Int", "String", "Double"])
        #else
        throw macrosUnavailable()
        #endif
    }

    func testExcludedProperties() throws {
        #if canImport(Tools4SwiftDataMacros)
        let result = extract("""
        final class Item {
            @IgnoredByDTO var a: Int = 0
            @Tools4SwiftData.IgnoredByDTO var b: Int = 0
            @Transient var c: Int = 0
            @SwiftData.Transient var d: Int = 0
            @IgnoredByDTO var e: Int?
            @IgnoredByDTO var inferred = 0
            var kept: Int = 0
        }
        """)

        XCTAssertTrue(result.diagnostics.isEmpty)
        XCTAssertEqual(result.properties.map(\.name), ["kept"])
        #else
        throw macrosUnavailable()
        #endif
    }

    func testDiagnosticsAreCollectedPerProperty() throws {
        #if canImport(Tools4SwiftDataMacros)
        let result = extract("""
        final class Item {
            var inferred = 0
            @IgnoredByDTO var noDefault: Int
            @Relationship var map: [String: Part]
            var fine: Int = 0
        }
        """)

        XCTAssertEqual(result.properties.map(\.name), ["fine"])
        XCTAssertEqual(result.diagnostics.map(\.diagMessage.message), [
            MacroDiagnostic.missingTypeAnnotation(property: "inferred").message,
            MacroDiagnostic.excludedWithoutDefault(property: "noDefault").message,
            MacroDiagnostic.unsupportedRelationship(property: "map", type: "[String: Part]").message,
        ])
        #else
        throw macrosUnavailable()
        #endif
    }

    func testAccessModifiers() throws {
        #if canImport(Tools4SwiftDataMacros)
        let expectations = [
            ("public final class Item {}", "public "),
            ("open class Item {}", "public "),
            ("package final class Item {}", "package "),
            ("final class Item {}", ""),
            ("internal final class Item {}", ""),
            ("fileprivate final class Item {}", ""),
            ("private final class Item {}", ""),
        ]
        for (source, modifier) in expectations {
            XCTAssertEqual(PersistableExpander.accessModifier(of: parseClass(source)), modifier, source)
        }
        #else
        throw macrosUnavailable()
        #endif
    }

    func testOrphanPolicyArgument() throws {
        #if canImport(Tools4SwiftDataMacros)
        func policy(_ attribute: String) -> String {
            let classDecl = parseClass("\(attribute)\nfinal class Item {}")
            let node = classDecl.attributes.compactMap { $0.as(AttributeSyntax.self) }.first!
            return PersistableExpander.orphanPolicy(from: node)
        }

        XCTAssertEqual(policy("@DataTransferObject"), ".detach")
        XCTAssertEqual(policy("@DataTransferObject()"), ".detach")
        XCTAssertEqual(policy("@DataTransferObject(orphans: .delete)"), ".delete")
        XCTAssertEqual(policy("@DataTransferObject(orphans: OrphanPolicy.delete)"), "OrphanPolicy.delete")
        #else
        throw macrosUnavailable()
        #endif
    }

    func testMessageIdentifiersAreDistinct() throws {
        #if canImport(Tools4SwiftDataMacros)
        let diagnostics: [MacroDiagnostic] = [
            .onlyClasses,
            .missingModel,
            .missingTypeAnnotation(property: "a"),
            .excludedWithoutDefault(property: "a"),
            .unsupportedRelationship(property: "a", type: "T"),
        ]
        let identifiers = Set(diagnostics.map(\.diagnosticID))
        XCTAssertEqual(identifiers.count, diagnostics.count)
        XCTAssertTrue(diagnostics.allSatisfy { $0.severity == .error })
        #else
        throw macrosUnavailable()
        #endif
    }
}
