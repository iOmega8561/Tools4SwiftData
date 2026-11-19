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
//  SupportTests.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import Foundation
import SwiftData
import Testing
import Tools4SwiftData

@Suite("Errors")
struct ErrorTests {

    @Test("every error has a localized description")
    func descriptions() async throws {
        let store = try TestStore()
        let first = try await store.author("First")
        let second = try await store.author("Second")

        let errors: [Tools4SwiftDataError] = [
            .notFound(first),
            .identifierMismatch(expected: first, found: second),
            .missingIdentifier,
            .missingRelationship,
            .unresolvedRelationship(first),
        ]

        for error in errors {
            let description = try #require(error.errorDescription)
            #expect(!description.isEmpty)
            // A missing translation would return the key itself.
            #expect(!description.hasPrefix("error-"), "\(error) has no entry in the string catalog")
        }
        #expect(Set(errors.compactMap(\.errorDescription)).count == errors.count)
    }
}

@Suite("QueryResult")
struct QueryResultTests {

    /// Collects the identifiers of the committed results.
    private actor CommitLog {
        var ids: [PersistentIdentifier] = []
        func append(_ id: PersistentIdentifier) { ids.append(id) }
    }

    // Only the parts of QueryResult that do not read its @State are tested
    // here: outside a view hierarchy SwiftUI never installs that state.

    @Test("identity and equality come from the snapshot")
    func identityAndEquality() async throws {
        let store = try TestStore()
        let first = try await store.authors.insert(Author.Configurable(name: "First"))
        let second = try await store.authors.insert(Author.Configurable(name: "Second"))

        let a = QueryResult<Author>(original: first) { _ in }
        let b = QueryResult<Author>(original: first) { _ in }
        let c = QueryResult<Author>(original: second) { _ in }

        #expect(a.id == first.persistentModelID)
        #expect(a == b)
        #expect(a != c)
        #expect(Set([a, b, c]).count == 2)
    }

    @Test("commit hands the result itself to the callback")
    func commitCallsTheCallback() async throws {
        let store = try TestStore()
        let saved = try await store.authors.insert(Author.Configurable(name: "Ursula"))
        let log = CommitLog()

        let result = QueryResult<Author>(original: saved) { committed in
            await log.append(committed.id)
        }
        try await result.commit()
        try await result.projectedValue.commit()

        #expect(await log.ids == [saved.persistentModelID, saved.persistentModelID])
    }

    @Test("a failing callback propagates its error")
    func commitPropagatesErrors() async throws {
        let store = try TestStore()
        let saved = try await store.authors.insert(Author.Configurable(name: "Ursula"))

        let result = QueryResult<Author>(original: saved) { _ in
            throw InvalidDraft(reason: "commit")
        }

        await #expect(throws: InvalidDraft(reason: "commit")) {
            try await result.commit()
        }
    }
}
