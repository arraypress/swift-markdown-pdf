//
//  Typography.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The typefaces, and how they are loaded.
//
//  Three families travel with the package: Inter for a sans, Source Serif 4
//  for a serif, JetBrains Mono for code. All under the Open Font License,
//  all embedded and subset into the document, so the page looks the same on
//  every machine that opens it — which is the property a PDF is for.
//

import Foundation
import TextPDF

/// A typeface the designs can be set in.
///
/// A struct rather than an enum so callers are not limited to what happens to
/// be bundled. Somebody with a brand face should not have to fork the package
/// to use it.
public struct Typeface: Sendable, Equatable, Codable {

    /// For diagnostics, and for a tool to name.
    public let name: String

    /// Files making up the family. Empty for a bundled one.
    let files: [Face]

    /// Which bundled family this is, if it is one.
    let bundled: String?

    struct Face: Sendable, Equatable, Codable {
        let path: String
        let weight: Int
        let italic: Bool
    }

    init(name: String, files: [Face], bundled: String?) {
        self.name = name
        self.files = files
        self.bundled = bundled
    }

    // MARK: Bundled

    /// Inter — a neutral grotesque with a tall x-height that stays legible
    /// at the sizes a dense page needs.
    public static let inter = Typeface(name: "Inter", files: [], bundled: "inter")

    /// Source Serif 4 — a transitional serif. Reads as considered rather
    /// than current.
    public static let sourceSerif = Typeface(name: "Source Serif 4", files: [], bundled: "sourceSerif")

    /// The bundled families, for a caller offering a choice.
    public static let bundledFamilies: [Typeface] = [.inter, .sourceSerif]

    // MARK: Your own

    /// A family loaded from files on disk: static TrueType instances, one
    /// per weight. Only the weights given are available; a design asking
    /// for one that is missing gets the nearest that is.
    public static func custom(
        name: String,
        regular: URL,
        medium: URL? = nil,
        semibold: URL? = nil,
        bold: URL? = nil,
        italic: URL? = nil
    ) -> Typeface {
        var faces = [Face(path: regular.path, weight: 400, italic: false)]
        if let medium { faces.append(Face(path: medium.path, weight: 500, italic: false)) }
        if let semibold { faces.append(Face(path: semibold.path, weight: 600, italic: false)) }
        if let bold { faces.append(Face(path: bold.path, weight: 700, italic: false)) }
        if let italic { faces.append(Face(path: italic.path, weight: 400, italic: true)) }
        return Typeface(name: name, files: faces, bundled: nil)
    }

    public var displayName: String { name }

    /// The bundled files making up a family, by weight and slope.
    var bundledFaces: [(file: String, weight: FontFamily.Weight, italic: Bool)] {
        switch bundled {
        case "sourceSerif":
            return [
                ("SourceSerif4-Regular", .regular, false),
                ("SourceSerif4-Semibold", .semibold, false),
                ("SourceSerif4-Bold", .bold, false),
                ("SourceSerif4-It", .regular, true),
            ]
        default:
            return [
                ("Inter-Regular", .regular, false),
                ("Inter-Medium", .medium, false),
                ("Inter-SemiBold", .semibold, false),
                ("Inter-Bold", .bold, false),
                ("Inter-Italic", .regular, true),
            ]
        }
    }

    static let monoFaces: [(file: String, weight: FontFamily.Weight, italic: Bool)] = [
        ("JetBrainsMono-Regular", .regular, false),
        ("JetBrainsMono-Medium", .medium, false),
        ("JetBrainsMono-Bold", .bold, false),
    ]

    // MARK: Codable

    /// A bundled family is its name — `"inter"`, `"serif"` — and a family
    /// of your own is the object; either reads back to the same value.
    public init(from decoder: Decoder) throws {
        if let name = try decoder.shorthand() {
            guard let family = Typeface.bundled(named: name) else {
                throw DecodingError.noSuch("typeface", called: name,
                                           options: ["inter", "sans", "sourceSerif", "serif"],
                                           at: decoder.codingPath)
            }
            self = family
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.value(.name, or: "Custom")
        files = try container.value(.files, or: [])
        bundled = try container.maybe(.bundled)
    }

    public func encode(to encoder: Encoder) throws {
        if files.isEmpty, let bundled {
            var single = encoder.singleValueContainer()
            try single.encode(bundled)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(files, forKey: .files)
        try container.encodeIfPresent(bundled, forKey: .bundled)
    }

    enum CodingKeys: String, CodingKey { case name, files, bundled }

    /// The bundled family a short name means.
    static func bundled(named name: String) -> Typeface? {
        switch name.lowercased() {
        case "inter", "sans": return .inter
        case "sourceserif", "serif": return .sourceSerif
        default: return nil
        }
    }
}

/// Loads the families.
public enum Typography {

    /// JetBrains Mono, for code.
    public static func mono() throws -> FontFamily {
        var family = FontFamily(name: "JetBrains Mono")
        for face in Typeface.monoFaces {
            family.add(try load(face.file), weight: face.weight, italic: face.italic)
        }
        return family
    }

    /// A fresh family, loaded from the package's resources or from the
    /// caller's files.
    ///
    /// Fresh each call, deliberately: an ``EmbeddedFont`` accumulates the
    /// glyphs it has drawn so it can subset itself, so one shared between
    /// two documents would carry the first's characters into the second.
    public static func family(_ typeface: Typeface) throws -> FontFamily {
        var family = FontFamily(name: typeface.displayName)

        guard typeface.files.isEmpty else {
            for face in typeface.files {
                let weight = FontFamily.Weight(rawValue: face.weight) ?? .regular
                family.add(try EmbeddedFont.load(URL(fileURLWithPath: face.path)),
                           weight: weight, italic: face.italic)
            }
            return family
        }

        for face in typeface.bundledFaces {
            family.add(try load(face.file), weight: face.weight, italic: face.italic)
        }
        return family
    }

    private static func load(_ file: String) throws -> EmbeddedFont {
        guard let url = Bundle.module.url(forResource: file, withExtension: "ttf", subdirectory: "Fonts") else {
            throw MarkdownPDFError.missingFont("\(file).ttf")
        }
        return try EmbeddedFont.load(url)
    }
}

// MARK: - Errors

public enum MarkdownPDFError: Error, LocalizedError, Equatable {

    /// A bundled font file is not in the package.
    case missingFont(String)

    /// A design named that the package does not carry.
    case unknownDesign(String)

    public var errorDescription: String? {
        switch self {
        case .missingFont(let name):
            return "The font \(name) is missing from the package resources."
        case .unknownDesign(let name):
            return "There is no design called '\(name)'."
        }
    }
}
