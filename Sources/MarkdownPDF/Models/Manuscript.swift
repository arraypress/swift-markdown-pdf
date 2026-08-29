//
//  Manuscript.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  A Markdown file, read: its front matter and its blocks.
//
//  Agents write Markdown all day, and the route from that to a document
//  somebody would hand over runs through a LaTeX install or a headless
//  browser. This is the other route: parse once, then set the same blocks as
//  a PDF in a chosen design, as a Word document, or as text.
//

import Foundation

/// A Markdown document, parsed and ready to set.
public struct Manuscript: Equatable, Sendable {

    /// What the file said about itself.
    public var frontMatter: FrontMatter

    /// The document, top to bottom.
    public var blocks: [Block]

    /// Where the file was, so a relative image path resolves. Nil for
    /// text that came from nowhere in particular.
    public var base: URL?

    public init(frontMatter: FrontMatter = FrontMatter(), blocks: [Block], base: URL? = nil) {
        self.frontMatter = frontMatter
        self.blocks = blocks
        self.base = base
    }

    // MARK: Reading

    /// Parses Markdown — CommonMark with the GFM extensions: tables,
    /// strikethrough and task lists.
    public init(markdown source: String, base: URL? = nil) {
        let (matter, body) = FrontMatter.split(source)
        self.init(frontMatter: matter, blocks: Parser.blocks(of: body), base: base)
    }

    /// Reads and parses a file.
    public init(contentsOf url: URL) throws {
        let source = try String(contentsOf: url, encoding: .utf8)
        self.init(markdown: source, base: url.deletingLastPathComponent())
    }

    // MARK: What it is called

    /// The title: the front matter's, else the leading `#` heading.
    public var title: String {
        if !frontMatter.title.isEmpty { return frontMatter.title }
        if case .heading(1, let inlines)? = blocks.first { return inlines.plain }
        return ""
    }

    /// Whether the body opens with a `#` heading that says the title — a
    /// design that draws the title drops that heading rather than set the
    /// same words twice. Either the heading *is* the title, or the front
    /// matter named the same one.
    var titleIsLeadingHeading: Bool {
        guard case .heading(1, let inlines)? = blocks.first else { return false }
        return frontMatter.title.isEmpty
            || inlines.plain.trimmingCharacters(in: .whitespaces).lowercased() == frontMatter.title.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// The blocks under the title, whichever way the title was given.
    public var body: [Block] {
        titleIsLeadingHeading ? Array(blocks.dropFirst()) : blocks
    }

    /// Every heading, in order — the table of contents.
    public var headings: [(level: Int, text: String)] {
        blocks.compactMap {
            if case .heading(let level, let inlines) = $0 { return (level, inlines.plain) }
            return nil
        }
    }

    /// The words on the page, roughly — for a summary line.
    public var wordCount: Int {
        blocks.map(\.plain).joined(separator: " ")
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    /// Everything referenced as a picture, block or inline.
    public var imageSources: [String] {
        var found: [String] = []
        func walk(_ inlines: Inlines) {
            for inline in inlines {
                switch inline {
                case .image(let source, _): found.append(source)
                case .emphasis(let inner), .strong(let inner), .strikethrough(let inner), .link(let inner, _): walk(inner)
                default: break
                }
            }
        }
        func walk(_ blocks: [Block]) {
            for block in blocks {
                switch block {
                case .image(let source, _): found.append(source)
                case .heading(_, let inlines), .paragraph(let inlines): walk(inlines)
                case .list(let list): list.items.forEach { walk($0.blocks) }
                case .quote(let inner): walk(inner)
                case .table(let table): (table.header + table.rows.flatMap { $0 }).forEach(walk)
                default: break
                }
            }
        }
        walk(blocks)
        return found
    }

    /// A path from the document, resolved against where the document was.
    public func resolve(_ path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") { return URL(fileURLWithPath: expanded) }
        if let base { return base.appendingPathComponent(expanded) }
        return URL(fileURLWithPath: expanded)
    }
}
