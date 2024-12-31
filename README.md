# Tools4SwiftData

<div align="center">
  <a href="https://developer.apple.com/xcode/swiftdata">
    <img src="https://developer.apple.com/assets/elements/icons/swiftdata/swiftdata-96x96_2x.png" width="150" height="150">
  </a>

  [![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/download/)
  <p>A comprehensive framework for streamlined data persistence, transfer, and management in Swift.<br>Leverages Swift's concurrency model and structured protocols for reliable data workflows.</p>
  
</div>

---

## Features

**Tools4SwiftData** simplifies data operations in Swift with robust and flexible tools, including:

### **Protocols**
- **`SwiftDataTransferable`**: Represents a model suitable for data transfer, initialized from a persistent model.
- **`SwiftDataPersistable`**: Defines a model capable of persisting data, ensuring all stored models are validated.
- **`SwiftDataConfigurable`**: A configurable model interface with validation logic to guarantee correctness before use.

### **Components**
- **`SwiftDataProvider`**: A class providing shared access to the persistence container for data management.
- **`SwiftDataManager`**: An actor designed for thread-safe CRUD operations on your data store, ensuring data integrity across contexts.

### **Concurrency-Safe Design**
- Strict adherence to Swift’s concurrency model using `Sendable` and `@ModelActor`.

---

## Installation

### Swift Package Manager (SPM)
Add the package to your Xcode project:

1. In Xcode, go to **File > Add Packages**.
2. Enter the URL for this repository:  
   ```plaintext
   https://github.com/iOmega8561/Tools4SwiftData.git
   ```
3. Choose the appropriate version rules and add the package.

---

## Usage

### **SwiftDataTransferable**
Define a model suitable for data transfer:
```swift
struct MyTransferableModel: SwiftDataTransferable {
    typealias PersistableType = MyPersistableModel
    let persistentModelID: PersistentIdentifier

    init(_ persistentModel: MyPersistableModel) {
        self.persistentModelID = persistentModel.persistentModelID
    }
}
```

### **SwiftDataPersistable**
Implement a persistent model initialized from a validated configuration:
```swift
struct MyPersistableModel: SwiftDataPersistable {
    typealias ConfigurableType = MyConfigurableModel
    static let filePrefix = "MyModel"

    init(_ configurableModel: MyConfigurableModel) {
        // Initialize from configuration
    }
}
```

### **SwiftDataProvider**
Create a shared persistence container:
```swift
let dataProvider = try SwiftDataProvider<MyTransferableModel>(
    writeDataStoreAt: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
)
```

### **SwiftDataManager**
Perform CRUD operations safely using `SwiftDataManager`:
```swift
let dataManager = dataProvider.managerCreator()

// Add an item
try await dataManager.addItem(configurableModel)

// Fetch items
let items = try await dataManager.fetch()

// Update an item
try await dataManager.updateItem(id: itemID) { item in
    item.property = newValue
}

// Delete an item
try await dataManager.deleteItem(id: itemID)
```

---

## Concurrency and Safety

This package is built with Swift’s strict concurrency rules in mind, ensuring data integrity and safe access across multiple threads. By leveraging actors, all data operations are thread-safe and efficient.
