//
//  Theme+Rendering.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  What this library draws from a theme: the accent as a colour, whether it
//  is near enough black to spend no colour at all, and what a density does
//  to the rhythm and the margins.
//

import DocumentTheme
import TextPDF

extension Theme {

    /// Whether the accent is near enough black that colour should not be
    /// spent on anything — a rule in "#111111" reads as a rule, and a
    /// heading in it as a heading, not as a brand.
    var isMonochrome: Bool { ThemeRules.isMonochrome(accentHex: accent) }

    var accentColor: Color { Color.hex(accent) }
}

extension Density {

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
