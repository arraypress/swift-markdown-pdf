//
//  Schema.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The shapes this library reads, written down as JSON Schema.
//
//  A design and a theme are JSON, and an editor or an agent that has the
//  schema stops guessing the keys. The files are in the package's
//  resources, kept honest by a test that validates every bundled design
//  and theme against them.
//

import Foundation

/// One of the shapes, as JSON Schema (draft 2020-12).
public enum Schema: String, CaseIterable, Sendable {

    /// A design written as data.
    case blueprint

    /// A theme.
    case theme

    /// The schema, as the bytes of its file.
    public var data: Data {
        guard let url = Bundle.module.url(forResource: "\(rawValue).schema", withExtension: "json", subdirectory: "Schemas"),
              let data = try? Data(contentsOf: url)
        else {
            preconditionFailure("The schema \(rawValue).schema.json is not in the package")
        }
        return data
    }

    /// The schema as text.
    public var json: String { String(decoding: data, as: UTF8.self) }

    /// The file's name, for a tool writing it out.
    public var filename: String { "\(rawValue).schema.json" }
}
