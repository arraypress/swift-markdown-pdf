//
//  Designs.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The designs the package carries, and how a design file is read.
//
//  A design is a JSON file in `Resources/Designs/`. The Swift here only
//  names them, reads them, and writes one out for somebody to start from.
//

import Foundation

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
    public static let starting: [Blueprint] = bundledNames.map { read($0) }

    /// The bundled designs' names, in the order they are listed.
    public static let bundledNames = DesignKind.allCases.map(\.rawValue)

    /// A bundled design by name.
    ///
    /// A name the package does not carry is a programming error here —
    /// a caller with a name from outside goes through ``DesignKind`` and
    /// gets nil instead.
    public static func bundled(_ name: String) -> Blueprint {
        guard let design = starting.first(where: { $0.name == name }) else {
            preconditionFailure("The bundled design \(name).json is not in the package")
        }
        return design
    }

    private static func read(_ name: String) -> Blueprint {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Designs") else {
            preconditionFailure("The bundled design \(name).json is not in the package")
        }
        do {
            let design = try Blueprint(contentsOf: url)
            precondition(design.name == name, "\(name).json calls itself \(design.name)")
            return design
        } catch {
            preconditionFailure("The bundled design \(name).json does not decode: \(Decoding.describe(error))")
        }
    }

    // MARK: Files

    /// Reads a design from a file.
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
