//
//  Manuscript+Derived.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Everything a Manuscript can say about itself once parsed — its title,
//  its headings, its pictures — kept out of the model, which states only
//  what a manuscript is.
//

import Foundation

extension Manuscript {

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
