//
//  Docx.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The document as a Word file.
//
//  One layout, not five: a .docx goes where a form or a colleague demands
//  one, and it carries the words with their emphasis, links and headings —
//  the things Word can be trusted with. What a design does with the page is
//  a property of the PDF.
//

import Foundation
import TextDocx

extension Manuscript {

    /// The finished `.docx`.
    public func docx(theme: Theme = .plain) -> Data {
        docxDocument(theme: theme).data()
    }

    public func saveDocx(to url: URL, theme: Theme = .plain) throws {
        try docx(theme: theme).write(to: url, options: .atomic)
    }

    /// The members of a `.docx` — for a test, or a caller looking inside.
    public static func docxMembers(of data: Data) -> [String: Data] {
        Docx.members(of: data)
    }

    /// The document before it is written, for a caller who wants to add
    /// to it.
    public func docxDocument(theme: Theme = .plain) -> Docx {
        var doc = Docx(
            page: Docx.Page(size: theme.pageSize == .letter ? .letter : .a4,
                            margins: Docx.Page.Margins(all: 60 * theme.density.margin)),
            typography: Docx.Typography(body: theme.typeface == .sourceSerif ? "Georgia" : "Calibri", size: 11),
            accent: theme.isMonochrome ? nil : theme.accent,
            title: title,
            author: frontMatter.author
        )
        if !title.isBlank { doc.title(title) }
        if !frontMatter.subtitle.isBlank { doc.subtitle(frontMatter.subtitle) }
        let who = [frontMatter.author, frontMatter.date].filter { !$0.isBlank }.joined(separator: " · ")
        if !who.isBlank { doc.paragraph(Docx.Paragraph([Docx.Run(who, color: "#595959")], spaceAfter: 12)) }

        DocxWriter.write(body, into: &doc, depth: 0)
        return doc
    }
}

private enum DocxWriter {

    static func write(_ blocks: [Block], into doc: inout Docx, depth: Int) {
        for block in blocks {
            switch block {
            case .heading(let level, let inlines):
                doc.heading(inlines.plain, level: min(level, 2))
            case .paragraph(let inlines):
                doc.paragraph(Docx.Paragraph(runs(inlines, prefix: String(repeating: "    ", count: depth))))
            case .list(let list):
                for (index, item) in list.items.enumerated() {
                    let mark: String
                    if let checked = item.checked { mark = checked ? "☑ " : "☐ " }
                    else if list.ordered { mark = "\(list.start + index). " }
                    else { mark = "" }
                    var first = true
                    for inner in item.blocks {
                        if case .paragraph(let inlines) = inner, first {
                            doc.bullets([[Docx.Run(String(repeating: "    ", count: depth) + mark)] + runs(inlines)])
                        } else {
                            write([inner], into: &doc, depth: depth + 1)
                        }
                        first = false
                    }
                }
            case .code(_, let code):
                for line in code.components(separatedBy: "\n") {
                    doc.paragraph(Docx.Paragraph([Docx.Run(line.isEmpty ? " " : line, size: 9.5)], spaceAfter: 0))
                }
                doc.paragraph(Docx.Paragraph([Docx.Run(" ")], spaceAfter: 4))
            case .quote(let inner):
                for block in inner {
                    if case .paragraph(let inlines) = block {
                        doc.paragraph(Docx.Paragraph(runs(inlines).map { run in
                            var italic = run; italic.italic = true; italic.color = run.color ?? "#595959"; return italic
                        }))
                    } else {
                        write([block], into: &doc, depth: depth + 1)
                    }
                }
            case .table(let table):
                // Word's own tables are beyond the writer; rows are set as
                // lines with the cells apart, header bold.
                if !table.header.isEmpty {
                    doc.paragraph(Docx.Paragraph([Docx.Run(table.header.map(\.plain).joined(separator: "    "), bold: true)], spaceAfter: 2))
                }
                for row in table.rows {
                    doc.paragraph(Docx.Paragraph([Docx.Run(row.map(\.plain).joined(separator: "    "))], spaceAfter: 2))
                }
                doc.paragraph(Docx.Paragraph([Docx.Run(" ")], spaceAfter: 4))
            case .rule:
                doc.paragraph(Docx.Paragraph([Docx.Run("—", color: "#8C8C8C")], alignment: .centre))
            case .image(let source, let alt):
                doc.paragraph(Docx.Paragraph([Docx.Run(alt.isBlank ? "[Image: \(source)]" : "[Image: \(alt)]", italic: true, color: "#595959")], alignment: .centre))
            case .html:
                break
            }
        }
    }

    static func runs(_ inlines: Inlines, prefix: String = "", bold: Bool = false, italic: Bool = false, link: String? = nil) -> [Docx.Run] {
        var out: [Docx.Run] = prefix.isEmpty ? [] : [Docx.Run(prefix)]
        for inline in inlines {
            switch inline {
            case .text(let text): out.append(Docx.Run(text, bold: bold, italic: italic, link: link))
            case .emphasis(let inner): out += runs(inner, bold: bold, italic: true, link: link)
            case .strong(let inner): out += runs(inner, bold: true, italic: italic, link: link)
            case .strikethrough(let inner): out += runs(inner, bold: bold, italic: italic, link: link)
            case .link(let inner, let url): out += runs(inner, bold: bold, italic: italic, link: url.isBlank ? link : url)
            case .code(let code): out.append(Docx.Run(code, bold: bold, italic: italic, color: "#8C1D1D", link: link))
            case .image(_, let alt): out.append(Docx.Run(alt, italic: true, link: link))
            case .lineBreak: out.append(Docx.Run("\n"))
            case .softBreak: out.append(Docx.Run(" "))
            }
        }
        return out
    }
}
