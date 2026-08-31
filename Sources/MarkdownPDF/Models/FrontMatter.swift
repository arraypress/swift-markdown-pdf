//
//  FrontMatter.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The block between the `---` fences at the top of a file.
//
//  Enough YAML to carry a title, an author and a date — `key: value` lines,
//  quoted or not — and no more. A document's front matter is a handful of
//  fields, and a full YAML parser is a dependency that would spend most of
//  its weight on things nobody writes above a report.
//

import Foundation

/// What the file says about itself, above the first heading.
public struct FrontMatter: Equatable, Sendable {

    /// Every field, in the order written. The known ones are also named
    /// below; a design may read others — a memo's `to` and `from`, say.
    public var fields: [(key: String, value: String)]

    public init(fields: [(key: String, value: String)] = []) {
        self.fields = fields
    }

    public subscript(key: String) -> String? {
        fields.first { $0.key.lowercased() == key.lowercased() }?.value
    }

    public var title: String { self["title"] ?? "" }
    public var subtitle: String { self["subtitle"] ?? "" }
    public var author: String { self["author"] ?? "" }
    public var date: String { self["date"] ?? "" }

    /// The design the file asks for, for a tool that honours it.
    public var design: String? { self["design"] }

    /// The theme the file asks for — a preset's name, or a path.
    public var theme: String? { self["theme"] }

    public var isEmpty: Bool { fields.isEmpty }

    public static func == (lhs: FrontMatter, rhs: FrontMatter) -> Bool {
        lhs.fields.map { "\($0.key)=\($0.value)" } == rhs.fields.map { "\($0.key)=\($0.value)" }
    }
}
