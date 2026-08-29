//
//  Outline.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  A document reduced to the blocks every output shares.
//
//  Markdown is already an outline — headings, paragraphs, lists, code,
//  tables — so the parse produces it once, here, and the PDF, the Word
//  document and the plain text are each a renderer over the same blocks. A
//  construct added to the parser reaches every format at the same time, or
//  none of them, which is the only way three outputs stay the same document.
//

import Foundation

/// A block of the document, top to bottom.
public enum Block: Equatable, Sendable {

    /// A heading, `#` through `######`.
    case heading(level: Int, Inlines)

    case paragraph(Inlines)

    /// A bulleted or numbered list. Items nest, so an item is itself blocks.
    case list(List)

    /// A fenced or indented code block, with the fence's language if it named one.
    case code(language: String?, String)

    /// A block quote: blocks set inside a bar.
    case quote([Block])

    /// A GFM table.
    case table(Table)

    /// A thematic break — `---` between paragraphs.
    case rule

    /// A picture on a line of its own, with its alt text as the caption.
    case image(source: String, alt: String)

    /// Raw HTML, which nothing here renders. Kept so a check can say so.
    case html(String)
}

/// A run of inline content: the words of a paragraph, a heading, a cell.
public typealias Inlines = [Inline]

/// The pieces a line of text is made of.
public indirect enum Inline: Equatable, Sendable {

    case text(String)

    /// `*emphasis*` — set italic.
    case emphasis(Inlines)

    /// `**strong**` — set bold.
    case strong(Inlines)

    /// `` `code` `` — set in the monospaced face.
    case code(String)

    /// `[text](url)` — the text, and where it goes.
    case link(Inlines, url: String)

    /// `~~struck~~`.
    case strikethrough(Inlines)

    /// A picture inline, drawn as its alt text.
    case image(source: String, alt: String)

    /// A hard break — two trailing spaces, or a backslash.
    case lineBreak

    /// A newline inside a paragraph, which renders as a space.
    case softBreak
}

/// A bulleted or numbered list.
public struct List: Equatable, Sendable {

    public var ordered: Bool

    /// Where a numbered list starts counting.
    public var start: Int

    public var items: [Item]

    public init(ordered: Bool, start: Int = 1, items: [Item]) {
        self.ordered = ordered
        self.start = start
        self.items = items
    }

    /// One item: its blocks, and whether it is a task with a box.
    public struct Item: Equatable, Sendable {

        public var blocks: [Block]

        /// `- [x]` or `- [ ]`; nil for an ordinary item.
        public var checked: Bool?

        public init(blocks: [Block], checked: Bool? = nil) {
            self.blocks = blocks
            self.checked = checked
        }
    }
}

/// A GFM table: a header row, body rows, and how each column aligns.
public struct Table: Equatable, Sendable {

    public var header: [Inlines]
    public var rows: [[Inlines]]

    /// Per column; nil where the header said nothing.
    public var alignments: [Alignment?]

    public init(header: [Inlines], rows: [[Inlines]], alignments: [Alignment?]) {
        self.header = header
        self.rows = rows
        self.alignments = alignments
    }

    public enum Alignment: String, Equatable, Sendable {
        case left, centre, right
    }

    public var columnCount: Int { max(header.count, rows.map(\.count).max() ?? 0) }
}

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
