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
//  RelationshipTests.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import Foundation
import SwiftData
import Testing
import Tools4SwiftData

@Suite("Relationships")
struct RelationshipTests {

    let store: TestStore

    init() throws {
        store = try TestStore()
    }

    /// Inserts a shelf with one book per title, all by the same author.
    private func shelf(_ titles: [String], by author: PersistentIdentifier) async throws -> Shelf.Transferable {
        let books = titles.map { Book.Configurable(title: $0, pages: 100, author: author) }
        return try await store.shelves.insert(Shelf.Configurable(label: "Fiction", books: books))
    }

    // MARK: - To-one

    @Test("a required to-one relationship is resolved from its identifier")
    func requiredToOne() async throws {
        let author = try await store.author()

        let book = try await store.books.insert(Book.Configurable(title: "Dune", author: author))

        #expect(book.author == author)
    }

    @Test("an optional to-one relationship can be set, changed and cleared")
    func optionalToOne() async throws {
        let first = try await store.author("First")
        let second = try await store.author("Second")
        let saved = try await store.shelves.insert(Shelf.Configurable(label: "Classics", curator: first))
        #expect(saved.curator == first)

        var draft = Shelf.Configurable(saved)
        draft.curator = second
        #expect(try await store.shelves.update(id: saved.persistentModelID, with: draft).curator == second)

        draft.curator = nil
        #expect(try await store.shelves.update(id: saved.persistentModelID, with: draft).curator == nil)
        #expect(try await store.authors.fetch().count == 2)
    }

