//
//  Strings.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension String {

    /// Whether there is nothing here but whitespace.
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The first letter up, the rest as written.
    var capitalised: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
