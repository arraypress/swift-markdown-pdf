//
//  FrontMatter+Reading.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The model's way in, delegated: the parsing rules live in
//  FrontMatterParsing, this keeps the call site.
//

import Foundation

extension FrontMatter {

    /// Splits the front matter off the top of a file.
    ///
    /// The fences must be the first line and a later line of exactly `---`;
    /// a `---` in the body is a thematic break, not a fence. Anything that
    /// is not `key: value` between them is ignored rather than refused: a
    /// stray line in the front matter should not cost the document.
    static func split(_ source: String) -> (matter: FrontMatter, body: String) {
        FrontMatterParsing.split(source)
    }
}
