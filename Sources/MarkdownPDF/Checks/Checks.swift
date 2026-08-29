//
//  Checks.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Whether the document will come out the way its author thinks.
//
//  Markdown is forgiving on a screen and unforgiving on paper: a picture
//  that is not there is a gap, a heading with nothing under it is a
//  heading of nothing, a twelve-column table is nine columns of ellipsis.
//  None of that is an error to the parser. All of it is visible to the
//  reader, so it is said here, before the file is sent.
//

import Foundation
import TextPDF

/// How much a finding matters.
public enum Severity: String, Sendable, Comparable, CaseIterable, Codable {

    /// Fix before sending: something on the page is wrong.
    case blocker

    /// Worth knowing; the document still reads.
    case warning

    /// Advice.
    case note

    private var rank: Int {
        switch self {
        case .blocker: return 0
        case .warning: return 1
        case .note: return 2
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rank < rhs.rank }
}

/// One thing the check found.
public struct Finding: Equatable, Sendable {
    public let severity: Severity
    public let message: String
    public let detail: String

    public init(_ severity: Severity, _ message: String, _ detail: String) {
        self.severity = severity
        self.message = message
        self.detail = detail
    }
}

/// What the check found, and what the page came to.
public struct Report: Sendable {

    public let findings: [Finding]

    /// How many pages the document ran to.
    public let pages: Int

    public let wordCount: Int

    /// No blockers.
    public var isClean: Bool { !findings.contains { $0.severity == .blocker } }

    public func findings(_ severity: Severity) -> [Finding] {
        findings.filter { $0.severity == severity }
    }
}

extension Manuscript {

    /// Renders the document and reports what a reader would notice.
    public func check(design: Blueprint, theme: Theme = .plain) throws -> Report {
        let pdf = try document(design: design, theme: theme)
        var findings = Checks.structure(self)
        findings += Checks.pictures(self)
        findings += Checks.tables(self, width: pdf.contentWidth(), size: design.table.size)
        findings += Checks.code(self, width: pdf.contentWidth(), size: design.code.size)
        return Report(findings: findings.sorted { $0.severity < $1.severity }, pages: pdf.pageCount(), wordCount: wordCount)
    }

    public func check(design: DesignKind = .report, theme: Theme = .plain) throws -> Report {
        try check(design: design.blueprint, theme: theme)
    }
}

enum Checks {

    // MARK: Structure

    static func structure(_ manuscript: Manuscript) -> [Finding] {
        var findings: [Finding] = []

        if manuscript.title.isBlank {
            findings.append(Finding(.note, "The document has no title.",
                                    "Add `title:` to the front matter or open with a `#` heading — it names the PDF, the running header and the bookmark."))
        }

        let headings = manuscript.headings
        var previous = 0
        for (level, text) in headings {
            if previous > 0, level > previous + 1 {
                findings.append(Finding(.warning, "\"\(text)\" skips from a level \(previous) heading to level \(level).",
                                        "A reader — and a screen reader — takes heading levels as the outline; use #\(String(repeating: "#", count: previous)) for the next level down."))
            }
            previous = level
        }

        for empty in emptyHeadings(manuscript.body) {
            findings.append(Finding(.warning, "\"\(empty)\" is a heading with nothing under it.",
                                    "The next thing after it is another heading of the same or a higher level. Write something under it, or drop it."))
        }

        let html = manuscript.blocks.compactMap { block -> String? in
            if case .html(let raw) = block { return raw.trimmingCharacters(in: .whitespacesAndNewlines) }
            return nil
        }
        for raw in html {
            findings.append(Finding(.warning, "An HTML block is not rendered.",
                                    "Nothing here draws HTML; \"\(raw.prefix(60))\" is left off the page. Write it as Markdown."))
        }

        let emptyLinks = countEmptyLinks(manuscript.blocks)
        if emptyLinks > 0 {
            findings.append(Finding(.warning, "\(emptyLinks) link\(emptyLinks == 1 ? " has" : "s have") no address.",
                                    "`[text]()` sets the words plain. Put the URL in the brackets, or drop them."))
        }
        return findings
    }

    private static func emptyHeadings(_ blocks: [Block]) -> [String] {
        var empty: [String] = []
        for (index, block) in blocks.enumerated() {
            guard case .heading(let level, let inlines) = block else { continue }
            let next = index + 1 < blocks.count ? blocks[index + 1] : nil
            switch next {
            case .heading(let nextLevel, _)? where nextLevel <= level: empty.append(inlines.plain)
            case nil: empty.append(inlines.plain)
            default: break
            }
        }
        return empty
    }

    private static func countEmptyLinks(_ blocks: [Block]) -> Int {
        func count(_ inlines: Inlines) -> Int {
            inlines.reduce(0) { total, inline in
                switch inline {
                case .link(let inner, let url): return total + (url.isBlank ? 1 : 0) + count(inner)
                case .emphasis(let inner), .strong(let inner), .strikethrough(let inner): return total + count(inner)
                default: return total
                }
            }
        }
        return blocks.reduce(0) { total, block in
            switch block {
            case .heading(_, let inlines), .paragraph(let inlines): return total + count(inlines)
            case .list(let list): return total + list.items.reduce(0) { $0 + countEmptyLinks($1.blocks) }
            case .quote(let inner): return total + countEmptyLinks(inner)
            case .table(let table): return total + (table.header + table.rows.flatMap { $0 }).reduce(0) { $0 + count($1) }
            default: return total
            }
        }
    }

    // MARK: Pictures

    static func pictures(_ manuscript: Manuscript) -> [Finding] {
        manuscript.imageSources.compactMap { source in
            let url = manuscript.resolve(source)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return Finding(.blocker, "The image \(source) is not there.",
                               "The page shows a box saying so where the picture should be. Check the path — it resolves from the Markdown file's own folder.")
            }
            do {
                _ = try EmbeddedImage.load(url)
                return nil
            } catch {
                return Finding(.blocker, "The image \(source) cannot be used.",
                               (error as? LocalizedError)?.errorDescription ?? String(describing: error))
            }
        }
    }

    // MARK: Tables and code

    static func tables(_ manuscript: Manuscript, width: Double, size: Double) -> [Finding] {
        var findings: [Finding] = []
        for block in manuscript.blocks {
            guard case .table(let table) = block else { continue }
            let columns = table.columnCount
            // Forty-four points is a five-letter word at nine and a half.
            if Double(columns) * 44 > width {
                findings.append(Finding(.warning, "A table has \(columns) columns, more than the page can set.",
                                        "At \(Int(width)) points wide every column gets under \(Int(width / Double(columns))) — words will wrap letter by letter. Split it, or turn it on its side as a list."))
            }
        }
        return findings
    }

    static func code(_ manuscript: Manuscript, width: Double, size: Double) -> [Finding] {
        // JetBrains Mono is 0.6 em wide, and the block has seven points of
        // padding each side.
        let columns = Int((width - 14) / (size * 0.6))
        var long = 0
        for block in manuscript.blocks {
            guard case .code(_, let code) = block else { continue }
            long += code.components(separatedBy: "\n").filter { $0.count > columns }.count
        }
        guard long > 0 else { return [] }
        return [Finding(.note, "\(long) line\(long == 1 ? "" : "s") of code \(long == 1 ? "is" : "are") longer than the block is wide.",
                        "Anything past \(columns) characters wraps onto the next line, which reads as a line of code that is not there. Break the long lines yourself, where it makes sense.")]
    }
}
