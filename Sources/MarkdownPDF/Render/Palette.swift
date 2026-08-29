//
//  Palette.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Colours by role, resolved from the theme once.
//

import Foundation
import TextPDF

/// The colours a theme gives the page.
struct Palette {

    let ink: Color
    let muted: Color
    let accent: Color
    let wash: Color
    let hairline: Color
    let paper: Color

    init(theme: Theme) {
        ink = Color.hex("#141414")
        muted = Color.grey(108)
        hairline = Color.grey(205)
        paper = Color.grey(255)
        if theme.isMonochrome {
            accent = ink
            wash = Color.grey(243)
        } else {
            accent = theme.accentColor
            wash = Palette.mix(theme.accentColor, into: Color.grey(255), amount: 0.09)
        }
    }

    /// A paint's colour on this page, or nil for none.
    func colour(_ paint: Blueprint.Paint) -> Color? {
        switch paint {
        case .ink: return ink
        case .muted: return muted
        case .accent: return accent
        case .wash: return wash
        case .hairline: return hairline
        case .none: return nil
        }
    }

    /// The text colour that reads on a fill. An accent fill is a dark one
    /// even under a monochrome theme — it is black then — so it takes
    /// paper.
    func text(on fill: Blueprint.Paint) -> Color {
        fill == .accent ? paper : ink
    }

    /// `amount` of one colour laid over another.
    static func mix(_ colour: Color, into base: Color, amount: Double) -> Color {
        func channel(_ a: Int, _ b: Int) -> Int { Int((Double(b) + (Double(a) - Double(b)) * amount).rounded()) }
        return Color(red: channel(colour.red, base.red), green: channel(colour.green, base.green), blue: channel(colour.blue, base.blue))
    }
}
