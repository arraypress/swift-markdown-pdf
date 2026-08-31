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
}
