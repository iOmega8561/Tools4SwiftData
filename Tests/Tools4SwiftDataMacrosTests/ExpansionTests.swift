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
//  ExpansionTests.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

#if canImport(Tools4SwiftDataMacros)

import SwiftSyntaxMacrosTestSupport
import XCTest

/// Golden tests of the `@DataTransferObject` expansion.
///
/// Each test pins the complete expanded source, so any change to the
/// generated code shows up as a readable diff.
final class ExpansionTests: XCTestCase {

    /// Plain attributes are copied verbatim; optionals get an implicit `nil` default.
    func testAttributes() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Item {
                var name: String
                var count: Int = 0
                var note: String?
                var tags: [String] = []
                var scores: [String: Int] = [:]
            }
            """#,
            expandedSource: #"""
            @Model
            final class Item {
                var name: String
                var count: Int = 0
                var note: String?
                var tags: [String] = []
                var scores: [String: Int] = [:]

                typealias ConfigurableType = Configurable

                typealias TransferableType = Transferable

                struct Transferable: SwiftDataTransferable, Identifiable {
                    typealias PersistableType = Item
                    typealias ConfigurableType = Item.Configurable

                    let persistentModelID: PersistentIdentifier
                    var id: PersistentIdentifier {
                        persistentModelID
                    }
                    let name: String
                    let count: Int
                    let note: String?
                    let tags: [String]
                    let scores: [String: Int]

                    init(_ persistentModel: Item) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.name = persistentModel.name
                        self.count = persistentModel.count
                        self.note = persistentModel.note
                        self.tags = persistentModel.tags
                        self.scores = persistentModel.scores
                    }
                }

                struct Configurable: SwiftDataConfigurable {
                    typealias PersistableType = Item
                    typealias TransferableType = Item.Transferable

                    private(set) var persistentModelID: PersistentIdentifier? = nil
                    var name: String
                    var count: Int
                    var note: String?
                    var tags: [String]
                    var scores: [String: Int]

                    init(
                        name: String,
                        count: Int = 0,
                        note: String? = nil,
                        tags: [String] = [],
                        scores: [String: Int] = [:]
                    ) {
                        self.name = name
                        self.count = count
                        self.note = note
                        self.tags = tags
                        self.scores = scores
                    }

                    init(_ transferable: Item.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.name = transferable.name
                        self.count = transferable.count
                        self.note = transferable.note
                        self.tags = transferable.tags
                        self.scores = transferable.scores
                    }
                }

