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

/// An orchestrator that performs the core macro expansion for `@Model` classes.
///
/// `PersistableExpander` is the central component responsible for analyzing a
/// `@Model` class declaration, extracting its stored properties via SwiftSyntax,
/// and synthesizing the required conformances, methods, and associated types.
/// It does not conform to `DynamicMemberBuilder` itself; instead, it delegates
/// to `TransferableBuilder` and `ConfigurableBuilder` for struct generation,
/// while producing the `init(_:)` and `update(using:)` methods directly.
///
/// The expansion workflow consists of three phases:
/// 1. **AST Parsing**: `extractStoredProperties()` traverses the class member
///    block, collects variable declarations, detects `@Relationship` and
///    `@IgnoredByDTO` attributes, and builds `StoredProperty` instances.
/// 2. **Struct Generation**: The extracted properties are passed to
///    `TransferableBuilder` and `ConfigurableBuilder`, which produce the
///    corresponding `Transferable` and `Configurable` structs.
/// 3. **Method Injection**: `makeInit()` and `makeUpdate()` generate the
///    required `init(_ configurableModel:)` and `update(using:)` methods
///    that are added to the original class declaration.
///
/// The `expand()` method returns an array of `DeclSyntax` elements that
/// collectively replace or augment the original class declaration:
/// - Two type aliases (`ConfigurableType`, `TransferableType`)
/// - The generated `Transferable` struct
/// - The generated `Configurable` struct
/// - The `init(_:)` method
/// - The `update(using:)` method
///
/// - Parameter originalClassDecl: The `ClassDeclSyntax` representing the
///   `@Model` class being processed.
struct PersistableExpander {
    
    private let originalClassDecl: ClassDeclSyntax
    
