//
//  Schema.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The shapes this library reads, written down as JSON Schema.
//
//  A design and a theme are JSON, and an editor or an agent that has the
//  schema stops guessing the keys. The design's is compiled in
//  (`Support/SchemaText.swift`); the theme's is DocumentTheme's, shared with
//  the résumé library. Kept honest by a test that validates every bundled
//  design and theme against them.
//

import DocumentTheme
import Foundation

/// One of the shapes, as JSON Schema (draft 2020-12).
public enum Schema: String, CaseIterable, Sendable {

    /// A design written as data.
    case blueprint

    /// A theme.
    case theme

    /// The schema, as the bytes of its file.
    public var data: Data { Data(json.utf8) }

    /// The schema as text.
    public var json: String {
        switch self {
        case .blueprint: return SchemaText.blueprint
        case .theme: return ThemeSchema.json
        }
    }

    /// The file's name, for a tool writing it out.
    public var filename: String { "\(rawValue).schema.json" }
}
