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
//  ManagerTests.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import Foundation
import SwiftData
import Testing
import Tools4SwiftData

@Suite("SwiftDataManager")
struct ManagerTests {

    let store: TestStore

    init() throws {
        store = try TestStore()
    }

    // MARK: - Insert and fetch

    @Test("insert saves the model and returns its snapshot")
    func insertReturnsSnapshot() async throws {
        let born = Date(timeIntervalSince1970: 0)
        let saved = try await store.authors.insert(Author.Configurable(name: "Ursula", born: born))

        #expect(saved.name == "Ursula")
        #expect(saved.born == born)
        #expect(try await store.authors.fetch(id: saved.persistentModelID) == saved)
        #expect(try await store.authors.fetch() == [saved])
    }

    @Test("fetch applies the sort order of the descriptor")
    func fetchSorted() async throws {
        for name in ["Carla", "Anna", "Bruno"] {
            try await store.authors.insert(Author.Configurable(name: name))
        }

        let sorted = try await store.authors.fetch(FetchDescriptor(sortBy: [SortDescriptor(\.name)]))

        #expect(sorted.map(\.name) == ["Anna", "Bruno", "Carla"])
    }

    @Test("fetch applies the predicate and the limit of the descriptor")
    func fetchFiltered() async throws {
        for name in ["Anna", "Bruno", "Anna"] {
            try await store.authors.insert(Author.Configurable(name: name))
        }

        let annas = try await store.authors.fetch(FetchDescriptor(predicate: #Predicate { $0.name == "Anna" }))
        #expect(annas.count == 2)

        var limited = FetchDescriptor<Author>()
        limited.fetchLimit = 1
        #expect(try await store.authors.fetch(limited).count == 1)
    }

    @Test("fetch(id:) returns nil for a model that no longer exists")
    func fetchMissing() async throws {
        let id = try await store.author()
        try await store.authors.delete(id: id)

        #expect(try await store.authors.fetch(id: id) == nil)
    }

    // MARK: - Update

    @Test("update(id:with:) applies a draft")
    func updateWithDraft() async throws {
        let saved = try await store.authors.insert(Author.Configurable(name: "Ursula"))
        var draft = Author.Configurable(saved)
        draft.name = "Ursula K."

        let updated = try await store.authors.update(id: saved.persistentModelID, with: draft)

        #expect(updated.name == "Ursula K.")
        #expect(updated.persistentModelID == saved.persistentModelID)
        #expect(try await store.authors.fetch(id: saved.persistentModelID)?.name == "Ursula K.")
    }

    @Test("an unchanged draft leaves the model as it is")
    func updateWithUnchangedDraft() async throws {
        let saved = try await store.authors.insert(Author.Configurable(name: "Ursula"))

        let updated = try await store.authors.update(id: saved.persistentModelID, with: Author.Configurable(saved))

        #expect(updated == saved)
    }

    @Test("update(id:handler:) runs the closure on the model")
    func updateWithHandler() async throws {
        let id = try await store.author()

        let updated = try await store.authors.update(id: id) { $0.name = "Changed" }

        #expect(updated.name == "Changed")
    }

    @Test("a draft taken from another model is rejected")
    func updateWithForeignDraft() async throws {
        let first = try await store.authors.insert(Author.Configurable(name: "First"))
        let second = try await store.authors.insert(Author.Configurable(name: "Second"))

        await #expect(throws: Tools4SwiftDataError.identifierMismatch(
            expected: second.persistentModelID,
            found: first.persistentModelID
        )) {
            try await store.authors.update(id: second.persistentModelID, with: Author.Configurable(first))
        }
        #expect(try await store.authors.fetch(id: second.persistentModelID)?.name == "Second")
    }

    @Test("updating a model that does not exist throws notFound")
    func updateMissing() async throws {
        let id = try await store.author()
        try await store.authors.delete(id: id)

        await #expect(throws: Tools4SwiftDataError.notFound(id)) {
            try await store.authors.update(id: id, with: Author.Configurable(name: "Ghost"))
        }
        await #expect(throws: Tools4SwiftDataError.notFound(id)) {
            try await store.authors.update(id: id) { _ in }
        }
    }

    @Test("an error thrown by the handler rolls the changes back")
    func handlerErrorRollsBack() async throws {
        let id = try await store.author("Original")

        await #expect(throws: InvalidDraft(reason: "handler")) {
            try await store.authors.update(id: id) { author in
                author.name = "Changed"
                throw InvalidDraft(reason: "handler")
            }
        }
        #expect(try await store.authors.fetch(id: id)?.name == "Original")
    }

    // MARK: - Delete

    @Test("delete removes the model")
    func delete() async throws {
        let id = try await store.author()

        try await store.authors.delete(id: id)

        #expect(try await store.authors.fetch().isEmpty)
    }

    @Test("deleting a missing model is ignored by default and an error on request")
    func deleteMissing() async throws {
        let id = try await store.author()
        try await store.authors.delete(id: id)

        try await store.authors.delete(id: id)
        await #expect(throws: Tools4SwiftDataError.notFound(id)) {
            try await store.authors.delete(id: id, ignoreNonExistent: false)
        }
    }

    // MARK: - Validation

    @Test("an invalid draft is not inserted")
    func insertValidation() async throws {
        await #expect(throws: InvalidDraft(reason: "empty name")) {
            try await store.authors.insert(Author.Configurable(name: ""))
        }
        #expect(try await store.authors.fetch().isEmpty)
    }

    @Test("skipValidation inserts a draft that would be rejected")
    func insertSkippingValidation() async throws {
        try await store.authors.insert(Author.Configurable(name: ""), skipValidation: true)

        #expect(try await store.authors.fetch().count == 1)
    }

    @Test("an invalid draft does not update the model")
    func updateValidation() async throws {
        let saved = try await store.authors.insert(Author.Configurable(name: "Ursula"))
        var draft = Author.Configurable(saved)
        draft.name = ""

        await #expect(throws: InvalidDraft(reason: "empty name")) {
            try await store.authors.update(id: saved.persistentModelID, with: draft)
        }
        #expect(try await store.authors.fetch(id: saved.persistentModelID)?.name == "Ursula")
    }
}
