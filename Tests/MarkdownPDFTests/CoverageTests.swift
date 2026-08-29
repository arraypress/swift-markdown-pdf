//
//  CoverageTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The CommonMark a writer reaches for without thinking of it as a
//  feature: the older spellings, the escapes, the references. Each one is
//  parsed the way the spec says and comes out on the page.
//

import XCTest
@testable import MarkdownPDF

final class CoverageTests: XCTestCase {

    private func blocks(_ markdown: String) -> [Block] { Manuscript(markdown: markdown).blocks }
    private func text(_ markdown: String, design: DesignKind = .plain) throws -> String {
        Fixtures.text(of: try Manuscript(markdown: markdown).render(design: design))
    }

    func testSetextHeadings() {
        XCTAssertEqual(blocks("Title\n=====\n\nSub\n---"), [
            .heading(level: 1, [.text("Title")]), .heading(level: 2, [.text("Sub")]),
        ])
    }

    func testClosingHashesAreNotPartOfAHeading() {
        XCTAssertEqual(blocks("## Two ##"), [.heading(level: 2, [.text("Two")])])
    }

    func testReferenceStyleLinksAndImages() {
        let parsed = blocks("See [the spec][cm] and ![pic][p].\n\n[cm]: https://commonmark.org \"CommonMark\"\n[p]: chart.png")
        guard case .paragraph(let inlines)? = parsed.first else { return XCTFail("not a paragraph") }
        XCTAssertEqual(inlines[1], .link([.text("the spec")], url: "https://commonmark.org"))
        XCTAssertEqual(inlines[3], .image(source: "chart.png", alt: "pic"))
        XCTAssertEqual(parsed.count, 1, "the definitions are not content")
    }

    func testAutolinks() {
        let parsed = blocks("Angle <https://example.com/a> and bare https://example.com/b end")
        guard case .paragraph(let inlines)? = parsed.first else { return XCTFail("not a paragraph") }
        XCTAssertTrue(inlines.contains(.link([.text("https://example.com/a")], url: "https://example.com/a")))
        XCTAssertTrue(inlines.contains(.link([.text("https://example.com/b")], url: "https://example.com/b")),
                      "GFM autolinks a bare URL: \(inlines)")
        XCTAssertEqual(Parser.autolinked("see https://a.b/c. Then (https://d.e/f) and https://g.h/(i)!"), [
            .text("see "), .link([.text("https://a.b/c")], url: "https://a.b/c"), .text(". Then ("),
            .link([.text("https://d.e/f")], url: "https://d.e/f"), .text(") and "),
            .link([.text("https://g.h/(i)")], url: "https://g.h/(i)"), .text("!"),
        ])
    }

    func testEntitiesAndEscapes() throws {
        let parsed = blocks("Tom &amp; Jerry &copy; \\*not emphasis\\* 3 &lt; 4")
        guard case .paragraph(let inlines)? = parsed.first else { return XCTFail("not a paragraph") }
        XCTAssertEqual(inlines.plain, "Tom & Jerry © *not emphasis* 3 < 4")
        XCTAssertTrue(try text("Tom &amp; Jerry \\*plain\\*").contains("Tom & Jerry *plain*"))
    }

    func testIndentedCodeAndCodeInsideAListItem() {
        let parsed = blocks("- item\n\n      indented code\n\n- next\n\nprose\n\n    top-level indented")
        guard case .list(let list)? = parsed.first else { return XCTFail("not a list") }
        XCTAssertEqual(list.items[0].blocks, [.paragraph([.text("item")]), .code(language: nil, "indented code")])
        XCTAssertEqual(parsed.last, .code(language: nil, "top-level indented"))
    }

    func testNestedQuotesAndAQuotedHeading() {
        let parsed = blocks("> # Quoted heading\n>\n> > deeper\n")
        guard case .quote(let inner)? = parsed.first else { return XCTFail("not a quote") }
        XCTAssertEqual(inner.first, .heading(level: 1, [.text("Quoted heading")]))
        guard case .quote? = inner.last else { return XCTFail("the nested quote flattened") }
    }

    func testLooseAndTightListsBothCarryTheirParagraphs() {
        let loose = blocks("- one\n\n- two\n")
        guard case .list(let list)? = loose.first else { return XCTFail("not a list") }
        XCTAssertEqual(list.items.map { $0.blocks.count }, [1, 1])
    }

    func testAnInlineImageInsideALinkAndATableCell() {
        let parsed = blocks("| a |\n|---|\n| [![badge](b.png)](https://x.y) and `code` |")
        guard case .table(let table)? = parsed.first else { return XCTFail("not a table") }
        XCTAssertEqual(table.rows[0][0].plain, "badge and code")
        XCTAssertEqual(Manuscript(markdown: "| a |\n|---|\n| [![badge](b.png)](https://x.y) |").imageSources, ["b.png"])
    }

    func testEscapedPipesStayInsideACell() {
        let parsed = blocks("| a | b |\n|---|---|\n| x \\| y | z |")
        guard case .table(let table)? = parsed.first else { return XCTFail("not a table") }
        XCTAssertEqual(table.rows[0].map(\.plain), ["x | y", "z"])
    }

    func testHardWrappedParagraphsAreOneParagraph() throws {
        let parsed = blocks("one line\ntwo line\nthree line")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertTrue(try text("one line\ntwo line").contains("one line two line"))
    }

    func testWhatIsNotMarkdownIsSetAsWritten() throws {
        // Footnotes, math and heading ids are other tools' extensions; the
        // words are kept, the syntax with them, and nothing is dropped.
        let out = try text("A claim[^1] with $x^2$ and {#id}.\n\n[^1]: the note")
        XCTAssertTrue(out.contains("[^1]"), out)
        XCTAssertTrue(out.contains("$x^2$"), out)
    }

    func testEveryHeadingLevelRenders() throws {
        let out = try text("# H1\n\n## H2\n\n### H3\n\n#### H4\n\n##### H5\n\n###### H6\n\nend")
        for level in 1...6 { XCTAssertTrue(out.contains("H\(level)"), "level \(level)") }
    }
}
