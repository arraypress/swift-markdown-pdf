//
//  CheckTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//

import XCTest
@testable import MarkdownPDF

final class CheckTests: XCTestCase {

    private func report(_ markdown: String, design: DesignKind = .report) throws -> Report {
        try Manuscript(markdown: markdown).check(design: design)
    }

    func testACleanDocumentIsClean() throws {
        let report = try self.report(Fixtures.everything)
        XCTAssertTrue(report.isClean, "\(report.findings)")
        XCTAssertEqual(report.pages, 1)
        XCTAssertGreaterThan(report.wordCount, 20)
        XCTAssertTrue(report.findings.isEmpty, "\(report.findings.map(\.message))")
    }

    func testNoTitleIsANote() throws {
        let findings = try report("just words").findings
        XCTAssertEqual(findings.map(\.severity), [.note])
        XCTAssertTrue(findings[0].message.contains("no title"))
    }

    func testASkippedHeadingLevelIsNamed() throws {
        let findings = try report("# T\n\ntext\n\n### Three\n\ntext").findings(.warning)
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings[0].message.contains("Three"), findings[0].message)
        XCTAssertTrue(findings[0].message.contains("level 1") && findings[0].message.contains("level 3"), findings[0].message)
    }

    func testAHeadingOfNothingIsNamed() throws {
        let findings = try report("# T\n\n## Empty\n\n## Full\n\ntext\n\n## Trailing").findings(.warning)
        XCTAssertEqual(findings.map(\.message), [
            "\"Empty\" is a heading with nothing under it.",
            "\"Trailing\" is a heading with nothing under it.",
        ])
    }

    func testAMissingPictureBlocks() throws {
        let report = try self.report("# T\n\n![gone](nowhere.png)")
        XCTAssertFalse(report.isClean)
        XCTAssertEqual(report.findings(.blocker).count, 1)
        XCTAssertTrue(report.findings(.blocker)[0].message.contains("nowhere.png"))
    }

    func testAPictureThatIsNotOneBlocks() throws {
        let folder = try Fixtures.temporaryFolder()
        try Data("not a picture".utf8).write(to: folder.appendingPathComponent("bad.png"))
        let file = folder.appendingPathComponent("doc.md")
        try Data("# T\n\n![x](bad.png)".utf8).write(to: file)
        let report = try Manuscript(contentsOf: file).check(design: .report)
        XCTAssertEqual(report.findings(.blocker).count, 1)
        XCTAssertTrue(report.findings(.blocker)[0].message.contains("cannot be used"))
    }

    func testHTMLIsSaidToBeDropped() throws {
        let findings = try report("# T\n\n<table><tr><td>x</td></tr></table>").findings(.warning)
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings[0].message.contains("HTML"))
    }

    func testAnEmptyLinkIsCounted() throws {
        let findings = try report("# T\n\n[one]() and [two]() and [ok](https://x.y)").findings(.warning)
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings[0].message.hasPrefix("2 links"), findings[0].message)
    }

    func testATableTooWideForThePage() throws {
        let header = (1...14).map { "c\($0)" }.joined(separator: " | ")
        let rule = (1...14).map { _ in "---" }.joined(separator: " | ")
        let findings = try report("# T\n\n| \(header) |\n| \(rule) |\n| \(header) |").findings(.warning)
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings[0].message.contains("14 columns"), findings[0].message)
    }

    func testARaggedTableIsSquaredByTheParser() throws {
        // cmark pads a short row and drops a long one's extra cells, so
        // nothing ragged reaches the page — there is nothing to report.
        let manuscript = Manuscript(markdown: "# T\n\n| a | b |\n|---|---|\n| 1 |\n| 1 | 2 | 3 |")
        guard case .table(let table)? = manuscript.blocks.last else { return XCTFail("not a table") }
        XCTAssertEqual(table.rows.map(\.count), [2, 2])
        XCTAssertTrue(try manuscript.check(design: .report).findings.isEmpty)
    }

    func testALongLineOfCodeIsANote() throws {
        let long = String(repeating: "x", count: 200)
        let findings = try report("# T\n\n```\nshort\n\(long)\n```").findings(.note)
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings[0].message.hasPrefix("1 line of code"), findings[0].message)
    }

    func testFindingsAreOrderedBySeverity() throws {
        let report = try self.report("just words\n\n![gone](no.png)\n\n<div>x</div>")
        XCTAssertEqual(report.findings.map(\.severity), [.blocker, .warning, .note])
    }
}
