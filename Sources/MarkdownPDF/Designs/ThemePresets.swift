//
//  ThemePresets.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The preset themes this library carries. The shape is DocumentTheme's;
//  the choices — a navy, a classic serif, a US Letter — are this library's,
//  as data in `ThemeCatalogText`.
//

import Foundation
import RecipeKit

/// The bundled preset themes, by name.
public enum ThemePresets {

    /// Their names, in the order they are listed.
    public static let names = ThemeCatalogText.all.map(\.name)

    /// Every preset, read once.
    public static let all: [Theme] = ThemeCatalogText.all.map { read($0.name, $0.json) }

    /// Restrained and monochrome.
    public static var plain: Theme { named("plain")! }

    /// A quiet ink blue.
    public static var navy: Theme { named("navy")! }

    /// Set in the serif, relaxed and justified, for an essay.
    public static var classic: Theme { named("classic")! }

    /// US Letter.
    public static var american: Theme { named("american")! }

    /// A preset by name, however it was typed; nil for a name that is not one.
    public static func named(_ name: String) -> Theme? {
        names.firstIndex(of: name.lowercased()).map { all[$0] }
    }

    /// Every problem with the bundled presets: one that does not read, a
    /// name that is not kebab-case or is listed twice. A test asserts there
    /// are none, so a bad entry fails the build's tests rather than a run.
    public static var problems: [String] {
        var seen = Set<String>()
        return ThemeCatalogText.all.flatMap { entry -> [String] in
            var found = StyleCatalogs.nameProblems(entry.name, seen: &seen)
            do { _ = try JSONDecoder().decode(Theme.self, from: Data(entry.json.utf8)) } catch {
                found.append("\(entry.name): \(Decoding.describe(error))")
            }
            return found
        }
    }

    /// The preset's JSON, read. A preset is part of the package, so one that
    /// does not read is a build fault, and ``problems`` is the test for it.
    private static func read(_ name: String, _ json: String) -> Theme {
        do { return try JSONDecoder().decode(Theme.self, from: Data(json.utf8)) } catch {
            preconditionFailure("The bundled theme \(name) does not read: \(Decoding.describe(error))")
        }
    }
}
