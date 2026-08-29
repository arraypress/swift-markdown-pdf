//
//  READMEExamples.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Every Swift example in the README, compiled — with a plain `import`, so
//  what the README shows is reachable from outside the package. A drift
//  test checks the README's blocks appear here line for line.
//

import Foundation
import MarkdownPDF
import XCTest

final class READMEExamples: XCTestCase {

    private var out: URL { URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("readme-\(UUID().uuidString).pdf") }
    private var docx: URL { URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("readme-\(UUID().uuidString).docx") }
    private var file: URL { URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("readme-\(UUID().uuidString).json") }

    func testTheOpening() throws {
        let url = out.deletingPathExtension().appendingPathExtension("md")
        try Data("# Hi\n\nthere".utf8).write(to: url)
        let out = self.out, docx = self.docx

        let manuscript = try Manuscript(contentsOf: url)          // front matter + CommonMark/GFM
        try manuscript.save(to: out, design: .report)              // a PDF
        try manuscript.saveDocx(to: docx)                          // a Word document
        let pasted = manuscript.plainText()                        // for the box that takes nothing else
        _ = pasted
    }

    func testTheDesigns() throws {
        let manuscript = Manuscript(markdown: "# Hi\n\nthere")
        let url = out
        try manuscript.save(to: url, design: .memo)
        try manuscript.save(to: url, design: .article, theme: .classic)
        let data = try manuscript.render(design: .manual, theme: Theme(accent: "#1F3A5F"))
        _ = data
    }

    func testThemes() throws {
        let themes: [Theme?] = [
        Theme(accent: "#1F3A5F"),                         // an ink blue on rules, headings and links
        Theme(typeface: .sourceSerif),                    // the serif, whatever the design was drawn for
        Theme(pageSize: .letter, density: .compact),      // US paper, tighter
        Theme(justified: true, logo: "logo.png"),         // flush edges, a logo where the design has a place
        Theme.named("navy"),                              // a preset, from its file
        ]
        XCTAssertEqual(themes.count, 5)
    }

    func testWordAndText() throws {
        let manuscript = Manuscript(markdown: "# Hi\n\nthere")
        let url = docx
        try manuscript.saveDocx(to: url)                 // headings, emphasis, links, lists, in the theme's face
        let text = manuscript.plainText()                // headings on their lines, a dash per item, tables as columns
        _ = text
    }

    func testTheCheck() throws {
        let manuscript = Manuscript(markdown: "# Hi\n\nthere")
        let report = try manuscript.check(design: .report)
        let clean = report.isClean                       // no blockers
        let pages = report.pages                         // how many it ran to
        for finding in report.findings { print(finding.severity, finding.message, finding.detail) }
        _ = (clean, pages)
    }

    func testADesignOfYourOwn() throws {
        let manuscript = Manuscript(markdown: "# Hi\n\nthere")
        let file = self.file
        try DesignKind.plain.blueprint.encoded().write(to: file)
        let url = out
        let mine = try Blueprint(contentsOf: file)       // a JSON file, edited from one of the five
        try manuscript.save(to: url, design: mine)
        let json = try DesignKind.report.blueprint.encoded()   // the report, to start from
        _ = json
    }

    func testTheSchemas() {
        let schema = Schema.blueprint.json               // JSON Schema, draft 2020-12
        _ = schema
    }
}
