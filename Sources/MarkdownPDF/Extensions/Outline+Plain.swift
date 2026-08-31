//
//  Outline+Plain.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The words without the marks. Every walker here derives one fact —
//  the plain text — from shapes declared in Models/Outline.swift.
//

import Foundation

// MARK: - The words, without the marks

extension Inline {

    /// The text alone, formatting dropped — for a bookmark, a running
    /// header, a plain-text paste.
    public var plain: String {
        switch self {
        case .text(let text): return text
        case .emphasis(let inner), .strong(let inner), .strikethrough(let inner): return inner.plain
        case .link(let inner, _): return inner.plain
        case .code(let code): return code
        case .image(_, let alt): return alt
        case .lineBreak: return "\n"
        case .softBreak: return " "
        }
    }
}

extension Array where Element == Inline {

    /// The text alone, formatting dropped.
    public var plain: String { map(\.plain).joined() }
}

extension Block {

    /// The text alone, for searching and for the plain-text form.
    public var plain: String {
        switch self {
        case .heading(_, let inlines), .paragraph(let inlines): return inlines.plain
        case .list(let list): return list.items.map { $0.blocks.map(\.plain).joined(separator: "\n") }.joined(separator: "\n")
        case .code(_, let code): return code
        case .quote(let blocks): return blocks.map(\.plain).joined(separator: "\n")
        case .table(let table): return (table.header + table.rows.flatMap { $0 }).map(\.plain).joined(separator: " ")
        case .rule: return ""
        case .image(_, let alt): return alt
        case .html(let html): return html
        }
    }
}
