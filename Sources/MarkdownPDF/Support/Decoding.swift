//
//  Decoding.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Reading JSON without demanding every field.
//
//  Swift's synthesised decoder does not use a property's default value, so a
//  design file would have to spell out every setting to change one. The
//  decoders are written out instead: each type defaults what is absent and
//  refuses what is wrong, naming the key — because a design and a theme are
//  typed by hand, and "the file is invalid" is not an answer.
//

import Foundation

extension KeyedDecodingContainer {

    /// The value at `key`, or `fallback` when the key is absent or null.
    /// Absent and *wrong* are different answers: a malformed value throws
    /// and names itself.
    func value<T: Decodable>(_ key: Key, or fallback: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? fallback
    }

    /// The value at `key`, or nothing when it is absent or null.
    func maybe<T: Decodable>(_ key: Key) throws -> T? {
        try decodeIfPresent(T.self, forKey: key)
    }

    /// A named choice at `key`, matched against its cases without regard
    /// to case, or `fallback` when absent. A name that is none of them is
    /// refused with the names that are.
    func choice<T: RawRepresentable & CaseIterable>(
        _ key: Key, or fallback: T, called what: String
    ) throws -> T where T.RawValue == String {
        guard let written = try decodeIfPresent(String.self, forKey: key) else { return fallback }
        guard let matched = T.matching(written) else {
            throw DecodingError.noSuch(what, called: written, options: T.allCases.map(\.rawValue),
                                       at: codingPath + [key])
        }
        return matched
    }
}

extension Decoder {

    /// The value as a bare string, where the JSON wrote one instead of an
    /// object — `"typeface": "serif"` — or nil where it did not.
    func shorthand() throws -> String? {
        guard let single = try? singleValueContainer() else { return nil }
        return try? single.decode(String.self)
    }
}

extension RawRepresentable where Self: CaseIterable, RawValue == String {

    /// The case whose name this is, in any case.
    static func matching(_ written: String) -> Self? {
        let typed = written.lowercased()
        return allCases.first { $0.rawValue.lowercased() == typed }
    }
}

extension DecodingError {

    /// "There is no page size called 'foolscap' — one of: A4, Letter".
    static func noSuch(_ what: String, called written: String, options: [String],
                       at path: [CodingKey]) -> DecodingError {
        DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: path,
            debugDescription: "There is no \(what) called '\(written)' — one of: " + options.joined(separator: ", ")
        ))
    }
}

/// Describes a decoding failure the way a person reads a file: by key.
public enum Decoding {

    /// One line naming the key and what is wrong with it.
    public static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else { return error.localizedDescription }

        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { key -> String in
                if let index = key.intValue { return "[\(index)]" }
                return key.stringValue
            }
            return keys.joined(separator: ".").replacingOccurrences(of: ".[", with: "[")
        }

        switch decoding {
        case .keyNotFound(let key, let context):
            let at = path(context)
            return "\"\(key.stringValue)\" is missing" + (at.isEmpty ? "" : " in \(at)")
        case .typeMismatch(_, let context):
            return "\"\(path(context))\" — \(context.debugDescription)"
        case .valueNotFound(_, let context):
            return "\"\(path(context))\" is null"
        case .dataCorrupted(let context):
            let at = path(context)
            return (at.isEmpty ? "" : "\"\(at)\" — ") + context.debugDescription
        @unknown default:
            return error.localizedDescription
        }
    }
}
