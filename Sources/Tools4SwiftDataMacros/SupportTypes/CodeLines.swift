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
//  CodeLines.swift
//  Tools4SwiftData
//
//  Created on 19/11/2026.
//

import SwiftSyntax

/// Assembles generated declarations from lines of code.
///
/// Building declarations from lists of lines, each indented explicitly,
/// avoids the pitfalls of interpolating multi-line fragments into string
/// literals (only the first line of a fragment inherits the indentation)
/// and makes optional sections easy to leave out without stray blank lines.
enum CodeLines {

    /// The indentation of one nesting level.
    static let indentation = "    "

    /// Indents every non-empty line by one level. Lines containing newlines
    /// are split first, so multi-line fragments are indented as a whole.
    static func indented(_ lines: [String]) -> [String] {
        lines
            .flatMap { $0.split(separator: "\n", omittingEmptySubsequences: false) }
            .map { $0.isEmpty ? "" : indentation + $0 }
    }

    /// A block: the header line followed by `{`, the indented body, and `}`.
    ///
    /// An empty body produces `header {}` on one line.
    static func block(_ header: String, body: [String]) -> [String] {
        guard !body.isEmpty else { return ["\(header) {}"] }
        return ["\(header) {"] + indented(body) + ["}"]
    }

    /// Joins sections with one blank line between them, skipping empty ones.
    static func sections(_ sections: [[String]]) -> [String] {
        var result: [String] = []
        for section in sections where !section.isEmpty {
            if !result.isEmpty {
                result.append("")
            }
            result += section
        }
        return result
    }

    /// Turns lines into a declaration.
    static func declaration(_ lines: [String]) -> DeclSyntax {
        DeclSyntax(stringLiteral: lines.joined(separator: "\n"))
    }
}
