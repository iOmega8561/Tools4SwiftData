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
//  ProviderTests.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import Foundation
import SwiftData
import Testing
import Tools4SwiftData

@Suite("SwiftDataProvider")
struct ProviderTests {

    @Test("managers created by the same provider share the store")
    func managersShareTheStore() async throws {
        let provider = try SwiftDataProvider.inMemory(for: TestStore.types)
        let writer: SwiftDataManager<Author> = provider.createManager()
        let reader: SwiftDataManager<Author> = await provider.createBackgroundManager()

        let saved = try await writer.insert(Author.Configurable(name: "Ursula"))

        #expect(try await reader.fetch(id: saved.persistentModelID) == saved)
    }

    @Test("in-memory providers are independent")
    func inMemoryProvidersAreIndependent() async throws {
        let first = try SwiftDataProvider.inMemory(for: TestStore.types)
        let second = try SwiftDataProvider.inMemory(for: TestStore.types)

        try await first.createManager(for: Author.self).insert(Author.Configurable(name: "Ursula"))

        #expect(try await second.createManager(for: Author.self).fetch().isEmpty)
    }

    @Test("init(container:) wraps the given container")
    func wrapsContainer() throws {
        let schema = Schema(TestStore.types)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )

        #expect(SwiftDataProvider(container: container).persistenceContainer === container)
    }

    @Test("a file store is named after storeName and keeps its data")
    func fileStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tools4SwiftDataTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = try SwiftDataProvider(for: TestStore.types, storeName: "Library", in: directory)
        try await writer.createManager(for: Author.self).insert(Author.Configurable(name: "Ursula"))

        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Library.sqlite").path))

        let reader = try SwiftDataProvider(for: TestStore.types, storeName: "Library", in: directory)
        #expect(try await reader.createManager(for: Author.self).fetch().map(\.name) == ["Ursula"])
    }
}
