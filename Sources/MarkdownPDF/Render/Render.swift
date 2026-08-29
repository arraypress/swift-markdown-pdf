//
//  Render.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The document, drawn.
//

import Foundation
import TextPDF

extension Manuscript {

    /// The document before it is written: for a caller who wants to add
    /// a page, a watermark, an attachment.
    public func document(design: Blueprint, theme: Theme = .plain) throws -> TextPDF.Document {
        try Typesetter(self, design: design, theme: theme).run()
    }

    public func document(design: DesignKind = .report, theme: Theme = .plain) throws -> TextPDF.Document {
        try document(design: design.blueprint, theme: theme)
    }

    /// The finished PDF.
    public func render(design: Blueprint, theme: Theme = .plain, creationDate: Date = Date()) throws -> Data {
        try document(design: design, theme: theme).render(metadata: metadata, creationDate: creationDate)
    }

    public func render(design: DesignKind = .report, theme: Theme = .plain, creationDate: Date = Date()) throws -> Data {
        try render(design: design.blueprint, theme: theme, creationDate: creationDate)
    }

    /// Writes the PDF, and returns its size in bytes.
    @discardableResult
    public func save(to url: URL, design: Blueprint, theme: Theme = .plain) throws -> Int {
        let data = try render(design: design, theme: theme)
        try data.write(to: url, options: .atomic)
        return data.count
    }

    @discardableResult
    public func save(to url: URL, design: DesignKind = .report, theme: Theme = .plain) throws -> Int {
        try save(to: url, design: design.blueprint, theme: theme)
    }

    /// What the PDF says about itself.
    var metadata: [String: String] {
        var fields = ["Creator": "MarkdownPDF"]
        if !title.isBlank { fields["Title"] = title }
        if !frontMatter.author.isBlank { fields["Author"] = frontMatter.author }
        if !frontMatter.subtitle.isBlank { fields["Subject"] = frontMatter.subtitle }
        return fields
    }
}
