//
//  BlueprintTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  A design is a JSON file, and these prove it: every bundled design is
//  read from its file, round-trips through JSON, and renders the same
//  bytes whether it came from the package or from a file of your own.
//

import XCTest
@testable import MarkdownPDF

final class BlueprintTests: XCTestCase {

    private static let stamped = Date(timeIntervalSince1970: 1_776_000_000)

    func testEveryDesignIsAFileThePackageCarries() throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Designs", withExtension: nil))
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.map { $0.deletingPathExtension().lastPathComponent }
        XCTAssertEqual(Set(files), Set(DesignKind.allCases.map(\.rawValue)))
        XCTAssertEqual(Blueprint.starting.count, DesignKind.allCases.count)
    }

    func testEveryDesignRoundTripsThroughJSON() throws {
        for design in DesignKind.allCases {
            let original = design.blueprint
            let again = try JSONDecoder().decode(Blueprint.self, from: try original.encoded())
            XCTAssertEqual(again, original, design.rawValue)
            XCTAssertEqual(original.name, design.rawValue)
            XCTAssertFalse(original.description.isEmpty, "\(design.rawValue) has no description")
        }
    }

    func testAWrittenDesignRendersTheSameBytesAsTheBundledOne() throws {
        let manuscript = Manuscript(markdown: Fixtures.everything)
        let folder = try Fixtures.temporaryFolder()
        for design in DesignKind.allCases {
            let file = folder.appendingPathComponent("\(design.rawValue).json")
            try design.blueprint.encoded().write(to: file)
            let written = try Blueprint(contentsOf: file)
            XCTAssertEqual(try manuscript.render(design: written, creationDate: Self.stamped),
                           try manuscript.render(design: design, creationDate: Self.stamped),
                           "\(design.rawValue) drew differently from its file")
        }
    }

    func testAFileNamingOnlyItsNameIsThePlainDesign() throws {
        let sparse = try JSONDecoder().decode(Blueprint.self, from: Data(#"{ "name": "mine" }"#.utf8))
        XCTAssertEqual(sparse.name, "mine")
        XCTAssertEqual(sparse.displayName, "Mine")
        XCTAssertEqual(sparse.headings.count, 3)
        XCTAssertEqual(sparse.title.style, .plain)
        XCTAssertNoThrow(try Manuscript(markdown: Fixtures.everything).render(design: sparse))
    }

    func testAChoiceIsMatchedInAnyCaseAndATypoIsNamed() throws {
        let loose = try JSONDecoder().decode(Blueprint.self, from: Data(#"{ "typeface": "Serif", "title": { "style": "BAND" } }"#.utf8))
        XCTAssertEqual(loose.typeface, .serif)
        XCTAssertEqual(loose.title.style, .band)

        XCTAssertThrowsError(try JSONDecoder().decode(Blueprint.self, from: Data(#"{ "quote": { "bar": "purple" } }"#.utf8))) { error in
            let described = Decoding.describe(error)
            XCTAssertTrue(described.contains("purple"), described)
            XCTAssertTrue(described.contains("hairline"), "the real choices should be listed: \(described)")
            XCTAssertTrue(described.contains("quote"), "the key should be named: \(described)")
        }
    }

    func testDeeperHeadingsTakeTheLastStyle() {
        let design = DesignKind.report.blueprint
        XCTAssertEqual(design.heading(6), design.headings.last)
        XCTAssertEqual(design.heading(1), design.headings.first)
    }
}