    @Test("a missing required relationship fails and saves nothing")
    func missingRequiredToOne() async throws {
        await #expect(throws: Tools4SwiftDataError.missingRelationship) {
            try await store.books.insert(Book.Configurable(title: "Orphan"))
        }
        #expect(try await store.books.fetch().isEmpty)
    }

    @Test("a relationship to a deleted model fails")
    func unresolvedToOne() async throws {
        let author = try await store.author()
        try await store.authors.delete(id: author)

        await #expect(throws: Tools4SwiftDataError.unresolvedRelationship(author)) {
            try await store.books.insert(Book.Configurable(title: "Dune", author: author))
        }
        #expect(try await store.books.fetch().isEmpty)
    }

    // MARK: - To-many

    @Test("nested drafts become new models")
    func nestedInsert() async throws {
        let author = try await store.author()

        let saved = try await shelf(["Dune", "Emma"], by: author)

        #expect(saved.books.map(\.title).sorted() == ["Dune", "Emma"])
        #expect(saved.books.allSatisfy { $0.author == author })
        #expect(try await store.books.fetch().count == 2)
    }

    @Test("a nested draft that fails stops the whole insertion")
    func nestedFailureRollsBack() async throws {
        let author = try await store.author()
        let books = [
            Book.Configurable(title: "Valid", author: author),
            Book.Configurable(title: "Invalid"),
        ]

        await #expect(throws: Tools4SwiftDataError.missingRelationship) {
            try await store.shelves.insert(Shelf.Configurable(label: "Broken", books: books))
        }
        #expect(try await store.shelves.fetch().isEmpty)
        #expect(try await store.books.fetch().isEmpty)
    }

    @Test("nested drafts are validated")
    func nestedValidation() async throws {
        let author = try await store.author()
        let books = [Book.Configurable(title: "Negative", pages: -1, author: author)]

        await #expect(throws: InvalidDraft(reason: "negative pages")) {
            try await store.shelves.insert(Shelf.Configurable(label: "Broken", books: books))
        }
        #expect(try await store.shelves.fetch().isEmpty)
    }

    @Test("an update edits existing models in place, adds new ones and deletes orphans")
    func reconcileWithDeletePolicy() async throws {
        let author = try await store.author()
        let saved = try await shelf(["Dune", "Emma"], by: author)
        let dune = try #require(saved.books.first { $0.title == "Dune" })

        var draft = Shelf.Configurable(saved)
        draft.books.removeAll { $0.title == "Emma" }
        let duneIndex = try #require(draft.books.firstIndex { $0.persistentModelID == dune.persistentModelID })
        draft.books[duneIndex].title = "Dune Messiah"
        draft.books.append(Book.Configurable(title: "Kindred", author: author))

        let updated = try await store.shelves.update(id: saved.persistentModelID, with: draft)

        #expect(updated.books.map(\.title).sorted() == ["Dune Messiah", "Kindred"])
        #expect(updated.books.contains { $0.persistentModelID == dune.persistentModelID && $0.title == "Dune Messiah" })
        #expect(try await store.books.fetch().map(\.title).sorted() == ["Dune Messiah", "Kindred"])
    }

    @Test("the detach policy keeps removed models in the store")
    func reconcileWithDetachPolicy() async throws {
        let author = try await store.author()
        let list = try await store.lists.insert(ReadingList.Configurable(
            name: "Summer",
            books: [Book.Configurable(title: "Dune", author: author)]
        ))

        var draft = ReadingList.Configurable(list)
        draft.books = []
        let updated = try await store.lists.update(id: list.persistentModelID, with: draft)

        #expect((updated.books ?? []).isEmpty)
        #expect(try await store.books.fetch().count == 1)
    }

    @Test("clearing an optional to-many relationship detaches its models")
    func clearOptionalToMany() async throws {
        let author = try await store.author()
        let list = try await store.lists.insert(ReadingList.Configurable(
            name: "Summer",
            books: [Book.Configurable(title: "Dune", author: author)]
        ))

        var draft = ReadingList.Configurable(list)
        draft.books = nil
        let updated = try await store.lists.update(id: list.persistentModelID, with: draft)

        #expect((updated.books ?? []).isEmpty)
        #expect(try await store.books.fetch().count == 1)
    }

    @Test("a model taken from another relationship is reused, not duplicated")
    func movedModelIsReused() async throws {
        let author = try await store.author()
        let saved = try await shelf(["Dune"], by: author)
        let dune = try #require(saved.books.first)

        let list = try await store.lists.insert(ReadingList.Configurable(
            name: "Favourites",
            books: [Book.Configurable(dune)]
        ))

        #expect(list.books?.map(\.persistentModelID) == [dune.persistentModelID])
        #expect(try await store.books.fetch().count == 1)
    }

    @Test("a nested draft that refers to a deleted model fails")
    func nestedDraftOfDeletedModel() async throws {
        let author = try await store.author()
        let saved = try await shelf(["Dune"], by: author)
        let dune = try #require(saved.books.first)
        try await store.books.delete(id: dune.persistentModelID)

        await #expect(throws: Tools4SwiftDataError.unresolvedRelationship(dune.persistentModelID)) {
            try await store.lists.insert(ReadingList.Configurable(name: "Ghosts", books: [Book.Configurable(dune)]))
        }
    }

    // MARK: - Snapshots and drafts

    @Test("snapshots and drafts round-trip without changes")
    func roundTrip() async throws {
        let author = try await store.author()
        let saved = try await store.books.insert(Book.Configurable(
            title: "Dune",
            pages: 412,
            tags: ["sci-fi", "classic"],
            author: author
        ))

        let draft = Book.Configurable(saved)
        #expect(draft.persistentModelID == saved.persistentModelID)
        #expect(draft.title == "Dune" && draft.pages == 412 && draft.tags == ["sci-fi", "classic"])
        #expect(draft.author == author)

        let updated = try await store.books.update(id: saved.persistentModelID, with: draft)
        #expect(updated == saved)
    }

    @Test("excluded properties are not touched by drafts")
    func excludedPropertyIsPreserved() async throws {
        let author = try await store.author()
        let saved = try await store.books.insert(Book.Configurable(title: "Dune", author: author))
        try await store.books.update(id: saved.persistentModelID) { $0.readCount = 3 }

        var draft = Book.Configurable(saved)
        draft.title = "Dune (2nd ed.)"
        try await store.books.update(id: saved.persistentModelID, with: draft)

        // The excluded property is not part of any snapshot: check it on the model.
        try await store.books.update(id: saved.persistentModelID) { book in
            guard book.readCount == 3 else { throw InvalidDraft(reason: "readCount was reset") }
        }
    }
}
