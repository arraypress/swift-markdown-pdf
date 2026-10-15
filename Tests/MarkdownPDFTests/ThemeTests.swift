//
//  ThemeTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//

import XCTest
@testable import MarkdownPDF
import TextPDF

final class ThemeTests: XCTestCase {

    func testEveryPresetReadsUnderItsName() throws {
        XCTAssertEqual(ThemePresets.problems, [])
        XCTAssertEqual(ThemePresets.names, ["plain", "navy", "classic", "american"])
        XCTAssertEqual(ThemePresets.all.count, ThemePresets.names.count)
        XCTAssertEqual(ThemePresets.named("Navy")?.accent, "#1F3A5F")
        XCTAssertEqual(ThemePresets.plain, Theme(), "plain is the theme with nothing set")
        XCTAssertNil(ThemePresets.named("sepia"))
    }

    func testAThemeSurvivesJSONAndNamesItsChoicesInAnyCase() throws {
        let theme = Theme(typeface: .sourceSerif, accent: "#1F3A5F", pageSize: .letter, density: .compact, justified: true, logo: "logo.png")
        XCTAssertEqual(try JSONDecoder().decode(Theme.self, from: try JSONEncoder().encode(theme)), theme)

        let loose = try JSONDecoder().decode(Theme.self, from: Data(#"{ "pageSize": "letter", "density": "Compact", "typeface": "serif" }"#.utf8))
        XCTAssertEqual(loose.pageSize, .letter)
        XCTAssertEqual(loose.density, .compact)
        XCTAssertEqual(loose.typeface, .sourceSerif)
        XCTAssertNil(try JSONDecoder().decode(Theme.self, from: Data("{}".utf8)).typeface, "no typeface is no preference")
    }

    func testAMisspeltThemeKeyIsRefusedNotIgnored() {
        XCTAssertThrowsError(try JSONDecoder().decode(Theme.self, from: Data(##"{ "acent": "#1F3A5F" }"##.utf8))) { error in
            XCTAssertEqual(Decoding.describe(error), "acent is not a theme field — did you mean accent?")
        }
    }

    func testMonochromeIsNearBlack() {
        XCTAssertTrue(Theme(accent: "#111111").isMonochrome)
        XCTAssertTrue(Theme(accent: "#000000").isMonochrome)
        XCTAssertFalse(Theme(accent: "#1F3A5F").isMonochrome)
    }

    func testATypefaceOfYourOwnIsUsed() throws {
        // The bundled files stand in for somebody's own family.
        let custom = Typeface.custom(name: "Mine", regular: try XCTUnwrap(Typography.bundledFile("SourceSerif4-Regular")),
                                     bold: try XCTUnwrap(Typography.bundledFile("SourceSerif4-Bold")))
        let data = try Manuscript(markdown: "# Hi\n\n**bold** and plain").render(design: .plain, theme: Theme(typeface: custom))
        XCTAssertTrue(data.contains(Data("SourceSerif".utf8)))
        XCTAssertFalse(data.contains(Data("Inter-Regular".utf8)), "the design's own face should not be embedded when a theme names one")
    }
}
