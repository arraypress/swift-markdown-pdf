//
//  DocxTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The Word document, proved with the tools this machine has: the zip
//  is sound, the XML says what it should, and Cocoa's importer reads the
//  words back in order.
//

import AppKit
import XCTest
@testable import MarkdownPDF

final class DocxTests: XCTestCase {

    private func members(_ data: Data) -> [String: Data] { TextDocxMembers.members(of: data) }

    func testItIsAZipWithTheDocumentInside() throws {
        let data = Manuscript(markdown: Fixtures.everything).docx()
        XCTAssertEqual(data.prefix(2), Data("PK".utf8))
        let parts = members(data)
        XCTAssertNotNil(parts["word/document.xml"])
        XCTAssertNotNil(parts["[Content_Types].xml"])
    }

    func testTheWordsComeBackInOrder() throws {
        let data = Manuscript(markdown: Fixtures.everything).docx()
        let attributed = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
        let text = attributed.string
        for expected in ["Everything", "First section", "emphasis", "nested", "answer = 42", "Quoted words", "Last words"] {
            XCTAssertTrue(text.contains(expected), "lost \"\(expected)\"")
        }
        let first = try XCTUnwrap(text.range(of: "First section")).lowerBound
        let last = try XCTUnwrap(text.range(of: "Last words")).lowerBound
        XCTAssertLessThan(first, last)
    }

    func testEmphasisLinksAndHeadingsAreMarked() throws {
        let xml = String(decoding: try XCTUnwrap(members(Manuscript(markdown: Fixtures.everything).docx())["word/document.xml"]), as: UTF8.self)
        XCTAssertTrue(xml.contains("<w:b/>"), "bold")
        XCTAssertTrue(xml.contains("<w:i/>"), "italic")
        XCTAssertTrue(xml.contains("Heading1") || xml.contains("Heading2"), "headings as styles")
        XCTAssertTrue(xml.contains("hyperlink"), "the link is a hyperlink")
    }

    func testTheFileIsWritten() throws {
        let url = try Fixtures.temporaryFolder().appendingPathComponent("out.docx")
        try Manuscript(markdown: "# Hi\n\nthere").saveDocx(to: url)
        XCTAssertEqual(try Data(contentsOf: url).prefix(2), Data("PK".utf8))
    }
}

/// The docx writer's zip reader, reached through the library's own export
/// so the test does not depend on the writer directly.
private enum TextDocxMembers {
    static func members(of data: Data) -> [String: Data] { Manuscript.docxMembers(of: data) }
}
