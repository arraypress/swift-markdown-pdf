//
//  ThemeRules.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Judgements a theme makes about itself, as pure functions with their
//  thresholds visible and pinned.
//

import Foundation
import TextPDF

enum ThemeRules {

    /// Whether an accent is near enough black that colour should not be
    /// spent on anything — a rule in "#111111" reads as a rule, and a
    /// heading in it as a heading, not as a brand.
    static func isMonochrome(accentHex: String) -> Bool {
        let colour = Color.hex(accentHex)
        return max(colour.red, colour.green, colour.blue) < 40
            && abs(colour.red - colour.green) < 12 && abs(colour.green - colour.blue) < 12
    }
}
