//
//  ManuscriptTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Front matter, titles and what a manuscript knows about itself.
//

import XCTest
@testable import MarkdownPDF

final class ManuscriptTests: XCTestCase {

    func testFrontMatterIsSplitOffTheTop() {
        let manuscript = Manuscript(markdown: """
            ---
            title: "Quoted Title"
            author: Alex Moreau
            date: 2026-08-30
            tags: [one, two]
            # a comment
            not a field
            ---
            # Body

            text
            """)
        XCTAssertEqual(manuscript.frontMatter.title, "Quoted Title")
        XCTAssertEqual(manuscript.frontMatter.author, "Alex Moreau")
        XCTAssertEqual(manuscript.frontMatter["tags"], "one, two")
        XCTAssertEqual(manuscript.frontMatter.fields.count, 4)
        XCTAssertEqual(manuscript.blocks.first, .heading(level: 1, [.text("Body")]))
    }

    func testARuleIsNotAFence() {
        let manuscript = Manuscript(markdown: "para\n\n---\n\nmore")
        XCTAssertTrue(manuscript.frontMatter.isEmpty)
        XCTAssertEqual(manuscript.blocks.count, 3)
    }

    func testTheTitleComesFromTheFrontMatterOrTheHeading() {
        XCTAssertEqual(Manuscript(markdown: "---\ntitle: From matter\n---\n# From heading").title, "From matter")
        XCTAssertEqual(Manuscript(markdown: "# From heading\n\ntext").title, "From heading")
        XCTAssertEqual(Manuscript(markdown: "text only").title, "")
    }

    func testTheLeadingHeadingIsDroppedFromTheBodyWhenItIsTheTitle() {
        let heading = Manuscript(markdown: "# The Title\n\ntext")
        XCTAssertEqual(heading.body.count, 1, "the heading is the title; the body is what is under it")

        let same = Manuscript(markdown: "---\ntitle: The Title\n---\n# the title\n\ntext")
        XCTAssertEqual(same.body.count, 1, "the heading says the title; drawn once")

        let different = Manuscript(markdown: "---\ntitle: The Title\n---\n# Introduction\n\ntext")
        XCTAssertEqual(different.body.count, 2, "a different heading is content")
    }

    func testHeadingsWordsAndPictures() {
        let manuscript = Manuscript(markdown: "# A\n\nfour words are here\n\n## B\n\n![x](a.png) and ![y](b.jpg)\n\n![z](c.png)")
        XCTAssertEqual(manuscript.headings.map(\.text), ["A", "B"])
        XCTAssertEqual(manuscript.headings.map(\.level), [1, 2])
        XCTAssertEqual(manuscript.imageSources, ["a.png", "b.jpg", "c.png"])
        XCTAssertGreaterThanOrEqual(manuscript.wordCount, 8)
    }

    func testPathsResolveFromTheFile() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("md-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("doc.md")
        try Data("# Hi\n\n![p](pics/one.png)".utf8).write(to: file)

        let manuscript = try Manuscript(contentsOf: file)
        XCTAssertEqual(manuscript.title, "Hi")
        XCTAssertEqual(manuscript.resolve("pics/one.png").path, folder.appendingPathComponent("pics/one.png").path)
        XCTAssertEqual(manuscript.resolve("/abs/one.png").path, "/abs/one.png")
    }
}
