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
//  Fixtures.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import Foundation
import SwiftData
import Tools4SwiftData

// MARK: - Models

/// A model with plain attributes only, and custom validation.
@Model @DataTransferObject
final class Author {
    var name: String = ""
    var born: Date?
}

/// A model with a cascading to-many relationship that deletes its orphans,
/// and an optional to-one relationship.
@Model @DataTransferObject(orphans: .delete)
final class Shelf {
    var label: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Book.shelf)
    var books: [Book] = []

    @Relationship(deleteRule: .nullify)
    var curator: Author?
}

/// A model with a required to-one relationship, an inverse to-one
/// relationship, a collection attribute and an excluded property.
@Model @DataTransferObject
final class Book {
    var title: String = ""
    var pages: Int = 0
    var tags: [String] = []

    @Relationship
    var shelf: Shelf?

    @Relationship
    var author: Author

    @IgnoredByDTO
    var readCount: Int = 0
}

/// A model with an optional to-many relationship that only detaches its
/// orphans, used to hold books that also belong to a shelf.
@Model @DataTransferObject
final class ReadingList {
    var name: String = ""

    @Relationship(deleteRule: .nullify)
    var books: [Book]? = []
}

// MARK: - Validation

struct InvalidDraft: Error, Equatable {
    let reason: String
}

extension Author.Configurable {
    func validate(for scope: SwiftDataValidationScope) throws {
        if name.isEmpty {
            throw InvalidDraft(reason: "empty name")
        }
    }
}

extension Book.Configurable {
    func validate(for scope: SwiftDataValidationScope) throws {
        if pages < 0 {
            throw InvalidDraft(reason: "negative pages")
        }
    }
}

// MARK: - Store

/// An in-memory store with one manager per model type.
///
/// Every test creates its own store, so tests are independent and can run
/// in parallel.
struct TestStore {
    let provider: SwiftDataProvider
    let authors: SwiftDataManager<Author>
    let shelves: SwiftDataManager<Shelf>
    let books: SwiftDataManager<Book>
    let lists: SwiftDataManager<ReadingList>

    static let types: [any PersistentModel.Type] = [Author.self, Shelf.self, Book.self, ReadingList.self]

    init() throws {
        provider = try SwiftDataProvider.inMemory(for: Self.types)
        authors = provider.createManager()
        shelves = provider.createManager()
        books = provider.createManager()
        lists = provider.createManager()
    }

    /// Inserts an author and returns its identifier.
    func author(_ name: String = "Ursula") async throws -> PersistentIdentifier {
        try await authors.insert(Author.Configurable(name: name)).persistentModelID
    }
}
