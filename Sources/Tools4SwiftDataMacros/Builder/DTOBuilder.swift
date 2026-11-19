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
//  DTOBuilder.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import SwiftSyntax

/// The two data transfer objects generated for every `@Model` class.
enum DTOKind: Sendable {

    /// The immutable snapshot, built from the persistent model.
    case transferable

    /// The mutable draft, built from a `Transferable` or from scratch.
    case configurable

    /// The name of the nested struct.
    var typeName: String {
        switch self {
        case .transferable: "Transferable"
        case .configurable: "Configurable"
        }
    }
}

/// Generates the `Transferable` or the `Configurable` struct of a `@Model`
/// class.
///
/// Both structs share the same property layout, derived from each
/// `StoredProperty`'s shape:
///
/// | Shape               | `Transferable`               | `Configurable`               |
/// |---------------------|------------------------------|------------------------------|
/// | attribute `T`       | `let x: T`                   | `var x: T`                   |
/// | to-one `M`          | `let x: PersistentIdentifier`| `var x: PersistentIdentifier?` |
/// | to-one `M?`         | `let x: PersistentIdentifier?` | `var x: PersistentIdentifier?` |
/// | to-many `[M]`       | `let x: [M.Transferable]`    | `var x: [M.Configurable]`    |
/// | to-many `[M]?`      | `let x: [M.Transferable]?`   | `var x: [M.Configurable]?`   |
///
/// A to-one relationship is optional in every `Configurable` because a draft
/// may be incomplete; resolution fails at persistence time if a required
/// relationship is missing.
///
/// `Hashable` and `Sendable` come from the `SwiftDataTransferable` and
/// `SwiftDataConfigurable` protocols, so every attribute type must be
/// `Hashable` and `Sendable` for the generated code to compile.
struct DTOBuilder {

    let kind: DTOKind
    let className: String
    let access: String
    let properties: [StoredProperty]

    init(kind: DTOKind, className: String, access: String, properties: [StoredProperty]) {
        self.kind = kind
        self.className = className
        self.access = access
        self.properties = properties
    }

    /// Generates the struct declaration.
    func generate() -> DeclSyntax {
        switch kind {
        case .transferable: generateTransferable()
        case .configurable: generateConfigurable()
        }
    }

    // MARK: - Structs

    private func generateTransferable() -> DeclSyntax {
        let declarations = properties.map { "\(access)let \($0.name): \(declaredType(for: $0))" }
        let assignments = properties.map { "self.\($0.name) = \(conversion(for: $0, from: "persistentModel"))" }

        // A model that declares its own `id` already satisfies `Identifiable`.
        let idProperty = properties.contains { $0.name == "id" }
            ? ""
            : "\(access)var id: PersistentIdentifier { persistentModelID }"

        return """
        \(raw: access)struct Transferable: SwiftDataTransferable, Identifiable {
            \(raw: access)typealias PersistableType = \(raw: className)
            \(raw: access)typealias ConfigurableType = \(raw: className).Configurable

            \(raw: access)let persistentModelID: PersistentIdentifier
            \(raw: idProperty)
            \(raw: declarations.joined(separator: "\n"))

            \(raw: access)init(_ persistentModel: \(raw: className)) {
                self.persistentModelID = persistentModel.persistentModelID
                \(raw: assignments.joined(separator: "\n"))
            }
        }
        """
    }

    private func generateConfigurable() -> DeclSyntax {
        let declarations = properties.map { "\(access)var \($0.name): \(declaredType(for: $0))" }
        let assignments = properties.map { "self.\($0.name) = \(conversion(for: $0, from: "transferable"))" }
        let parameters = properties.map { property in
            let parameter = "\(property.name): \(declaredType(for: property))"
            guard let defaultValue = memberwiseDefault(for: property) else { return parameter }
            return "\(parameter) = \(defaultValue)"
        }
        let memberwiseAssignments = properties.map { "self.\($0.name) = \($0.name)" }

        return """
        \(raw: access)struct Configurable: SwiftDataConfigurable {
            \(raw: access)typealias PersistableType = \(raw: className)
            \(raw: access)typealias TransferableType = \(raw: className).Transferable

            \(raw: access)private(set) var persistentModelID: PersistentIdentifier? = nil
            \(raw: declarations.joined(separator: "\n"))

            \(raw: access)init(\(raw: parameters.joined(separator: ",\n"))) {
                \(raw: memberwiseAssignments.joined(separator: "\n"))
            }

            \(raw: access)init(_ transferable: \(raw: className).Transferable) {
                self.persistentModelID = transferable.persistentModelID
                \(raw: assignments.joined(separator: "\n"))
            }
        }
        """
    }

    // MARK: - Per-property generation

    /// The type of the property inside the generated struct.
    func declaredType(for property: StoredProperty) -> String {
        switch property.shape {
        case .attribute:
            return property.type
        case .toOne(_, let isOptional):
            return kind == .transferable && !isOptional ? "PersistentIdentifier" : "PersistentIdentifier?"
        case .toMany(let element, let isOptional):
            return "[\(element).\(kind.typeName)]" + (isOptional ? "?" : "")
        }
    }

    /// The expression converting the property of `source` (a persistent model
    /// for `Transferable`, a `Transferable` for `Configurable`).
    func conversion(for property: StoredProperty, from source: String) -> String {
        let value = "\(source).\(property.name)"

        switch (kind, property.shape) {
        case (_, .attribute):
            return value
        case (.transferable, .toOne(_, let isOptional)):
            return isOptional ? "\(value)?.persistentModelID" : "\(value).persistentModelID"
        case (.configurable, .toOne):
            return value
        case (_, .toMany(let element, let isOptional)):
            let map = isOptional ? "?.map" : ".map"
            return "\(value)\(map) { \(element).\(kind.typeName)($0) }"
        }
    }

    /// The default value of the property's parameter in the memberwise
    /// initializer of `Configurable`.
    func memberwiseDefault(for property: StoredProperty) -> String? {
        switch property.shape {
        case .attribute:
            return property.defaultValue
        case .toOne:
            return "nil"
        case .toMany(_, let isOptional):
            return isOptional ? "nil" : "[]"
        }
    }
}
