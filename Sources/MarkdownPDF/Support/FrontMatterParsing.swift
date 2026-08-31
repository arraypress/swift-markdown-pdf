//
//  FrontMatterParsing.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The front-matter fences and values, parsed. Pure functions of the
//  source text, so the unquoting and fence rules are pinned by tests
//  that never build a document.
//

import Foundation

/// Splits and reads the block between the `---` fences.
enum FrontMatterParsing {

    /// Splits the front matter off the top of a file.
    ///
    /// The fences must be the first line and a later line of exactly `---`;
    /// a `---` in the body is a thematic break, not a fence. Anything that
    /// is not `key: value` between them is ignored rather than refused: a
    /// stray line in the front matter should not cost the document.
    static func split(_ source: String) -> (matter: FrontMatter, body: String) {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let close = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
        else { return (FrontMatter(), source) }

        var fields: [(key: String, value: String)] = []
        for line in lines[1..<close] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !key.hasPrefix("#") else { continue }
            fields.append((key, unquote(String(line[line.index(after: colon)...]))))
        }

        let body = lines[(close + 1)...].joined(separator: "\n")
        return (FrontMatter(fields: fields), body)
    }

    /// A value with its quotes off, and a `[a, b]` list as `a, b`.
    static func unquote(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)
        if value.count >= 2,
           let first = value.first, let last = value.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            value = String(value.dropFirst().dropLast())
        } else if value.hasPrefix("["), value.hasSuffix("]") {
            value = value.dropFirst().dropLast()
                .split(separator: ",")
                .map { unquote(String($0)) }
                .joined(separator: ", ")
        }
        return value
    }
}
