//
//  Fixtures.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//

import AppKit
import Foundation
import PDFKit

enum Fixtures {

    /// A Markdown document with one of everything in it.
    static let everything = """
        ---
        title: Everything
        subtitle: One of each
        author: Alex Moreau
        date: 30 August 2026
        ---

        ## First section

        A paragraph with *emphasis*, **strength**, `code`, a [link](https://example.com/page) and ~~a strike~~.

        - one
        - two
          - nested
        - [x] done
        - [ ] not yet

        1. first
        2. second

        ```swift
        let answer = 42
        ```

        > Quoted words.

        | Left | Centre | Right |
        |:-----|:------:|------:|
        | a    | b      | c     |

        ---

        ### Deeper

        Last words.
        """

    /// Enough paragraphs to run past a page.
    static func long(paragraphs: Int) -> String {
        var out = "# A long one\n\n"
        for index in 1...paragraphs {
            out += "## Section \(index)\n\nParagraph \(index): " + String(repeating: "the quick brown fox jumps over the lazy dog ", count: 12) + "\n\n"
        }
        return out
    }

    /// A small PNG written to a temporary folder, and its path.
    static func png(named name: String = "figure.png", in folder: URL) throws -> URL {
        let image = NSImage(size: NSSize(width: 200, height: 100))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 200, height: 100).fill()
        image.unlockFocus()
        let tiff = try XCTUnwrapFixture(image.tiffRepresentation)
        let data = try XCTUnwrapFixture(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        let url = folder.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    static func temporaryFolder() throws -> URL {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("markdown-pdf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func text(of pdf: Data) -> String {
        PDFDocument(data: pdf)?.string ?? ""
    }

    private struct Missing: Error {}
    private static func XCTUnwrapFixture<T>(_ value: T?) throws -> T {
        guard let value else { throw Missing() }
        return value
    }
}
