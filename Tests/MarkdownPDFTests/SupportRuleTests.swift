//
//  SupportRuleTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The extracted rules pinned directly — no Manuscript, no Theme, no
//  document constructed where the rule alone will do.
//

import Foundation
import XCTest
@testable import MarkdownPDF

final class SupportRuleTests: XCTestCase {

    func testUnquoteHandlesQuotesAndLists() {
        XCTAssertEqual(FrontMatterParsing.unquote("  \"Quoted title\"  "), "Quoted title")
        XCTAssertEqual(FrontMatterParsing.unquote("'single'"), "single")
        XCTAssertEqual(FrontMatterParsing.unquote("[a, \"b\", c]"), "a, b, c")
        XCTAssertEqual(FrontMatterParsing.unquote("plain"), "plain")
    }

    func testFenceRules() {
        let (matter, body) = FrontMatterParsing.split("---\ntitle: T\nstray line\n# comment: no\n---\nBody")
        XCTAssertEqual(matter.title, "T")
        XCTAssertEqual(matter.fields.count, 1, "a stray line and a comment cost nothing")
        XCTAssertEqual(body, "Body")
        let (none, all) = FrontMatterParsing.split("No fences\n---\nhere")
        XCTAssertTrue(none.isEmpty)
        XCTAssertEqual(all, "No fences\n---\nhere", "a mid-document --- is a rule, not a fence")
    }

    func testMonochromeThresholds() {
        XCTAssertTrue(ThemeRules.isMonochrome(accentHex: "#111111"))
        XCTAssertTrue(ThemeRules.isMonochrome(accentHex: "#101418"), "near-black with a whisper of hue is still mono")
        XCTAssertFalse(ThemeRules.isMonochrome(accentHex: "#001030"), "a dark navy is a brand, not black")
        XCTAssertFalse(ThemeRules.isMonochrome(accentHex: "#333333"), "mid-grey is a choice, not monochrome")
    }

    func testAutolinkLeavesThePunctuationToTheSentence() {
        let linked = Parser.autolinked("see https://example.com/a.")
        XCTAssertEqual(linked, [.text("see "), .link([.text("https://example.com/a")], url: "https://example.com/a"), .text(".")])
        let bracketed = Parser.autolinked("(https://example.com/a)")
        XCTAssertEqual(bracketed[1], .link([.text("https://example.com/a")], url: "https://example.com/a"))
        let path = Parser.autolinked("https://en.wikipedia.org/wiki/A_(b)")
        XCTAssertEqual(path, [.link([.text("https://en.wikipedia.org/wiki/A_(b)")], url: "https://en.wikipedia.org/wiki/A_(b)")], "a bracket that opens inside the URL stays")
    }
}
