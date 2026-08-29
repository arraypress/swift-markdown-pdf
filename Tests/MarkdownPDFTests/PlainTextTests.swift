//
//  PlainTextTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//

import XCTest
@testable import MarkdownPDF

final class PlainTextTests: XCTestCase {

    func testTheStructureIsKeptWithoutTheMarks() {
        let text = Manuscript(markdown: Fixtures.everything).plainText()
        XCTAssertTrue(text.hasPrefix("EVERYTHING\n\nOne of each\nAlex Moreau\n30 August 2026\n\nFIRST SECTION\n"), text)
        XCTAssertTrue(text.contains("A paragraph with emphasis, strength, code, a link and a strike."), text)
        XCTAssertTrue(text.contains("- one\n- two\n  - nested\n[x] done\n[ ] not yet"), text)
        XCTAssertTrue(text.contains("1. first\n2. second"), text)
        XCTAssertTrue(text.contains("    let answer = 42"), "code is indented: \(text)")
        XCTAssertTrue(text.contains("> Quoted words."), text)
        XCTAssertTrue(text.contains("Left  Centre  Right\na     b       c"), "a table is columns: \(text)")
        XCTAssertTrue(text.contains("\n---\n"), text)
        XCTAssertTrue(text.contains("Deeper\n\nLast words."), "a level-three heading keeps its case: \(text)")
        XCTAssertFalse(text.contains("*") || text.contains("`") || text.contains("|"), "a mark leaked: \(text)")
    }

    func testNothingIsWrapped() {
        let long = "word " + String(repeating: "and more ", count: 60)
        let text = Manuscript(markdown: "# T\n\n" + long).plainText()
        XCTAssertTrue(text.contains(long.trimmingCharacters(in: .whitespaces)), "a form reflows its own text")
    }
}
