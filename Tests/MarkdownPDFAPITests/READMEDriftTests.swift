//
//  READMEDriftTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//

import XCTest

/// Checks that what the README shows is what `READMEExamples.swift` compiles.
///
/// The examples file only proves the code in *it* builds. This proves the code
/// in it is the code the README prints — otherwise the two drift apart and the
/// compiled copy quietly certifies something nobody reads.
final class READMEDriftTests: XCTestCase {

    private var readme: String {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // MarkdownPDFAPITests
                .deletingLastPathComponent()   // Tests
                .deletingLastPathComponent()   // the package
            return try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        }
    }

    private var examples: String {
        get throws {
            let file = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("READMEExamples.swift")
            return try String(contentsOf: file, encoding: .utf8)
        }
    }

    /// The lines of a block, trimmed and stripped of blanks — so indenting an
    /// example inside a function is not drift, and renaming an argument is.
    private func lines(_ source: String) -> [String] {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func swiftBlocks(in markdown: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []
        var inside = false

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("```swift") {
                inside = true
                current = []
            } else if line.hasPrefix("```"), inside {
                inside = false
                blocks.append(current.joined(separator: "\n"))
            } else if inside {
                current.append(String(line))
            }
        }
        return blocks
    }

    func testEverySwiftExampleInTheREADMEIsCompiledSomewhere() throws {
        let compiled = lines(try examples)
        let blocks = swiftBlocks(in: try readme)

        XCTAssertGreaterThan(blocks.count, 5, "the README lost its examples")

        for block in blocks {
            let wanted = lines(block)
            guard !wanted.isEmpty else { continue }

            // Every line of the example, in order, somewhere in the file.
            var index = compiled.startIndex
            var missing: String?

            for line in wanted {
                guard let found = compiled[index...].firstIndex(of: line) else {
                    missing = line
                    break
                }
                index = compiled.index(after: found)
            }

            XCTAssertNil(
                missing,
                """
                This README example is not in READMEExamples.swift, so nothing \
                compiles it:

                \(block)

                First line not found: \(missing ?? "")
                """
            )
        }
    }
}