    /// Extracts all stored properties from the original class declaration.
    ///
    /// Traverses the `memberBlock.members` of the class, filtering for
    /// `VariableDeclSyntax` nodes that have no accessor block (i.e., stored
    /// properties, not computed or lazy properties). For each property, it
    /// detects `@Relationship` and `@IgnoredByDTO` attributes, extracts the
    /// type and default value, and handles implicit `nil` defaults for
    /// optional types.
    ///
    /// Properties are collected in declaration order. Skipped items include
    /// computed properties, lazy properties, and accessors.
    ///
    /// - Returns: An array of `StoredProperty` instances representing the
    ///   class's stored properties.
    private func extractStoredProperties() -> [StoredProperty] {
        
        var properties: [StoredProperty] = []
        
        for member in originalClassDecl.memberBlock.members {
            
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  varDecl.bindings.first?.accessorBlock == nil else { continue }

            let isRelationship = varDecl.attributes.contains { element in
                guard let attr = element.as(AttributeSyntax.self) else { return false }
                
                let attrName = attr.attributeName.trimmedDescription
                return attrName == "Relationship" || attrName == "SwiftData.Relationship"
            }
            
            let isIgnored = varDecl.attributes.contains { element in
                guard let attr = element.as(AttributeSyntax.self) else { return false }
                
                let attrName = attr.attributeName.trimmedDescription
                return attrName == "IgnoredByDTO" || attrName == "Tools4SwiftData.IgnoredByDTO"
            }
            
            for binding in varDecl.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                      let typeAnnotation = binding.typeAnnotation?.type else { continue }
                
                // Usiamo trimmedDescription anche qui per evitare problemi con spazi extra: [ Message ] vs [Message]
                let typeString = typeAnnotation.trimmedDescription
                var defaultValueString = binding.initializer?.value.trimmedDescription
                
                // Gestione del default implicito per gli Opzionali (se manca l'inizializzatore ma c'è il '?')
                if defaultValueString == nil && (typeString.hasSuffix("?") || typeString.hasPrefix("Optional<")) {
                    defaultValueString = "nil"
                }
                
                properties.append(StoredProperty(
                    name: identifier,
                    type: typeString,
                    isRelationship: isRelationship,
                    isIgnored: isIgnored,
                    defaultValue: defaultValueString
                ))
            }
        }
        return properties
    }
    
    /// Generates the `init(_ configurableModel:)` method for the class.
    ///
    /// Iterates through non-ignored properties and assigns each one from the
    /// `configurableModel` parameter:
    /// - Array relationships: each element is mapped through the corresponding
    ///   `Configurable` initializer using `.map { }`
    /// - Scalar properties: assigned directly
    ///
    /// Ignored properties are skipped entirely.
    ///
    /// - Parameter props: The extracted `StoredProperty` instances.
    ///
    /// - Returns: A `DeclSyntax` representing the generated initializer.
    private func makeInit(props: [StoredProperty]) -> DeclSyntax {
        
        let initBody = props.compactMap { prop in
            guard !prop.isIgnored else { return nil }
            
            if prop.isArray, let elementName = prop.elementTypeName {
                return "self.\(prop.name) = configurableModel.\(prop.name).map { \(elementName)($0) }"
            } else {
                return "self.\(prop.name) = configurableModel.\(prop.name)"
            }
        }
        .joined(separator: "\n")
        
        return """
            public required init(_ configurableModel: Configurable) {
                \(raw: initBody)
            }
        """
    }
    
    /// Generates the `update(using:)` method for the class.
    ///
    /// For scalar properties, performs a direct assignment from the configurable.
    /// For array relationships, performs a diff-based update:
    /// 1. Builds a dictionary mapping `PersistentIdentifier` → existing entity
    /// 2. Iterates through the configurable items, updating existing ones in place
    ///    or creating new ones for unknown IDs
    /// 3. Deletes orphaned entities (present in the old array but absent from
    ///    the configurable) using `modelContext.delete(_:)`
    ///
    /// This ensures that relationship arrays stay in sync with the configurable
    /// state, preserving existing entities where possible and cleaning up
    /// deleted references.
    ///
    /// - Parameter props: The extracted `StoredProperty` instances.
    ///
    /// - Returns: A `DeclSyntax` representing the generated update method.
    private func makeUpdate(props: [StoredProperty]) -> DeclSyntax {

        var updaterBody = ""
        for prop in props {
            guard !prop.isIgnored else { continue }
            
            guard prop.isRelationship,
                  let elementType = prop.elementTypeName else {
                updaterBody += "\nself.\(prop.name) = configurable.\(prop.name)\n"
                continue
            }
        
            updaterBody += """
            var existing\(prop.name): [PersistentIdentifier: \(elementType)] = [:]
            for item in self.\(prop.name) {
                existing\(prop.name)[item.persistentModelID] = item
            }
            var updated\(prop.name): [\(elementType)] = []
            for config in configurable.\(prop.name) {
                if let id = config.persistentModelID, 
                   let existing = existing\(prop.name)[persistentModelID] {
                    try existing.update(using: config)
                    updated\(prop.name).append(existing)
                    existing\(prop.name).removeValue(forKey: id)
                } else {
                    let newItem = \(elementType)(config)
                    updated\(prop.name).append(newItem)
                }
            }
            if let context = self.modelContext {
                for orphaned in existing\(prop.name).values {
                    context.delete(orphaned)
                }
            }
            self.\(prop.name) = updated\(prop.name)
            """
        }
        
        return """
            public func update(using configurable: Configurable) throws {
                \(raw: updaterBody)
            }
        """
    }
    
    /// Orchestrates the full macro expansion by combining all generated
    /// declarations into a single array.
    ///
    /// The returned array contains, in order:
    /// 1. `ConfigurableType` type alias
    /// 2. `TransferableType` type alias
    /// 3. `Transferable` struct
    /// 4. `Configurable` struct
    /// 5. `init(_ configurableModel:)` method
    /// 6. `update(using:)` method
    ///
    /// - Returns: An array of `DeclSyntax` elements representing the complete
    ///   expansion for the class.
    func expand() -> [DeclSyntax] {
        let className = originalClassDecl.name.text
        let props = extractStoredProperties()
        
        let transferableStruct = TransferableBuilder(className: className, props: props).generate()
        let configurableStruct = ConfigurableBuilder(className: className, props: props).generate()
        
        let typeAliasConfig: DeclSyntax = "public typealias ConfigurableType = Configurable"
        let typeAliasTransf: DeclSyntax = "public typealias TransferableType = Transferable"

        return [
            typeAliasConfig,
            typeAliasTransf,
            transferableStruct,
            configurableStruct,
            makeInit(props: props),
            makeUpdate(props: props)
        ]
    }
    
    /// Initializes a `PersistableExpander` from a class declaration.
    ///
    /// The failable initializer returns `nil` if the provided declaration
    /// is not a `ClassDeclSyntax`, ensuring that only class declarations
    /// (specifically `@Model` classes) are processed.
    ///
    /// - Parameter declaration: The `DeclGroupSyntax` to analyze.
    init?(originalDeclaration declaration: DeclGroupSyntax) {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            return nil
        }
        self.originalClassDecl = classDecl
    }
}
