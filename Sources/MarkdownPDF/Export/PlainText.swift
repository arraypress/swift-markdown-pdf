//
//  PlainText.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The document as text, for the box that takes nothing else.
//
//  Not the Markdown source: the source has fences, pipes and asterisks in
//  it, and a form that reflows text shows every one of them. This is what
//  the page says, in reading order, with the structure kept as a reader
//  would keep it — headings on their own line, a dash before each item,
//  a table as columns.
//

import Foundation

extension Manuscript {

    /// The document as plain text.
    public func plainText() -> String {
        var out: [String] = []
        if !title.isBlank { out.append(title.uppercased()); out.append("") }
        let who = [frontMatter.subtitle, frontMatter.author, frontMatter.date].filter { !$0.isBlank }
        if !who.isEmpty { out += who; out.append("") }
        out += PlainWriter.lines(body, indent: "")
        return out.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }
}

private enum PlainWriter {

    static func lines(_ blocks: [Block], indent: String) -> [String] {
        var out: [String] = []
        for block in blocks {
            switch block {
            case .heading(let level, let inlines):
                out.append(indent + (level <= 2 ? inlines.plain.uppercased() : inlines.plain))
                out.append("")
            case .paragraph(let inlines):
                out.append(indent + inlines.plain.replacingOccurrences(of: "\n", with: "\n" + indent))
                out.append("")
            case .list(let list):
                for (index, item) in list.items.enumerated() {
                    let mark: String
                    if let checked = item.checked { mark = checked ? "[x] " : "[ ] " }
                    else if list.ordered { mark = "\(list.start + index). " }
                    else { mark = "- " }
                    var first = true
                    for inner in item.blocks {
                        if case .paragraph(let inlines) = inner, first {
                            out.append(indent + mark + inlines.plain)
                        } else {
                            out += lines([inner], indent: indent + "  ").filter { !$0.isEmpty }
                        }
                        first = false
                    }
                }
                out.append("")
            case .code(_, let code):
                out += code.components(separatedBy: "\n").map { indent + "    " + $0 }
                out.append("")
            case .quote(let inner):
                out += lines(inner, indent: indent + "> ")
            case .table(let table):
                out += columns(table, indent: indent)
                out.append("")
            case .rule:
                out.append(indent + "---")
                out.append("")
            case .image(_, let alt):
                out.append(indent + "[" + (alt.isBlank ? "image" : alt) + "]")
                out.append("")
            case .html:
                break
            }
        }
        return out
    }

    /// A table as aligned columns, two spaces between them.
    private static func columns(_ table: Table, indent: String) -> [String] {
        let rows = ([table.header] + table.rows).map { $0.map(\.plain) }
        let count = rows.map(\.count).max() ?? 0
        var widths = [Int](repeating: 0, count: count)
        for row in rows { for (index, cell) in row.enumerated() { widths[index] = max(widths[index], cell.count) } }
        return rows.map { row in
            indent + (0..<count).map { index in
                let cell = index < row.count ? row[index] : ""
                return cell.padding(toLength: widths[index], withPad: " ", startingAt: 0)
            }.joined(separator: "  ").trimmingCharacters(in: .whitespaces)
        }
    }
}
