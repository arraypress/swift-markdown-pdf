//
//  SchemaTests.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The schemas are kept honest here. A small validator — types, enums,
//  properties, `$ref`, `oneOf` — is enough to prove that every file the
//  package carries and every sample it ships fits the schema that claims
//  to describe it, so a key added to the model without the schema
//  following is caught in this file rather than in somebody's editor.
//

import XCTest
@testable import MarkdownPDF

final class SchemaTests: XCTestCase {

    // MARK: A validator, small enough to trust

    private struct Mismatch: Error, CustomStringConvertible {
        let path: String
        let reason: String
        var description: String { "\(path): \(reason)" }
    }

    private func schema(_ which: Schema) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: which.data) as? [String: Any])
    }

    private func validate(_ value: Any, against node: [String: Any], root: [String: Any], path: String = "$") throws {
        if let ref = node["$ref"] as? String {
            let name = ref.replacingOccurrences(of: "#/$defs/", with: "")
            let defs = try XCTUnwrap(root["$defs"] as? [String: Any])
            let target = try XCTUnwrap(defs[name] as? [String: Any], "unknown $ref \(ref)")
            return try validate(value, against: target, root: root, path: path)
        }
        for key in ["oneOf", "anyOf"] {
            if let branches = node[key] as? [[String: Any]] {
                var failures: [String] = []
                for branch in branches {
                    do { try validate(value, against: branch, root: root, path: path); return }
                    catch let mismatch as Mismatch { failures.append(mismatch.reason) }
                }
                throw Mismatch(path: path, reason: "matched no branch of \(key): \(failures)")
            }
        }
        // JSON's true and false come back as NSNumber like every other
        // number, and 0 and 1 bridge to Bool — so a boolean is told apart by
        // its CoreFoundation type, not by a cast.
        let isBoolean = (value as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() } ?? false
        if let type = node["type"] as? String {
            let ok: Bool
            switch type {
            case "string": ok = value is String
            case "number": ok = value is NSNumber && !isBoolean
            case "integer": ok = value is NSNumber && !isBoolean
            case "boolean": ok = isBoolean
            case "array": ok = value is [Any]
            case "object": ok = value is [String: Any]
            case "null": ok = value is NSNull
            default: ok = false
            }
            if !ok { throw Mismatch(path: path, reason: "is not \(type)") }
        }
        if let allowed = node["enum"] as? [String], let text = value as? String, !allowed.contains(text) {
            throw Mismatch(path: path, reason: "\"\(text)\" is not one of \(allowed)")
        }
        if let pattern = node["pattern"] as? String, let text = value as? String,
           text.range(of: pattern, options: .regularExpression) == nil {
            throw Mismatch(path: path, reason: "\"\(text)\" does not match \(pattern)")
        }
        if let object = value as? [String: Any] {
            let properties = node["properties"] as? [String: Any] ?? [:]
            if let required = node["required"] as? [String] {
                for key in required where object[key] == nil { throw Mismatch(path: path, reason: "missing \(key)") }
            }
            for (key, child) in object {
                if let property = properties[key] as? [String: Any] {
                    try validate(child, against: property, root: root, path: "\(path).\(key)")
                } else if let names = node["propertyNames"] as? [String: Any] {
                    try validate(key, against: names, root: root, path: "\(path).\(key)")
                    if let extra = node["additionalProperties"] as? [String: Any] {
                        try validate(child, against: extra, root: root, path: "\(path).\(key)")
                    }
                } else if let extra = node["additionalProperties"] as? [String: Any] {
                    try validate(child, against: extra, root: root, path: "\(path).\(key)")
                } else if node["additionalProperties"] as? Bool == false {
                    throw Mismatch(path: path, reason: "unknown key \(key)")
                }
            }
        }
        if let array = value as? [Any], let items = node["items"] as? [String: Any] {
            for (index, child) in array.enumerated() {
                try validate(child, against: items, root: root, path: "\(path)[\(index)]")
            }
        }
    }

    private func check(_ data: Data, against which: Schema, _ label: String) throws {
        let value = try JSONSerialization.jsonObject(with: data)
        let root = try schema(which)
        do { try validate(value, against: root, root: root) }
        catch let mismatch as Mismatch { XCTFail("\(label) against \(which.filename): \(mismatch)") }
    }

    private func files(in folder: String) throws -> [URL] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: folder, withExtension: nil))
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }

    // MARK: The schemas themselves

    func testEverySchemaIsAJSONSchemaDocument() throws {
        for which in Schema.allCases {
            let root = try schema(which)
            XCTAssertEqual(root["$schema"] as? String, "https://json-schema.org/draft/2020-12/schema", which.filename)
            XCTAssertEqual(root["type"] as? String, "object", which.filename)
            XCTAssertNotNil(root["properties"], which.filename)
            XCTAssertEqual(which.json.prefix(1), "{")
        }
    }

    func testEveryBundledDesignFitsTheBlueprintSchema() throws {
        for file in try files(in: "Designs") {
            try check(try Data(contentsOf: file), against: .blueprint, file.lastPathComponent)
        }
    }

    func testEveryThemePresetFitsTheThemeSchema() throws {
        for file in try files(in: "Themes") {
            try check(try Data(contentsOf: file), against: .theme, file.lastPathComponent)
        }
    }

    func testAnEncodedDesignAndThemeFitTheirSchemas() throws {
        try check(try DesignKind.manual.blueprint.encoded(), against: .blueprint, "manual, re-encoded")
        let theme = Theme(typeface: .custom(name: "Mine", regular: URL(fileURLWithPath: "/tmp/a.ttf")), accent: "#1F3A5F", logo: "l.png")
        try check(try JSONEncoder().encode(theme), against: .theme, "a custom theme")
    }

    func testTheSchemaRefusesATypo() throws {
        let root = try schema(.blueprint)
        let value = try JSONSerialization.jsonObject(with: Data(#"{ "name": "x", "headings": [{ "size": 12, "colur": "ink" }] }"#.utf8))
        XCTAssertThrowsError(try validate(value, against: root, root: root)) { error in
            XCTAssertTrue(String(describing: error).contains("colur"), String(describing: error))
        }
        let themeRoot = try schema(.theme)
        let bad = try JSONSerialization.jsonObject(with: Data(#"{ "accent": "blue" }"#.utf8))
        XCTAssertThrowsError(try validate(bad, against: themeRoot, root: themeRoot))
    }
}
