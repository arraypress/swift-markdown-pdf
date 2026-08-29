//
//  Theme.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  How a design looks, separated from which design it is.
//
//  A theme is the brand: the typeface, the accent, the page, the logo. It
//  does not change the arrangement — that is the design's job. The split is
//  what lets one set of settings produce a report, a memo and an article that
//  visibly belong to the same author, and it is the same handful of fields
//  the family's other document libraries read, so one file can feed them all.
//

import Foundation
import TextPDF

/// The look applied to a design.
public struct Theme: Sendable, Equatable, Codable {

    /// The typeface, where somebody chose one.
    ///
    /// `nil` means *no preference*, and the design's own face decides. A
    /// value always wins — it is the caller's page.
    public let typeface: Typeface?

    /// Brand colour as hex. Spent on rules, headings and links, never on
    /// body text.
    public let accent: String

    public let pageSize: PageSize

    /// How tightly the page is set.
    public let density: Density

    /// Whether body prose is set flush to both edges.
    public let justified: Bool

    /// A logo, as a path to a PNG or JPEG, for the designs that have a
    /// place for one. Relative to wherever the theme came from, resolved
    /// by whoever read it.
    public let logo: String?

    public init(
        typeface: Typeface? = nil,
        accent: String = "#111111",
        pageSize: PageSize = .a4,
        density: Density = .normal,
        justified: Bool = false,
        logo: String? = nil
    ) {
        self.typeface = typeface
        self.accent = accent
        self.pageSize = pageSize
        self.density = density
        self.justified = justified
        self.logo = logo
    }

    /// Whether the accent is near enough black that colour should not be
    /// spent on anything — a rule in "#111111" reads as a rule, and a
    /// heading in it as a heading, not as a brand.
    public var isMonochrome: Bool {
        let colour = Color.hex(accent)
        return max(colour.red, colour.green, colour.blue) < 40
            && abs(colour.red - colour.green) < 12 && abs(colour.green - colour.blue) < 12
    }

    var accentColor: Color { Color.hex(accent) }

    // MARK: Presets

    /// The bundled presets, each a JSON file in the package's resources.
    public static let presets: [Theme] = presetNames.map { bundled($0) }

    public static let presetNames = ["plain", "navy", "classic", "american"]

    public static let plain = bundled("plain")
    public static let navy = bundled("navy")
    public static let classic = bundled("classic")
    public static let american = bundled("american")

    /// A preset by name, or nil for a name that is not one.
    public static func named(_ name: String) -> Theme? {
        guard presetNames.contains(name.lowercased()) else { return nil }
        return bundled(name.lowercased())
    }

    /// The preset's file, read.
    static func bundled(_ name: String) -> Theme {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Themes"),
              let data = try? Data(contentsOf: url),
              let theme = try? JSONDecoder().decode(Theme.self, from: data)
        else {
            preconditionFailure("The bundled theme \(name).json is not in the package, or does not decode")
        }
        return theme
    }

    // MARK: Codable

    /// An absent `typeface` decodes as *no preference*; every other key
    /// has the initialiser's default. Names — page size, density — match
    /// without regard to case, because a theme file is typed by hand.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            typeface: try container.maybe(.typeface),
            accent: try container.value(.accent, or: "#111111"),
            pageSize: try container.choice(.pageSize, or: .a4, called: "page size"),
            density: try container.choice(.density, or: .normal, called: "density"),
            justified: try container.value(.justified, or: false),
            logo: try container.maybe(.logo)
        )
    }

    enum CodingKeys: String, CodingKey {
        case typeface, accent, pageSize, density, justified, logo
    }
}

// MARK: - Density

/// How tightly the page is set.
public enum Density: String, Sendable, CaseIterable, Codable {

    /// For a document with room to breathe.
    case relaxed

    case normal

    /// A few more lines on every page.
    case compact

    /// Multiplier on the vertical rhythm.
    var leading: Double {
        switch self {
        case .relaxed: return 1.12
        case .normal: return 1.0
        case .compact: return 0.9
        }
    }

    /// Multiplier on the margins.
    var margin: Double {
        switch self {
        case .relaxed: return 1.1
        case .normal: return 1.0
        case .compact: return 0.82
        }
    }
}
