//
//  ParserTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Every construct the outline carries, parsed from the Markdown that
//  writes it.
//

import XCTest
@testable import MarkdownPDF

final class ParserTests: XCTestCase {

    private func blocks(_ markdown: String) -> [Block] { Manuscript(markdown: markdown).blocks }

    // MARK: Blocks

    func testHeadingsCarryTheirLevel() {
        let parsed = blocks("# One\n\n### Three\n\n###### Six")
        XCTAssertEqual(parsed, [
            .heading(level: 1, [.text("One")]),
            .heading(level: 3, [.text("Three")]),
            .heading(level: 6, [.text("Six")]),
        ])
    }

    func testParagraphsWithEveryInline() {
        let parsed = blocks("Plain *em* **strong** `code` [link](https://x.y) ~~gone~~ ![alt](p.png) end")
        guard case .paragraph(let inlines)? = parsed.first else { return XCTFail("not a paragraph") }
        XCTAssertEqual(inlines, [
            .text("Plain "), .emphasis([.text("em")]), .text(" "), .strong([.text("strong")]), .text(" "),
            .code("code"), .text(" "), .link([.text("link")], url: "https://x.y"), .text(" "),
            .strikethrough([.text("gone")]), .text(" "), .image(source: "p.png", alt: "alt"), .text(" end"),
        ])
    }

    func testNestedEmphasisNests() {
        let parsed = blocks("***both*** and **bold *with italic* inside**")
        guard case .paragraph(let inlines)? = parsed.first else { return XCTFail("not a paragraph") }
        XCTAssertEqual(inlines[0], .emphasis([.strong([.text("both")])]))
        XCTAssertEqual(inlines[2], .strong([.text("bold "), .emphasis([.text("with italic")]), .text(" inside")]))
    }

    func testListsNestAndNumber() {
        let parsed = blocks("""
            3. three
            4. four
               - inner
               - [x] done
               - [ ] not yet
            """)
        guard case .list(let list)? = parsed.first else { return XCTFail("not a list") }
        XCTAssertTrue(list.ordered)
        XCTAssertEqual(list.start, 3)
        XCTAssertEqual(list.items.count, 2)
        guard case .list(let inner)? = list.items[1].blocks.last else { return XCTFail("no nested list") }
        XCTAssertFalse(inner.ordered)
        XCTAssertEqual(inner.items.map(\.checked), [nil, true, false])
    }

    func testCodeBlocksKeepTheirLanguageAndText() {
        let parsed = blocks("```swift\nlet x = 1\n\n  indented\n```\n\n```\nbare\n```")
        XCTAssertEqual(parsed, [
            .code(language: "swift", "let x = 1\n\n  indented"),
            .code(language: nil, "bare"),
        ])
    }

    func testQuotesHoldBlocks() {
        let parsed = blocks("> A line\n>\n> - item\n\nafter")
        XCTAssertEqual(parsed.count, 2)
        guard case .quote(let inner)? = parsed.first else { return XCTFail("not a quote") }
        XCTAssertEqual(inner.count, 2)
        guard case .list? = inner.last else { return XCTFail("the list inside the quote went missing") }
    }

    func testTablesWithAlignments() {
        let parsed = blocks("""
            | Name | Qty | Price |
            |:-----|:---:|------:|
            | A    | 1   | 2.00  |
            | **B** | 10 | 3.50 |
            """)
        guard case .table(let table)? = parsed.first else { return XCTFail("not a table") }
        XCTAssertEqual(table.header.map(\.plain), ["Name", "Qty", "Price"])
        XCTAssertEqual(table.alignments, [.left, .centre, .right])
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[1][0], [.strong([.text("B")])])
        XCTAssertEqual(table.columnCount, 3)
    }

    func testARuleAndAFigure() {
        let parsed = blocks("---\n\n![Caption here](chart.png)")
        XCTAssertEqual(parsed, [.rule, .image(source: "chart.png", alt: "Caption here")])
    }

    func testHTMLIsKeptSoTheCheckCanSayItIsDropped() {
        let parsed = blocks("<div class=\"x\">hi</div>\n\ntext with <br> break")
        guard case .html(let raw)? = parsed.first else { return XCTFail("the HTML block was lost") }
        XCTAssertTrue(raw.contains("div"))
        guard case .paragraph(let inlines)? = parsed.last else { return XCTFail("not a paragraph") }
        XCTAssertTrue(inlines.contains(.lineBreak), "<br> inside a paragraph is a line break")
    }

    func testHardAndSoftBreaks() {
        let parsed = blocks("one  \ntwo\nthree")
        guard case .paragraph(let inlines)? = parsed.first else { return XCTFail("not a paragraph") }
        XCTAssertEqual(inlines, [.text("one"), .lineBreak, .text("two"), .softBreak, .text("three")])
    }

    // MARK: The words alone

    func testPlainDropsTheMarks() {
        let inlines: Inlines = [.text("a "), .strong([.text("b")]), .text(" "), .link([.code("c")], url: "u")]
        XCTAssertEqual(inlines.plain, "a b c")
    }
}
