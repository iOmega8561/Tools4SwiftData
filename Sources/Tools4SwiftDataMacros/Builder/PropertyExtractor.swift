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
//  PropertyExtractor.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import SwiftSyntax

/// Collects the stored properties of a `@Model` class that take part in the
/// data transfer pipeline.
///
/// A property is collected when it is a stored instance property (computed
/// properties and `static`/`class` properties are skipped; properties with
/// only `willSet`/`didSet` observers are still stored) and it is not marked
/// with `@IgnoredByDTO` or SwiftData's `@Transient`.
///
/// Relationships are recognized by an explicit `@Relationship` attribute only:
/// a macro sees syntax, not types, so it cannot tell whether `Message` is a
/// `@Model` class or a plain struct.
struct PropertyExtractor {

    static let relationshipAttributes: Set<String> = [
        "Relationship", "SwiftData.Relationship"
    ]

    static let excludingAttributes: Set<String> = [
        "IgnoredByDTO", "Tools4SwiftData.IgnoredByDTO",
        "Transient", "SwiftData.Transient"
    ]

    private let classDecl: ClassDeclSyntax

    init(classDecl: ClassDeclSyntax) {
        self.classDecl = classDecl
    }

    /// Extracts the participating stored properties, in declaration order.
    func extract() -> [StoredProperty] {
        var properties: [StoredProperty] = []

        for member in classDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  !Self.isTypeProperty(varDecl),
                  !Self.hasAttribute(in: varDecl, named: Self.excludingAttributes) else { continue }

            let isRelationship = Self.hasAttribute(in: varDecl, named: Self.relationshipAttributes)
            let bindings = Array(varDecl.bindings)

            for (index, binding) in bindings.enumerated() {
                guard Self.isStored(binding),
                      let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                      let type = Self.declaredType(of: index, in: bindings) else { continue }

                properties.append(makeProperty(
                    name: name,
                    type: type,
                    initializer: binding.initializer?.value,
                    isRelationship: isRelationship
                ))
            }
        }
        return properties
    }

    private func makeProperty(
        name: String,
        type: TypeSyntax,
        initializer: ExprSyntax?,
        isRelationship: Bool
    ) -> StoredProperty {
        let isOptional = TypeInspector.isOptional(type)
        let shape: PropertyShape = isRelationship
            ? TypeInspector.relationshipShape(of: type) ?? .attribute
            : .attribute

        return StoredProperty(
            name: name,
            type: type.trimmedDescription,
            isOptional: isOptional,
            shape: shape,
            defaultValue: initializer?.trimmedDescription ?? (isOptional ? "nil" : nil)
        )
    }

    // MARK: - Syntax helpers

    /// Whether any of the declaration's attributes has one of the given names.
    static func hasAttribute(in varDecl: VariableDeclSyntax, named names: Set<String>) -> Bool {
        varDecl.attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else { return false }
            return names.contains(attribute.attributeName.trimmedDescription)
        }
    }

    /// Whether the declaration is a `static` or `class` property.
    static func isTypeProperty(_ varDecl: VariableDeclSyntax) -> Bool {
        varDecl.modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
        }
    }

    /// Whether a binding declares storage: no accessor block, or an accessor
    /// block made only of `willSet`/`didSet` observers.
    static func isStored(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessorBlock = binding.accessorBlock else { return true }

        switch accessorBlock.accessors {
        case .getter:
            return false
        case .accessors(let accessors):
            return accessors.allSatisfy { accessor in
                accessor.accessorSpecifier.tokenKind == .keyword(.willSet)
                    || accessor.accessorSpecifier.tokenKind == .keyword(.didSet)
            }
        }
    }

    /// The type annotation that applies to the binding at `index`.
    ///
    /// In `var a, b: Int` only `b` carries the annotation, but it applies to
    /// `a` as well. A binding with an initializer and no annotation has an
    /// inferred type and returns `nil`.
    static func declaredType(of index: Int, in bindings: [PatternBindingSyntax]) -> TypeSyntax? {
        if let type = bindings[index].typeAnnotation?.type {
            return type
        }
        guard bindings[index].initializer == nil else { return nil }

        for binding in bindings[(index + 1)...] {
            if let type = binding.typeAnnotation?.type {
                return type
            }
            if binding.initializer != nil {
                return nil
            }
        }
        return nil
    }
}
