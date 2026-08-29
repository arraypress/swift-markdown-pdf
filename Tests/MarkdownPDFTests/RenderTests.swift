//
//  RenderTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  What comes out: pages, text, links, the running parts, the pictures.
//

import PDFKit
import XCTest
@testable import MarkdownPDF

final class RenderTests: XCTestCase {

    func testEverythingRendersInEveryDesign() throws {
        let manuscript = Manuscript(markdown: Fixtures.everything)
        for design in DesignKind.allCases {
            let data = try manuscript.render(design: design)
            let pdf = try XCTUnwrap(PDFDocument(data: data), design.rawValue)
            XCTAssertEqual(pdf.pageCount, 1, design.rawValue)
            let text = try XCTUnwrap(pdf.string)
            for expected in ["First section", "emphasis", "strength", "nested", "answer = 42", "Quoted words", "Centre", "Last words"] {
                XCTAssertTrue(text.contains(expected), "\(design.rawValue) lost \"\(expected)\"")
            }
        }
    }

    func testTheTitleBlockSaysWhoAndWhen() throws {
        let manuscript = Manuscript(markdown: Fixtures.everything)
        for design in [DesignKind.report, .article, .manual] {
            let text = Fixtures.text(of: try manuscript.render(design: design))
            XCTAssertTrue(text.contains("Everything"), design.rawValue)
            XCTAssertTrue(text.contains("Alex Moreau"), design.rawValue)
            XCTAssertTrue(text.contains("30 August 2026"), design.rawValue)
        }
    }

    func testTheMemoHeadListsTheFields() throws {
        let manuscript = Manuscript(markdown: "---\ntitle: Memo\nto: Everyone\nfrom: Me\nre: Lunch\n---\n\nText.")
        let text = Fixtures.text(of: try manuscript.render(design: .memo))
        for expected in ["TO", "Everyone", "FROM", "Me", "RE", "Lunch"] {
            XCTAssertTrue(text.contains(expected), "the memo head lost \(expected)")
        }
    }

    func testLinksAreAnnotations() throws {
        let manuscript = Manuscript(markdown: "See [the docs](https://example.com/docs) and [more](https://example.com/more) here.")
        let pdf = try XCTUnwrap(PDFDocument(data: try manuscript.render(design: .plain)))
        let links = try XCTUnwrap(pdf.page(at: 0)).annotations.compactMap { $0.url?.absoluteString }
        XCTAssertEqual(Set(links), ["https://example.com/docs", "https://example.com/more"])
        XCTAssertEqual(links.count, 2, "one rectangle per link, however many words it spans")
    }

    func testALongDocumentRunsToPagesWithNumbers() throws {
        let manuscript = Manuscript(markdown: Fixtures.long(paragraphs: 14))
        let pdf = try XCTUnwrap(PDFDocument(data: try manuscript.render(design: .report)))
        XCTAssertGreaterThan(pdf.pageCount, 2)
        let last = try XCTUnwrap(pdf.page(at: pdf.pageCount - 1)?.string)
        XCTAssertTrue(last.contains("Page \(pdf.pageCount) of \(pdf.pageCount)"), last)
        XCTAssertTrue(last.contains("A long one"), "the running header carries the title")
        let first = try XCTUnwrap(pdf.page(at: 0)?.string)
        XCTAssertFalse(first.contains("Page 1 of") && first.hasPrefix("A long one\nA long one"), "no running title over the title block")
    }

    func testNumberedHeadingsStartAtOne() throws {
        let manuscript = Manuscript(markdown: "# Title\n\n## One\n\ntext\n\n### One point one\n\ntext\n\n## Two\n\ntext")
        let text = Fixtures.text(of: try manuscript.render(design: .manual))
        XCTAssertNotNil(text.range(of: #"(^|\n)1\s+One"#, options: .regularExpression), text)
        XCTAssertNotNil(text.range(of: #"1\.1\s+One point one"#, options: .regularExpression), text)
        XCTAssertNotNil(text.range(of: #"(^|\n)2\s+Two"#, options: .regularExpression), text)
    }

    func testAHeadingIsKeptWithWhatFollows() throws {
        // Enough prose to land a heading near the foot of the page, many
        // times over; a heading must never be the last line on a page.
        let manuscript = Manuscript(markdown: Fixtures.long(paragraphs: 30))
        let pdf = try XCTUnwrap(PDFDocument(data: try manuscript.render(design: .plain)))
        for index in 0..<pdf.pageCount {
            let lines = try XCTUnwrap(pdf.page(at: index)?.string).split(separator: "\n").map(String.init)
            let content = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && Int($0.trimmingCharacters(in: .whitespaces)) == nil }
            if let last = content.last {
                XCTAssertFalse(last.hasPrefix("Section "), "page \(index + 1) ends with a heading: \(last)")
            }
        }
    }

    func testAPictureIsDrawnAndAMissingOneIsSaidSo() throws {
        let folder = try Fixtures.temporaryFolder()
        _ = try Fixtures.png(in: folder)
        let file = folder.appendingPathComponent("doc.md")
        try Data("# Pictures\n\n![A blue box](figure.png)\n\n![Gone](nope.png)".utf8).write(to: file)

        let data = try Manuscript(contentsOf: file).render(design: .report)
        XCTAssertTrue(data.contains(Data("/Image".utf8)) || data.contains(Data("/XObject".utf8)), "no image object in the PDF")
        let text = Fixtures.text(of: data)
        XCTAssertTrue(text.contains("A blue box"), "the caption")
        XCTAssertTrue(text.contains("missing image: nope.png"), text)
    }

    func testTheThemeChangesThePageAndTheFace() throws {
        let manuscript = Manuscript(markdown: Fixtures.everything)
        let letter = try XCTUnwrap(PDFDocument(data: try manuscript.render(design: .plain, theme: .american)))
        XCTAssertEqual(Int(try XCTUnwrap(letter.page(at: 0)).bounds(for: .mediaBox).width), 612)

        let serif = try manuscript.render(design: .plain, theme: .classic)
        XCTAssertTrue(serif.contains(Data("SourceSerif".utf8)), "the classic theme sets the serif")
        let sans = try manuscript.render(design: .plain, theme: .plain)
        XCTAssertTrue(sans.contains(Data("Inter".utf8)))
    }

    func testMetadataNamesTheDocument() throws {
        let data = try Manuscript(markdown: Fixtures.everything).render(design: .report)
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        let attributes = try XCTUnwrap(pdf.documentAttributes)
        XCTAssertEqual(attributes[PDFDocumentAttribute.titleAttribute] as? String, "Everything")
        XCTAssertEqual(attributes[PDFDocumentAttribute.authorAttribute] as? String, "Alex Moreau")
    }

    func testTheOutlineHasTheHeadings() throws {
        let data = try Manuscript(markdown: "# T\n\n## A\n\ntext\n\n## B\n\ntext\n\n### C\n\ntext").render(design: .report)
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        let outline = try XCTUnwrap(pdf.outlineRoot, "no bookmarks")
        let labels = (0..<outline.numberOfChildren).compactMap { outline.child(at: $0)?.label }
        XCTAssertEqual(labels, ["A", "B"], "levels one and two are bookmarked; the title is not a section")
    }

    func testSaveWritesTheFile() throws {
        let folder = try Fixtures.temporaryFolder()
        let url = folder.appendingPathComponent("out.pdf")
        let size = try Manuscript(markdown: "# Hi\n\nthere").save(to: url, design: .plain)
        XCTAssertEqual(try Data(contentsOf: url).count, size)
    }
}
