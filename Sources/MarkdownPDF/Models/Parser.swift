//
//  Parser.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  swift-markdown's tree, walked into blocks.
//
//  The tree is CommonMark's, node for node. The blocks are this library's,
//  and the two differ where the tree carries things no output here draws —
//  block directives, HTML — or where the tree's shape is a parser's rather
//  than a typesetter's, such as a paragraph that is nothing but a picture.
//

import Foundation
import Markdown

enum Parser {

    /// The blocks of a Markdown body.
    static func blocks(of source: String) -> [Block] {
        let document = Markdown.Document(parsing: source)
        return blocks(of: document.children)
    }

    private static func blocks(of children: MarkupChildren) -> [Block] {
        children.compactMap { block(of: $0) }
    }

    private static func block(of markup: Markup) -> Block? {
        switch markup {
        case let heading as Heading:
            return .heading(level: heading.level, inlines(of: heading.children))

        case let paragraph as Paragraph:
            let content = inlines(of: paragraph.children)
            // A picture alone on its line is a figure, not a word.
            if content.count == 1, case .image(let source, let alt) = content[0] {
                return .image(source: source, alt: alt)
            }
            return .paragraph(content)

        case let list as UnorderedList:
            return .list(List(ordered: false, items: items(of: list.children)))

        case let list as OrderedList:
            return .list(List(ordered: true, start: Int(list.startIndex), items: items(of: list.children)))

        case let code as CodeBlock:
            let language = code.language?.trimmingCharacters(in: .whitespaces)
            return .code(language: language?.isEmpty == false ? language : nil,
                         code.code.hasSuffix("\n") ? String(code.code.dropLast()) : code.code)

        case let quote as BlockQuote:
            return .quote(blocks(of: quote.children))

        case let table as Markdown.Table:
            return .table(self.table(table))

        case is ThematicBreak:
            return .rule

        case let html as HTMLBlock:
            return .html(html.rawHTML)

        default:
            // Directives and anything newer than this switch: dropped, as
            // the one kind of content there is no honest way to set.
            return nil
        }
    }

    private static func items(of children: MarkupChildren) -> [List.Item] {
        children.compactMap { child in
            guard let item = child as? ListItem else { return nil }
            let checked: Bool?
            switch item.checkbox {
            case .checked?: checked = true
            case .unchecked?: checked = false
            case nil: checked = nil
            }
            return List.Item(blocks: blocks(of: item.children), checked: checked)
        }
    }

    private static func table(_ table: Markdown.Table) -> Table {
        let alignments: [Table.Alignment?] = table.columnAlignments.map {
            switch $0 {
            case .left?: return .left
            case .center?: return .centre
            case .right?: return .right
            case nil: return nil
            }
        }
        let header = Array(table.head.cells.map { inlines(of: $0.children) })
        let rows = Array(table.body.rows.map { row in Array(row.cells.map { inlines(of: $0.children) }) })
        return Table(header: header, rows: rows, alignments: alignments)
    }

    // MARK: Inlines

    /// - Parameter linking: Whether a bare URL in the text becomes a link.
    ///   Off inside a link, where the text is already one.
    private static func inlines(of children: MarkupChildren, linking: Bool = true) -> Inlines {
        children.flatMap { child -> Inlines in
            if let text = child as? Markdown.Text { return linking ? autolinked(text.string) : [.text(text.string)] }
            return inline(of: child).map { [$0] } ?? []
        }
    }

    /// A bare `https://…` in running text is a link, as GFM has it — the
    /// parser is asked for CommonMark, so this is added here.
    static func autolinked(_ text: String) -> Inlines {
        guard text.contains("://") else { return [.text(text)] }
        var out: Inlines = []
        var rest = text[...]
        while let range = rest.range(of: #"https?://[^\s<>"']+"#, options: .regularExpression) {
            if range.lowerBound > rest.startIndex { out.append(.text(String(rest[..<range.lowerBound]))) }
            var url = String(rest[range])
            // Trailing punctuation belongs to the sentence, not the address;
            // a closing bracket only if it has no opening one inside.
            while let last = url.last, ".,;:!?".contains(last) || (last == ")" && !url.contains("(")) {
                url.removeLast()
            }
            out.append(.link([.text(url)], url: url))
            let after = rest.index(range.lowerBound, offsetBy: url.count)
            rest = rest[after...]
        }
        if !rest.isEmpty { out.append(.text(String(rest))) }
        return out
    }

    private static func inline(of markup: Markup) -> Inline? {
        switch markup {
        case is Markdown.Text:
            return nil // handled by `inlines(of:)`, which may split one text into several
        case let emphasis as Emphasis:
            return .emphasis(inlines(of: emphasis.children))
        case let strong as Strong:
            return .strong(inlines(of: strong.children))
        case let code as InlineCode:
            return .code(code.code)
        case let link as Markdown.Link:
            return .link(inlines(of: link.children, linking: false), url: link.destination ?? "")
        case let struck as Strikethrough:
            return .strikethrough(inlines(of: struck.children))
        case let image as Markdown.Image:
            return .image(source: image.source ?? "", alt: inlines(of: image.children).plain)
        case is LineBreak:
            return .lineBreak
        case is SoftBreak:
            return .softBreak
        case let html as InlineHTML:
            // `<br>` is the one tag people write inside a paragraph on
            // purpose; the rest is set as what it says.
            return html.rawHTML.lowercased().hasPrefix("<br") ? .lineBreak : .text(html.rawHTML)
        default:
            return nil
        }
    }
}
