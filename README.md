# Tools4SwiftData

<div align="center">
  <a href="https://developer.apple.com/xcode/swiftdata">
    <img src="https://developer.apple.com/assets/elements/icons/swiftdata/swiftdata-96x96_2x.png" width="150" height="150">
  </a>

  [![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/download/)
  <p>A concurrency-safe toolkit for SwiftData under Swift 6 strict concurrency.<br>Models stay inside an actor; only Sendable snapshots and drafts cross isolation boundaries.</p>

</div>

---

## Why

SwiftData models and `ModelContext` are not `Sendable`, so under Swift 6 they cannot be passed between actors or tasks. Tools4SwiftData keeps every model inside a `@ModelActor` and exchanges two kinds of value types with the rest of the app:

- **`Transferable`**: an immutable, `Sendable` snapshot of a model, used to read data.
- **`Configurable`**: a mutable, `Sendable` draft, used to create and update models.

The `@DataTransferObject` macro generates both types, and the code that converts between them and the model, from your `@Model` class.

## Requirements

- Swift 6.0 (Xcode 16) or later
- iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1

## Installation

Add the package in Xcode with **File > Add Packages**, using:

```plaintext
https://github.com/iOmega8561/Tools4SwiftData.git
```

---

## Defining models

```swift
import SwiftData
import Tools4SwiftData

@Model @DataTransferObject
final class Chat {
    var title: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message] = []

    @Relationship
    var owner: User?

    @IgnoredByDTO
    var cachedPreview: String = ""
}

@Model @DataTransferObject
final class Message {
    var text: String = ""

    @Relationship
    var chat: Chat?
}
```

The macro adds to `Chat`:

| Member | Purpose |
|---|---|
| `Chat.Transferable` | Immutable snapshot, `Hashable`, `Identifiable`, `Sendable` |
| `Chat.Configurable` | Mutable draft, `Hashable`, `Sendable`, with a memberwise initializer |
| `init(_:in:)` | Builds a model from a draft |
| `update(using:in:)` | Applies a draft to an existing model, writing only what changed |
| `SwiftDataPersistable` conformance | Lets the model be used with `SwiftDataManager` |

### Rules

- **Relationships need an explicit `@Relationship` attribute.** A macro only sees syntax, so it cannot tell a `@Model` class from a plain struct. Supported types are `Model`, `Model?`, `[Model]` and `[Model]?`, and the related model must use `@DataTransferObject` too.
- **To-one relationships become identifiers.** In both DTOs, `owner` is a `PersistentIdentifier` (optional in `Configurable`). This is what keeps bidirectional relationships from recursing.
- **To-many relationships are embedded by value**: `Chat.Transferable.messages` is `[Message.Transferable]`. A many-to-many relationship would therefore recurse forever: mark one of its sides with `@IgnoredByDTO`.
- **Every attribute type must be `Hashable` and `Sendable`**, because the generated structs are.
- **Excluded properties need a default value.** This applies to `@IgnoredByDTO` and SwiftData's `@Transient` properties, which the generated initializer does not set.
- **Stored properties need an explicit type annotation**, unless they are excluded.

The macro reports a compile-time error, on the offending line, when one of these rules is broken.

### Orphans

When an update removes an element from a to-many relationship, the element is only detached by default: it stays in the store, and the relationship's delete rule decides its fate. To delete removed elements instead:

```swift
@Model @DataTransferObject(orphans: .delete)
final class Chat { ... }
```

Keep the default for many-to-many relationships and shared models.

### Validation

Drafts are validated before being persisted. The default implementation accepts everything; add your rules in an extension:

```swift
extension Chat.Configurable {
    func validate(for scope: SwiftDataValidationScope) throws {
        guard !title.isEmpty else { throw ChatError.emptyTitle }
    }
}
```

`scope` is `.creation` or `.update`. On a `public` model the method must be declared `public`. Nested drafts of to-many relationships are validated too.

---

## Persistence

### SwiftDataProvider

The provider owns the `ModelContainer`. A single store can hold any number of model types:

```swift
let provider = try SwiftDataProvider(
    for: [Chat.self, Message.self, User.self],
    storeName: "Chats",
    in: URL.applicationSupportDirectory
)
```

The store name is the identity of the store on disk: changing it points to a new, empty store. For versioned schemas, pass a `Schema` and a migration plan to `init(schema:storeName:in:migrationPlan:)`. For anything else (CloudKit, App Groups...), build the container yourself and use `init(container:)`. `SwiftDataProvider.inMemory(for:)` is meant for tests and previews.

### SwiftDataManager

A manager is an actor that performs every operation for one model type:

```swift
let chats = await provider.createBackgroundManager(for: Chat.self)

let chat = try await chats.insert(Chat.Configurable(title: "Hello"))
let all = try await chats.fetch()
let recent = try await chats.fetch(FetchDescriptor(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))

var draft = Chat.Configurable(chat)
draft.title = "Renamed"
try await chats.update(id: chat.persistentModelID, with: draft)

try await chats.update(id: chat.persistentModelID) { model in
    model.cachedPreview = ""
}

try await chats.delete(id: chat.persistentModelID)
```

Every write is either saved or rolled back, so a failed operation never leaves pending changes behind. Returned snapshots are taken after the save and carry the permanent identifier.

A `@ModelActor` works on the thread it was created on. `createBackgroundManager(for:)` creates the manager off the main thread; `createManager(for:)` creates it on the calling thread.

Build a `FetchDescriptor` right where you call `fetch(_:)`: a descriptor created on the spot can always be sent to the actor.

### Errors

Operations throw `Tools4SwiftDataError` (`notFound`, `identifierMismatch`, `missingIdentifier`, `missingRelationship`, `unresolvedRelationship`), validation errors from your `validate(for:)`, or errors from SwiftData. All library errors have localized descriptions.

---

## SwiftUI

`ManagedQuery` holds a list of `QueryResult` values and exposes the CRUD operations through its projected value. `QueryResult` pairs a snapshot with an editable draft, and should be installed on the view that edits the item:

```swift
struct ChatList: View {
    @ManagedQuery var chats: [QueryResult<Chat>]

    init(manager: SwiftDataManager<Chat>) {
        _chats = ManagedQuery(dataManager: manager, sortBy: [SortDescriptor(\.title)])
    }

    var body: some View {
        List {
            ForEach(chats) { ChatRow(result: $0) }
                .onDelete { offsets in Task { try await $chats.delete(at: offsets) } }
        }
        .task { try? await $chats.refresh() }
    }
}

struct ChatRow: View {
    @QueryResult var chat: Chat.Configurable

    init(result: QueryResult<Chat>) {
        _chat = result
    }

    var body: some View {
        TextField("Title", text: $chat.title)
            .onSubmit { Task { try await $chat.commit() } }
    }
}
```

`ManagedQuery` starts empty: load it with `refresh()`. Insertions, commits and deletions are persisted first and reflected in the list only on success.

A draft without changes follows the stored item, so a refresh shows fresh data. A draft with changes is kept; `$chat.hasConflict` tells whether the stored item changed in the meantime, `$chat.hasChanges` whether there is anything to commit, and `$chat.reset()` discards the changes.

Only a `QueryResult` installed on a view sees the user's edits. To commit a draft obtained elsewhere, use `$chats.commit(draft:)`.

---

## License

Tools4SwiftData is available under the Apache License 2.0. See [LICENSE](LICENSE).
