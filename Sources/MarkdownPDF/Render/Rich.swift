//
//  Rich.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  Text with more than one face in it, wrapped and drawn.
//
//  The writer sets a run of text in one face. A paragraph of Markdown is
//  many: a bold phrase, a link, a word of code. So the words are laid out
//  here — measured one by one in the face each carries, wrapped into lines,
//  and drawn word by word — and everything that sets prose goes through it,
//  which is how a link in a table cell and a link in a paragraph come out
//  the same.
//

import Foundation
import TextPDF

/// How a word is set.
struct Style: Equatable {
    var bold = false
    var italic = false
    var code = false
    var strike = false
    var url: String?
}

/// A word, a space, or a forced break.
enum Piece: Equatable {
    case word(String, Style)
    case space(Style)
    case newline
}

/// A word on a line, with where it goes.
struct Placed {
    let text: String
    let style: Style
    /// From the line's left edge.
    let x: Double
    let width: Double
}

/// One line of a wrapped paragraph.
struct Line {
    var placed: [Placed] = []
    /// The natural width, spaces included.
    var width: Double = 0
    /// The spaces between words, for justification.
    var spaces = 0
    /// Ended by a hard break or the paragraph's end — never stretched.
    var last = false
}

enum Rich {

    /// The inlines as words and spaces, the marks folded into each word.
    static func pieces(_ inlines: Inlines, base: Style = Style()) -> [Piece] {
        var out: [Piece] = []
        for inline in inlines {
            switch inline {
            case .text(let text):
                out += split(text, base)
            case .emphasis(let inner):
                var style = base; style.italic = true
                out += pieces(inner, base: style)
            case .strong(let inner):
                var style = base; style.bold = true
                out += pieces(inner, base: style)
            case .strikethrough(let inner):
                var style = base; style.strike = true
                out += pieces(inner, base: style)
            case .link(let inner, let url):
                var style = base; style.url = url.isBlank ? nil : url
                out += pieces(inner, base: style)
            case .code(let code):
                var style = base; style.code = true
                // Code keeps its spaces: `a b` is one token to a reader.
                out.append(.word(code, style))
            case .image(_, let alt):
                out += split(alt, base)
            case .lineBreak:
                out.append(.newline)
            case .softBreak:
                out.append(.space(base))
            }
        }
        return out
    }

    private static func split(_ text: String, _ style: Style) -> [Piece] {
        var out: [Piece] = []
        var word = ""
        for character in text {
            if character == " " || character == "\t" || character == "\n" {
                if !word.isEmpty { out.append(.word(word, style)); word = "" }
                if case .space? = out.last { continue }
                out.append(.space(style))
            } else {
                word.append(character)
            }
        }
        if !word.isEmpty { out.append(.word(word, style)) }
        return out
    }
}

/// Measures and draws rich text in a document.
struct Setter {

    let pdf: TextPDF.Document
    let family: FontFamily
    let mono: FontFamily
    let palette: Palette
    let links: Blueprint.LinkStyle

    /// The face for a style at a weight.
    func face(_ style: Style, weight: Blueprint.Weight = .regular) -> EmbeddedFont? {
        if style.code {
            return mono.face(style.bold ? .bold : .regular)
        }
        var chosen = weight.family
        if style.bold { chosen = weight == .bold ? .bold : .bold }
        return family.face(chosen, italic: style.italic)
    }

    func width(_ text: String, _ style: Style, size: Double, weight: Blueprint.Weight, tracking: Double = 0) -> Double {
        let scaled = style.code ? size * 0.92 : size
        return pdf.width(of: text, size: scaled, face: face(style, weight: weight), tracking: tracking)
    }

    // MARK: Wrapping

