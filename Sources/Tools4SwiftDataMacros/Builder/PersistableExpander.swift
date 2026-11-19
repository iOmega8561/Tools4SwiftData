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
//  PersistableExpander.swift
//  Tools4SwiftData
//
//  Created by Giuseppe Rocco on 16/05/2026.
//

import SwiftSyntax

/// Performs the member expansion of `@DataTransferObject` on a `@Model` class.
///
/// The expansion works in two steps:
/// 1. `PropertyExtractor` collects the stored properties that take part in
///    the pipeline, each classified by its `PropertyShape`.
/// 2. `DTOBuilder` generates the `Transferable` and `Configurable` structs,
///    while this type generates `init(_:in:)` and `update(using:in:)`.
///
/// Relationship handling is delegated to the `ModelContext` helpers defined
/// in the `Tools4SwiftData` library (`resolveRelationship`,
/// `resolveRequiredRelationship`, `reconcile`), which keeps the generated
/// code short and the actual logic testable in one place.
///
/// Every generated declaration mirrors the access level of the class:
/// `public` (or `open`) and `package` classes get `public` and `package`
/// members, every other class gets internal members.
struct PersistableExpander {

    private let classDecl: ClassDeclSyntax
    private let orphanPolicy: String

    private var className: String {
        classDecl.name.text
    }

    private var access: String {
        Self.accessModifier(of: classDecl)
    }

    /// Generates the `init(_:in:)` initializer required by `SwiftDataPersistable`.
    ///
    /// Attributes are copied, to-one relationships are resolved from their
    /// identifiers and to-many relationships are materialized from the
    /// nested drafts (existing models are reused and updated, new ones are
    /// created and inserted).
    private func makeInit(props: [StoredProperty]) -> DeclSyntax {
        let body = props.map { prop in
            let value = "configurable.\(prop.name)"

            switch prop.shape {
            case .attribute:
                return "self.\(prop.name) = \(value)"
            case .toOne(let target, let isOptional):
                let resolver = isOptional ? "resolveRelationship" : "resolveRequiredRelationship"
                return "self.\(prop.name) = try context.\(resolver)(\(value), as: \(target).self)"
            case .toMany(_, let isOptional):
                let current = isOptional ? "nil" : "[]"
                return "self.\(prop.name) = try context.reconcile(\(current), with: \(value), orphans: \(orphanPolicy))"
            }
        }

        return """
        \(raw: access)required init(_ configurable: Configurable, in context: ModelContext) throws {
            \(raw: body.joined(separator: "\n"))
        }
        """
    }

    /// Generates the `update(using:in:)` method required by `SwiftDataPersistable`.
    ///
    /// Every property is written only when its value actually changes, so an
    /// update with an unchanged draft leaves the model clean. To-many
    /// relationships are reconciled: existing elements are updated in place,
    /// elements moved from elsewhere are fetched by identifier, new drafts
    /// become new models, and orphans are handled according to the macro's
    /// `orphans` argument.
    private func makeUpdate(props: [StoredProperty]) -> DeclSyntax {
        let body = props.map { prop in
            let current = "self.\(prop.name)"
            let value = "configurable.\(prop.name)"

            switch prop.shape {
            case .attribute:
                return "if \(current) != \(value) { \(current) = \(value) }"
            case .toOne(let target, let isOptional):
                let resolver = isOptional ? "resolveRelationship" : "resolveRequiredRelationship"
                let currentID = isOptional ? "\(current)?.persistentModelID" : "\(current).persistentModelID"
                return """
                if \(currentID) != \(value) {
                    \(current) = try context.\(resolver)(\(value), as: \(target).self)
                }
                """
            case .toMany(_, let isOptional):
                let reconciled = "\(prop.name)Reconciled"
                let map = isOptional ? "?.map" : ".map"
                return """
                let \(reconciled) = try context.reconcile(\(current), with: \(value), orphans: \(orphanPolicy))
                if \(reconciled)\(map)(\\.persistentModelID) != \(current)\(map)(\\.persistentModelID) {
                    \(current) = \(reconciled)
                }
                """
            }
        }

        return """
        \(raw: access)func update(using configurable: Configurable, in context: ModelContext) throws {
            \(raw: body.joined(separator: "\n"))
        }
        """
    }

    /// Produces every member added to the class, in order: the two type
    /// aliases, the `Transferable` and `Configurable` structs, `init(_:in:)`
    /// and `update(using:in:)`.
    func expand() -> [DeclSyntax] {
        let props = PropertyExtractor(classDecl: classDecl).extract()

        let transferable = DTOBuilder(kind: .transferable, className: className, access: access, properties: props)
        let configurable = DTOBuilder(kind: .configurable, className: className, access: access, properties: props)

        return [
            "\(raw: access)typealias ConfigurableType = Configurable",
            "\(raw: access)typealias TransferableType = Transferable",
            transferable.generate(),
            configurable.generate(),
            makeInit(props: props),
            makeUpdate(props: props)
        ]
    }

    /// Initializes the expander from the macro's attribute and declaration.
    ///
    /// - Returns: `nil` when the declaration is not a class.
    init?(attribute: AttributeSyntax, declaration: some DeclGroupSyntax) {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            return nil
        }
        self.classDecl = classDecl
        self.orphanPolicy = Self.orphanPolicy(from: attribute)
    }

    // MARK: - Attribute and modifier parsing

    /// The expression passed as the `orphans:` argument, `.detach` if omitted.
    ///
    /// The expression is forwarded verbatim to the generated `reconcile`
    /// calls, so the compiler type-checks it against `OrphanPolicy`.
    static func orphanPolicy(from attribute: AttributeSyntax) -> String {
        guard case .argumentList(let arguments) = attribute.arguments,
              let argument = arguments.first(where: { $0.label?.text == "orphans" }) else {
            return ".detach"
        }
        return argument.expression.trimmedDescription
    }

    /// The access modifier (with a trailing space) for the generated members.
    static func accessModifier(of classDecl: ClassDeclSyntax) -> String {
        for modifier in classDecl.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return "public "
            case .keyword(.package):
                return "package "
            default:
                continue
            }
        }
        return ""
    }
}