                required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.name = configurable.name
                    self.count = configurable.count
                    self.note = configurable.note
                    self.tags = configurable.tags
                    self.scores = configurable.scores
                }

                func update(using configurable: Configurable, in context: ModelContext) throws {
                    if self.name != configurable.name {
                        self.name = configurable.name
                    }
                    if self.count != configurable.count {
                        self.count = configurable.count
                    }
                    if self.note != configurable.note {
                        self.note = configurable.note
                    }
                    if self.tags != configurable.tags {
                        self.tags = configurable.tags
                    }
                    if self.scores != configurable.scores {
                        self.scores = configurable.scores
                    }
                }
            }

            extension Item: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// A `public` class gets `public` generated members.
    func testPublicClassGetsPublicMembers() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            public final class Item {
                public var name: String = ""
            }
            """#,
            expandedSource: #"""
            @Model
            public final class Item {
                public var name: String = ""

                public typealias ConfigurableType = Configurable

                public typealias TransferableType = Transferable

                public struct Transferable: SwiftDataTransferable, Identifiable {
                    public typealias PersistableType = Item
                    public typealias ConfigurableType = Item.Configurable

                    public let persistentModelID: PersistentIdentifier
                    public var id: PersistentIdentifier {
                        persistentModelID
                    }
                    public let name: String

                    public init(_ persistentModel: Item) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.name = persistentModel.name
                    }
                }

                public struct Configurable: SwiftDataConfigurable {
                    public typealias PersistableType = Item
                    public typealias TransferableType = Item.Transferable

                    public private(set) var persistentModelID: PersistentIdentifier? = nil
                    public var name: String

                    public init(
                        name: String = ""
                    ) {
                        self.name = name
                    }

                    public init(_ transferable: Item.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.name = transferable.name
                    }
                }

                public required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.name = configurable.name
                }

                public func update(using configurable: Configurable, in context: ModelContext) throws {
                    if self.name != configurable.name {
                        self.name = configurable.name
                    }
                }
            }

            extension Item: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// An `open` class gets `public` generated members.
    func testOpenClassGetsPublicMembers() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            open class Item {
                open var name: String = ""
            }
            """#,
            expandedSource: #"""
            @Model
            open class Item {
                open var name: String = ""

                public typealias ConfigurableType = Configurable

                public typealias TransferableType = Transferable

                public struct Transferable: SwiftDataTransferable, Identifiable {
                    public typealias PersistableType = Item
                    public typealias ConfigurableType = Item.Configurable

                    public let persistentModelID: PersistentIdentifier
                    public var id: PersistentIdentifier {
                        persistentModelID
                    }
                    public let name: String

                    public init(_ persistentModel: Item) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.name = persistentModel.name
                    }
                }

                public struct Configurable: SwiftDataConfigurable {
                    public typealias PersistableType = Item
                    public typealias TransferableType = Item.Transferable

                    public private(set) var persistentModelID: PersistentIdentifier? = nil
                    public var name: String

                    public init(
                        name: String = ""
                    ) {
                        self.name = name
                    }

                    public init(_ transferable: Item.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.name = transferable.name
                    }
                }

                public required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.name = configurable.name
                }

                public func update(using configurable: Configurable, in context: ModelContext) throws {
                    if self.name != configurable.name {
                        self.name = configurable.name
                    }
                }
            }

            extension Item: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// A `package` class gets `package` generated members.
    func testPackageClassGetsPackageMembers() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            package final class Item {
                package var name: String = ""
            }
            """#,
            expandedSource: #"""
            @Model
            package final class Item {
                package var name: String = ""

                package typealias ConfigurableType = Configurable

                package typealias TransferableType = Transferable

                package struct Transferable: SwiftDataTransferable, Identifiable {
                    package typealias PersistableType = Item
                    package typealias ConfigurableType = Item.Configurable

                    package let persistentModelID: PersistentIdentifier
                    package var id: PersistentIdentifier {
                        persistentModelID
                    }
                    package let name: String

                    package init(_ persistentModel: Item) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.name = persistentModel.name
                    }
                }

                package struct Configurable: SwiftDataConfigurable {
                    package typealias PersistableType = Item
                    package typealias TransferableType = Item.Transferable

                    package private(set) var persistentModelID: PersistentIdentifier? = nil
                    package var name: String

                    package init(
                        name: String = ""
                    ) {
                        self.name = name
                    }

                    package init(_ transferable: Item.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.name = transferable.name
                    }
                }

                package required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.name = configurable.name
                }

                package func update(using configurable: Configurable, in context: ModelContext) throws {
                    if self.name != configurable.name {
                        self.name = configurable.name
                    }
                }
            }

            extension Item: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// To-one relationships become identifiers; `Configurable` always holds an optional one.
    func testToOneRelationships() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Book {
                @Relationship var author: Author
                @Relationship(deleteRule: .nullify) var editor: Author?
            }
            """#,
            expandedSource: #"""
            @Model
            final class Book {
                @Relationship var author: Author
                @Relationship(deleteRule: .nullify) var editor: Author?

                typealias ConfigurableType = Configurable

                typealias TransferableType = Transferable

                struct Transferable: SwiftDataTransferable, Identifiable {
                    typealias PersistableType = Book
                    typealias ConfigurableType = Book.Configurable

                    let persistentModelID: PersistentIdentifier
                    var id: PersistentIdentifier {
                        persistentModelID
                    }
                    let author: PersistentIdentifier
                    let editor: PersistentIdentifier?

                    init(_ persistentModel: Book) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.author = persistentModel.author.persistentModelID
                        self.editor = persistentModel.editor?.persistentModelID
                    }
                }

                struct Configurable: SwiftDataConfigurable {
                    typealias PersistableType = Book
                    typealias TransferableType = Book.Transferable

                    private(set) var persistentModelID: PersistentIdentifier? = nil
                    var author: PersistentIdentifier?
                    var editor: PersistentIdentifier?

                    init(
                        author: PersistentIdentifier? = nil,
                        editor: PersistentIdentifier? = nil
                    ) {
                        self.author = author
                        self.editor = editor
                    }

                    init(_ transferable: Book.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.author = transferable.author
                        self.editor = transferable.editor
                    }
                }

                required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.author = try context.resolveRequiredRelationship(configurable.author, as: Author.self)
                    self.editor = try context.resolveRelationship(configurable.editor, as: Author.self)
                }

                func update(using configurable: Configurable, in context: ModelContext) throws {
                    if self.author.persistentModelID != configurable.author {
                        self.author = try context.resolveRequiredRelationship(configurable.author, as: Author.self)
                    }
                    if self.editor?.persistentModelID != configurable.editor {
                        self.editor = try context.resolveRelationship(configurable.editor, as: Author.self)
                    }
                }
            }

            extension Book: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// To-many relationships embed the related DTOs and are reconciled with the default `.detach` policy.
    func testToManyRelationships() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Shelf {
                @Relationship(deleteRule: .cascade, inverse: \Book.shelf) var books: [Book] = []
                @Relationship var archive: [Book]?
            }
            """#,
            expandedSource: #"""
            @Model
            final class Shelf {
                @Relationship(deleteRule: .cascade, inverse: \Book.shelf) var books: [Book] = []
                @Relationship var archive: [Book]?

                typealias ConfigurableType = Configurable

                typealias TransferableType = Transferable

                struct Transferable: SwiftDataTransferable, Identifiable {
                    typealias PersistableType = Shelf
                    typealias ConfigurableType = Shelf.Configurable

                    let persistentModelID: PersistentIdentifier
                    var id: PersistentIdentifier {
                        persistentModelID
                    }
                    let books: [Book.Transferable]
                    let archive: [Book.Transferable]?

                    init(_ persistentModel: Shelf) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.books = persistentModel.books.map {
                            Book.Transferable($0)
                        }
                        self.archive = persistentModel.archive?.map {
                            Book.Transferable($0)
                        }
                    }
                }

                struct Configurable: SwiftDataConfigurable {
                    typealias PersistableType = Shelf
                    typealias TransferableType = Shelf.Transferable

                    private(set) var persistentModelID: PersistentIdentifier? = nil
                    var books: [Book.Configurable]
                    var archive: [Book.Configurable]?

                    init(
                        books: [Book.Configurable] = [],
                        archive: [Book.Configurable]? = nil
                    ) {
                        self.books = books
                        self.archive = archive
                    }

                    init(_ transferable: Shelf.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.books = transferable.books.map {
                            Book.Configurable($0)
                        }
                        self.archive = transferable.archive?.map {
                            Book.Configurable($0)
                        }
                    }
                }

                required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.books = try context.reconcile([], with: configurable.books, orphans: .detach)
                    self.archive = try context.reconcile(nil, with: configurable.archive, orphans: .detach)
                }

                func update(using configurable: Configurable, in context: ModelContext) throws {
                    let booksReconciled = try context.reconcile(self.books, with: configurable.books, orphans: .detach)
                    if booksReconciled.map(\.persistentModelID) != self.books.map(\.persistentModelID) {
                        self.books = booksReconciled
                    }
                    let archiveReconciled = try context.reconcile(self.archive, with: configurable.archive, orphans: .detach)
                    if archiveReconciled?.map(\.persistentModelID) != self.archive?.map(\.persistentModelID) {
                        self.archive = archiveReconciled
                    }
                }
            }

            extension Shelf: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// The `orphans:` argument is forwarded to every `reconcile` call.
    func testOrphansArgumentIsForwarded() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject(orphans: .delete)
            final class Shelf {
                @Relationship var books: [Book] = []
            }
            """#,
            expandedSource: #"""
            @Model
            final class Shelf {
                @Relationship var books: [Book] = []

                typealias ConfigurableType = Configurable

                typealias TransferableType = Transferable

                struct Transferable: SwiftDataTransferable, Identifiable {
                    typealias PersistableType = Shelf
                    typealias ConfigurableType = Shelf.Configurable

                    let persistentModelID: PersistentIdentifier
                    var id: PersistentIdentifier {
                        persistentModelID
                    }
                    let books: [Book.Transferable]

                    init(_ persistentModel: Shelf) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.books = persistentModel.books.map {
                            Book.Transferable($0)
                        }
                    }
                }

                struct Configurable: SwiftDataConfigurable {
                    typealias PersistableType = Shelf
                    typealias TransferableType = Shelf.Transferable

                    private(set) var persistentModelID: PersistentIdentifier? = nil
                    var books: [Book.Configurable]

                    init(
                        books: [Book.Configurable] = []
                    ) {
                        self.books = books
                    }

                    init(_ transferable: Shelf.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.books = transferable.books.map {
                            Book.Configurable($0)
                        }
                    }
                }

                required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.books = try context.reconcile([], with: configurable.books, orphans: .delete)
                }

                func update(using configurable: Configurable, in context: ModelContext) throws {
                    let booksReconciled = try context.reconcile(self.books, with: configurable.books, orphans: .delete)
                    if booksReconciled.map(\.persistentModelID) != self.books.map(\.persistentModelID) {
                        self.books = booksReconciled
                    }
                }
            }

            extension Shelf: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// Excluded, static and computed properties are skipped; observed properties and multi-binding declarations are kept.
    func testExcludedAndNonStoredProperties() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Item {
                var a, b: Int
                var observed: Int = 0 {
                    didSet { print(observed) }
                }
                @IgnoredByDTO var cache: Int = 0
                @IgnoredByDTO var optionalCache: Int?
                @Transient var scratch: String = ""
                static var counter = 0
                var sum: Int { a + b }
                var wrapped: Int {
                    get { a }
                    set { a = newValue }
                }
            }
            """#,
            expandedSource: #"""
            @Model
            final class Item {
                var a, b: Int
                var observed: Int = 0 {
                    didSet { print(observed) }
                }
                var cache: Int = 0
                var optionalCache: Int?
                @Transient var scratch: String = ""
                static var counter = 0
                var sum: Int { a + b }
                var wrapped: Int {
                    get { a }
                    set { a = newValue }
                }

                typealias ConfigurableType = Configurable

                typealias TransferableType = Transferable

                struct Transferable: SwiftDataTransferable, Identifiable {
                    typealias PersistableType = Item
                    typealias ConfigurableType = Item.Configurable

                    let persistentModelID: PersistentIdentifier
                    var id: PersistentIdentifier {
                        persistentModelID
                    }
                    let a: Int
                    let b: Int
                    let observed: Int

                    init(_ persistentModel: Item) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.a = persistentModel.a
                        self.b = persistentModel.b
                        self.observed = persistentModel.observed
                    }
                }

                struct Configurable: SwiftDataConfigurable {
                    typealias PersistableType = Item
                    typealias TransferableType = Item.Transferable

                    private(set) var persistentModelID: PersistentIdentifier? = nil
                    var a: Int
                    var b: Int
                    var observed: Int

                    init(
                        a: Int,
                        b: Int,
                        observed: Int = 0
                    ) {
                        self.a = a
                        self.b = b
                        self.observed = observed
                    }

                    init(_ transferable: Item.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.a = transferable.a
                        self.b = transferable.b
                        self.observed = transferable.observed
                    }
                }

                required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.a = configurable.a
                    self.b = configurable.b
                    self.observed = configurable.observed
                }

                func update(using configurable: Configurable, in context: ModelContext) throws {
                    if self.a != configurable.a {
                        self.a = configurable.a
                    }
                    if self.b != configurable.b {
                        self.b = configurable.b
                    }
                    if self.observed != configurable.observed {
                        self.observed = configurable.observed
                    }
                }
            }

            extension Item: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// A model that declares `id` does not get a synthesized one.
    func testExistingIdPropertyIsNotShadowed() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Item {
                var id: UUID = UUID()
            }
            """#,
            expandedSource: #"""
            @Model
            final class Item {
                var id: UUID = UUID()

                typealias ConfigurableType = Configurable

                typealias TransferableType = Transferable

                struct Transferable: SwiftDataTransferable, Identifiable {
                    typealias PersistableType = Item
                    typealias ConfigurableType = Item.Configurable

                    let persistentModelID: PersistentIdentifier
                    let id: UUID

                    init(_ persistentModel: Item) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.id = persistentModel.id
                    }
                }

                struct Configurable: SwiftDataConfigurable {
                    typealias PersistableType = Item
                    typealias TransferableType = Item.Transferable

                    private(set) var persistentModelID: PersistentIdentifier? = nil
                    var id: UUID

                    init(
                        id: UUID = UUID()
                    ) {
                        self.id = id
                    }

                    init(_ transferable: Item.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.id = transferable.id
                    }
                }

                required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.id = configurable.id
                }

                func update(using configurable: Configurable, in context: ModelContext) throws {
                    if self.id != configurable.id {
                        self.id = configurable.id
                    }
                }
            }

            extension Item: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// Module-qualified attributes and relationship types are recognized.
    func testQualifiedAttributesAndTypes() {
        assertMacroExpansion(
            #"""
            @SwiftData.Model @DataTransferObject
            final class Item {
                @SwiftData.Relationship var owner: Library.Owner?
                @SwiftData.Transient var scratch: String = ""
            }
            """#,
            expandedSource: #"""
            @SwiftData.Model
            final class Item {
                @SwiftData.Relationship var owner: Library.Owner?
                @SwiftData.Transient var scratch: String = ""

                typealias ConfigurableType = Configurable

                typealias TransferableType = Transferable

                struct Transferable: SwiftDataTransferable, Identifiable {
                    typealias PersistableType = Item
                    typealias ConfigurableType = Item.Configurable

                    let persistentModelID: PersistentIdentifier
                    var id: PersistentIdentifier {
                        persistentModelID
                    }
                    let owner: PersistentIdentifier?

                    init(_ persistentModel: Item) {
                        self.persistentModelID = persistentModel.persistentModelID
                        self.owner = persistentModel.owner?.persistentModelID
                    }
                }

                struct Configurable: SwiftDataConfigurable {
                    typealias PersistableType = Item
                    typealias TransferableType = Item.Transferable

                    private(set) var persistentModelID: PersistentIdentifier? = nil
                    var owner: PersistentIdentifier?

                    init(
                        owner: PersistentIdentifier? = nil
                    ) {
                        self.owner = owner
                    }

                    init(_ transferable: Item.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                        self.owner = transferable.owner
                    }
                }

                required init(_ configurable: Configurable, in context: ModelContext) throws {
                    self.owner = try context.resolveRelationship(configurable.owner, as: Library.Owner.self)
                }

                func update(using configurable: Configurable, in context: ModelContext) throws {
                    if self.owner?.persistentModelID != configurable.owner {
                        self.owner = try context.resolveRelationship(configurable.owner, as: Library.Owner.self)
                    }
                }
            }

            extension Item: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    /// A model without properties still gets the full pipeline.
    func testEmptyModel() {
        assertMacroExpansion(
            #"""
            @Model @DataTransferObject
            final class Marker {
            }
            """#,
            expandedSource: #"""
            @Model
            final class Marker {

                typealias ConfigurableType = Configurable

                typealias TransferableType = Transferable

                struct Transferable: SwiftDataTransferable, Identifiable {
                    typealias PersistableType = Marker
                    typealias ConfigurableType = Marker.Configurable

                    let persistentModelID: PersistentIdentifier
                    var id: PersistentIdentifier {
                        persistentModelID
                    }

                    init(_ persistentModel: Marker) {
                        self.persistentModelID = persistentModel.persistentModelID
                    }
                }

                struct Configurable: SwiftDataConfigurable {
                    typealias PersistableType = Marker
                    typealias TransferableType = Marker.Transferable

                    private(set) var persistentModelID: PersistentIdentifier? = nil

                    init() {
                    }

                    init(_ transferable: Marker.Transferable) {
                        self.persistentModelID = transferable.persistentModelID
                    }
                }

                required init(_ configurable: Configurable, in context: ModelContext) throws {
                }

                func update(using configurable: Configurable, in context: ModelContext) throws {
                }
            }

            extension Marker: SwiftDataPersistable {
            }
            """#,
            macroSpecs: testMacros
        )
    }
}

#endif