    /// The pieces wrapped into lines of at most `width`.
    func layout(_ pieces: [Piece], width: Double, size: Double, weight: Blueprint.Weight = .regular, tracking: Double = 0) -> [Line] {
        var lines: [Line] = []
        var line = Line()
        var pendingSpace: (style: Style, width: Double)?

        func flush(last: Bool) {
            line.last = last
            lines.append(line)
            line = Line()
            pendingSpace = nil
        }

        for piece in pieces {
            switch piece {
            case .newline:
                flush(last: true)
            case .space(let style):
                guard !line.placed.isEmpty else { continue }
                pendingSpace = (style, self.width(" ", style, size: size, weight: weight, tracking: tracking))
            case .word(let text, let style):
                let wordWidth = self.width(text, style, size: size, weight: weight, tracking: tracking)
                let spaceWidth = pendingSpace?.width ?? 0
                if !line.placed.isEmpty, line.width + spaceWidth + wordWidth > width {
                    flush(last: false)
                }
                let x = line.placed.isEmpty ? 0 : line.width + (pendingSpace?.width ?? 0)
                if !line.placed.isEmpty, pendingSpace != nil { line.spaces += 1 }
                line.placed.append(Placed(text: text, style: style, x: x, width: wordWidth))
                line.width = x + wordWidth
                pendingSpace = nil
            }
        }
        if !line.placed.isEmpty || lines.isEmpty { flush(last: true) }
        return lines
    }

    // MARK: Drawing

    /// Draws one line with its top at `top`, and returns nothing: the
    /// caller owns the cursor.
    func draw(
        _ line: Line, x: Double, top: Double, width: Double, size: Double,
        weight: Blueprint.Weight = .regular, colour: Color, align: Align = .left,
        justified: Bool = false, tracking: Double = 0
    ) {
        let regular = family.face(weight.family)
        let ascent = regular?.ascender(size) ?? size * 0.78
        let descent = regular?.descender(size) ?? size * 0.22
        let baseline = top - ascent

        var offset: Double = 0
        var stretch: Double = 0
        if justified, !line.last, line.spaces > 0, line.width < width {
            stretch = (width - line.width) / Double(line.spaces)
        } else {
            switch align {
            case .center: offset = (width - line.width) / 2
            case .right: offset = width - line.width
            default: break
            }
        }

        var seen = 0
        var openLink: (url: String, from: Double, to: Double)?
        for (index, word) in line.placed.enumerated() {
            if index > 0 { seen += 1 }
            let wordX = x + offset + word.x + stretch * Double(seen)
            let scaled = word.style.code ? size * 0.92 : size
            let wordFace = face(word.style, weight: weight)

            if word.style.code {
                pdf.rect(x: wordX - 1.5, y: baseline - descent * 0.8, width: word.width + 3,
                         height: ascent + descent * 0.8, color: palette.wash)
            }

            let ink = word.style.url != nil ? (palette.colour(links.colour) ?? colour) : colour
            pdf.textAt(word.text, x: wordX, y: baseline, size: scaled, color: ink, face: wordFace, tracking: tracking)

            if word.style.strike {
                let mid = baseline + (wordFace?.xHeight(scaled) ?? scaled * 0.5) / 2
                pdf.line(from: wordX, mid, to: wordX + word.width, mid, color: ink, thickness: 0.7)
            }

            if let url = word.style.url {
                if var open = openLink, open.url == url {
                    open.to = wordX + word.width
                    openLink = open
                } else {
                    if let open = openLink { link(open, baseline: baseline, ascent: ascent, descent: descent) }
                    openLink = (url, wordX, wordX + word.width)
                }
            } else if let open = openLink {
                link(open, baseline: baseline, ascent: ascent, descent: descent)
                openLink = nil
            }
        }
        if let open = openLink { link(open, baseline: baseline, ascent: ascent, descent: descent) }
    }

    /// The link's rectangle over the whole span, and its underline under
    /// it — one line across the words rather than one per word.
    private func link(_ span: (url: String, from: Double, to: Double), baseline: Double, ascent: Double, descent: Double) {
        if links.underline {
            let ink = palette.colour(links.colour) ?? palette.ink
            pdf.line(from: span.from, baseline - 1.6, to: span.to, baseline - 1.6, color: ink, thickness: 0.5)
        }
        pdf.link(span.url, x: span.from, y: baseline - descent, width: span.to - span.from, height: ascent + descent)
    }

    /// The height of a heading's worth of lines.
    func height(of lines: [Line], leading: Double) -> Double {
        Double(lines.count) * leading
    }
}
