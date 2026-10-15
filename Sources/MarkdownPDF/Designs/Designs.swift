//
//  Designs.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The designs the package carries, and how a design file is read.
//
//  A design is JSON, compiled in (`Support/DesignCatalogText.swift`). The
//  Swift here only names them, reads them strictly, and writes one out for
//  somebody to start from.
//

import Foundation
import RecipeKit

/// The bundled designs, by name.
public enum DesignKind: String, CaseIterable, Sendable {

    /// A business report: title and byline, ruled headings, page numbers.
    case report

    /// A memo: To / From / Date / Re from the front matter, then the text.
    case memo

    /// Serif, centred title, for an essay or a piece of writing.
    case article

    /// Nothing but the text, set well. What a rendered README looks like.
    case plain

    /// Technical: numbered headings, bordered code, an accent band.
    case manual

    /// The design, read from its file.
    public var blueprint: Blueprint { .bundled(rawValue) }

    public var displayName: String { rawValue.capitalised }

    public var description: String { blueprint.description }
}

extension Blueprint {

    /// Every bundled design, read once.
    public static let starting: [Blueprint] = DesignCatalogText.all.map { read($0.name, $0.json) }

    /// The bundled designs' names, in the order they are listed.
    public static let bundledNames = DesignKind.allCases.map(\.rawValue)

    /// A bundled design by name.
    ///
    /// A name the package does not carry is a programming error here —
    /// a caller with a name from outside goes through ``DesignKind`` and
    /// gets nil instead.
    public static func bundled(_ name: String) -> Blueprint {
        guard let design = starting.first(where: { $0.name == name }) else {
            preconditionFailure("The bundled design \(name) is not in the package")
        }
        return design
    }

    /// Every problem with the bundled designs: one that does not read
    /// strictly, a name that is not kebab-case, listed twice, not the one its
    /// entry is filed under, or not a ``DesignKind``. A test asserts there
    /// are none, so a bad entry fails the build's tests rather than a run.
    public static var catalogueProblems: [String] {
        var seen = Set<String>()
        var found = DesignCatalogText.all.flatMap { entry -> [String] in
            var problems = StyleCatalogs.nameProblems(entry.name, seen: &seen)
            do {
                let design = try JSONDecoder().decode(Blueprint.self, from: Data(entry.json.utf8))
                if design.name != entry.name { problems.append("\(entry.name): calls itself \(design.name)") }
            } catch {
                problems.append("\(entry.name): \(Decoding.describe(error))")
            }
            return problems
        }
        let names = Set(DesignCatalogText.all.map(\.name))
        found += DesignKind.allCases.map(\.rawValue).filter { !names.contains($0) }.map { "\($0): no design" }
        return found
    }

    /// A bundled design's JSON, read. A design is part of the package, so one
    /// that does not read is a build fault, and ``catalogueProblems`` is the
    /// test for it.
    private static func read(_ name: String, _ json: String) -> Blueprint {
        do { return try JSONDecoder().decode(Blueprint.self, from: Data(json.utf8)) } catch {
            preconditionFailure("The bundled design \(name) does not read: \(Decoding.describe(error))")
        }
    }

    // MARK: Files

    /// Reads a design from a file, strictly: a key a design does not have is
    /// refused by name, with the one it was probably meant to be.
    public init(contentsOf url: URL) throws {
        self = try JSONDecoder().decode(Blueprint.self, from: try Data(contentsOf: url))
    }

    /// The design as JSON, for somebody to start from.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
