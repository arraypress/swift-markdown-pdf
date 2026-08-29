//
//  ThemeTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//

import XCTest
@testable import MarkdownPDF

final class ThemeTests: XCTestCase {

    func testEveryPresetIsAFileThePackageCarries() throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Themes", withExtension: nil))
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.map { $0.deletingPathExtension().lastPathComponent }
        XCTAssertEqual(Set(files), Set(Theme.presetNames))
        XCTAssertEqual(Theme.presets.count, Theme.presetNames.count)
        XCTAssertEqual(Theme.named("Navy")?.accent, "#1F3A5F")
        XCTAssertNil(Theme.named("sepia"))
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

    func testMonochromeIsNearBlack() {
        XCTAssertTrue(Theme(accent: "#111111").isMonochrome)
        XCTAssertTrue(Theme(accent: "#000000").isMonochrome)
        XCTAssertFalse(Theme(accent: "#1F3A5F").isMonochrome)
    }

    func testATypefaceOfYourOwnIsUsed() throws {
        // The bundled files stand in for somebody's own family.
        let fonts = try XCTUnwrap(Bundle.module.url(forResource: "Fonts", withExtension: nil))
        let custom = Typeface.custom(name: "Mine", regular: fonts.appendingPathComponent("SourceSerif4-Regular.ttf"),
                                     bold: fonts.appendingPathComponent("SourceSerif4-Bold.ttf"))
        let data = try Manuscript(markdown: "# Hi\n\n**bold** and plain").render(design: .plain, theme: Theme(typeface: custom))
        XCTAssertTrue(data.contains(Data("SourceSerif".utf8)))
        XCTAssertFalse(data.contains(Data("Inter-Regular".utf8)), "the design's own face should not be embedded when a theme names one")
    }
}
