//
//  ExampleTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The examples in the repository, written by the library that makes them.
//
//  A design is a thing you look at, and a list of names is not one — so every
//  design and every theme preset is committed as a PDF somebody can open
//  before installing anything, all from `Examples/sample.md`.
//
//  They are generated rather than curated, so nothing can go stale quietly:
//
//      WRITE_EXAMPLES=1 swift test --filter ExampleTests
//
//  The creation date is pinned. A PDF carries one, so regenerating would
//  otherwise rewrite every file whether or not anything about it changed.
//

import PDFKit
import XCTest
@testable import MarkdownPDF

final class ExampleTests: XCTestCase {

    /// Somewhere stable, so the same content produces the same bytes.
    static let stamped = Date(timeIntervalSince1970: 1_776_000_000)

    private var writing: Bool { ProcessInfo.processInfo.environment["WRITE_EXAMPLES"] == "1" }

    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MarkdownPDFTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // the package
            .appendingPathComponent("Examples", isDirectory: true)
    }

    static func sample() throws -> Manuscript {
        try Manuscript(contentsOf: directory.appendingPathComponent("sample.md"))
    }

    private func put(_ data: Data, _ name: String) throws {
        // Rendered either way: the point of doing this in a test is that every
        // example is proved to render on every run, not only when written.
        XCTAssertNotNil(PDFDocument(data: data), "\(name) is not a readable PDF")
        XCTAssertGreaterThan(data.count, 2_000, "\(name) came out suspiciously small")

        guard writing else { return }
        let file = Self.directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file)
    }

    func testEveryDesign() throws {
        let sample = try Self.sample()
        for design in DesignKind.allCases {
            let data = try sample.render(design: design, creationDate: Self.stamped)
            try put(data, "designs/\(design.rawValue).pdf")

            let pdf = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertGreaterThanOrEqual(pdf.pageCount, 2, "\(design.rawValue): the sample runs to more than a page")
            XCTAssertLessThanOrEqual(pdf.pageCount, 4, "\(design.rawValue): the sample should not run to \(pdf.pageCount) pages")
            let text = try XCTUnwrap(pdf.string)
            XCTAssertTrue(text.contains("Recommendations"), "\(design.rawValue): a heading went missing")
            XCTAssertTrue(text.contains("exhausted"), "\(design.rawValue): the code block went missing")
        }
    }

    func testEveryThemePreset() throws {
        let sample = try Self.sample()
        for name in Theme.presetNames {
            let theme = try XCTUnwrap(Theme.named(name))
            try put(try sample.render(design: .report, theme: theme, creationDate: Self.stamped), "themes/\(name).pdf")
        }
    }
}
