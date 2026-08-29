//
//  Typesetter.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The interpreter: a manuscript, set in a design, on a theme.
//
//  A design says what a heading looks like; this is what draws one. Each
//  block kind has one method, every method takes the column it is given —
//  the page, a list item's indent, a quote's inset — so nesting is the same
//  code as the top level, and a page break inside any of them is handled by
//  the writer's cursor rather than by each block guessing.
//

import Foundation
import TextPDF

/// Sets a manuscript into a document.
final class Typesetter {

    let manuscript: Manuscript
    let design: Blueprint
    let theme: Theme
    let pdf: TextPDF.Document
    let setter: Setter
    let palette: Palette

    /// The body size and line height, after the theme's density.
    let body: Double
    let leading: Double

    /// Section numbers, counted through the document.
    private var numbers: [Int] = []

    /// The shallowest heading in the body — numbering starts there, so a
    /// document whose `#` is its title numbers its `##` sections 1, 2, 3.
    private lazy var shallowest: Int = manuscript.body.compactMap {
        if case .heading(let level, _) = $0 { return level }
        return nil
    }.min() ?? 1

    init(_ manuscript: Manuscript, design: Blueprint, theme: Theme) throws {
        self.manuscript = manuscript
        self.design = design
        self.theme = theme
        body = design.scale.body
        leading = (design.scale.body * design.scale.leading * theme.density.leading).rounded(toPlaces: 2)
        palette = Palette(theme: theme)

        pdf = TextPDF.Document(
            size: theme.pageSize,
            margin: (design.page.margin * theme.density.margin).rounded(),
            fontSize: body,
            leading: leading
        )
        let family = try Typography.family(theme.typeface ?? design.intendedTypeface)
        let mono = try Typography.mono()
        setter = Setter(pdf: pdf, family: family, mono: mono, palette: palette, links: design.links)
    }

    // MARK: The document

    func run() -> TextPDF.Document {
        running()
        titleBlock()
        // A design that draws no title block leaves the opening heading
        // where it is: it is the only place the title would appear.
        let content = design.title.style == .none ? manuscript.blocks : manuscript.body
        blocks(content, x: pdf.left(), width: pdf.contentWidth(), context: Context())
        return pdf
    }

    /// What every method needs to know about where it is drawing.
    struct Context {
        var style = Style()
        var colour: Blueprint.Paint = .ink
        /// Inside a list: paragraphs sit closer together.
        var tight = false
        /// Drawn beside each line — a quote's bar.
        var beside: ((_ top: Double, _ height: Double) -> Void)?
    }

    func blocks(_ blocks: [Block], x: Double, width: Double, context: Context) {
        for (index, block) in blocks.enumerated() {
            let isLast = index == blocks.count - 1
            switch block {
            case .heading(let level, let inlines):
                heading(level, inlines, x: x, width: width, atTop: index == 0)
            case .paragraph(let inlines):
                paragraph(inlines, x: x, width: width, context: context)
                if !isLast { space(context.tight ? body * 0.35 : body * design.scale.paragraphGap, context: context) }
            case .list(let list):
                self.list(list, x: x, width: width, context: context)
                if !isLast { space(context.tight ? body * 0.35 : body * design.scale.paragraphGap, context: context) }
            case .code(let language, let code):
                self.code(code, language: language, x: x, width: width)
                if !isLast { space(body * design.scale.blockGap, context: context) }
            case .quote(let inner):
                quote(inner, x: x, width: width, context: context)
                if !isLast { space(body * design.scale.blockGap, context: context) }
            case .table(let table):
                self.table(table, x: x, width: width)
                if !isLast { space(body * design.scale.blockGap, context: context) }
            case .rule:
                rule(x: x, width: width)
            case .image(let source, let alt):
                figure(source, alt: alt, x: x, width: width)
                if !isLast { space(body * design.scale.blockGap, context: context) }
            case .html:
                // Nothing here draws HTML; the check says so.
                break
            }
        }
    }

    private func space(_ points: Double, context: Context) {
        guard pdf.remaining() > points else { return }
        context.beside?(pdf.cursor(), points)
        pdf.gap(points)
    }

    // MARK: Paragraphs

    func paragraph(_ inlines: Inlines, x: Double, width: Double, context: Context, size: Double? = nil,
                   align: Align = .left) {
        let size = size ?? body
        let lines = setter.layout(Rich.pieces(inlines, base: context.style), width: width, size: size)
        let colour = palette.colour(context.colour) ?? palette.ink
        let step = size == body ? leading : (size * design.scale.leading * theme.density.leading)

        // A lone first line at the foot of a page, or a lone last line at
        // the head of one, is the thing typesetters have a word for.
        if lines.count > 1, pdf.remaining() < step * 2 { pdf.pageBreak() }

        for line in lines {
            pdf.breakIfNeeded(step)
            context.beside?(pdf.cursor(), step)
            setter.draw(line, x: x, top: pdf.cursor(), width: width, size: size, colour: colour,
                        align: align, justified: theme.justified && align == .left)
            pdf.gap(step)
        }
    }

    // MARK: Headings

    func heading(_ level: Int, _ inlines: Inlines, x: Double, width: Double, atTop: Bool) {
        let style = design.heading(level)
        let step = style.size * 1.25
        var text = inlines
        if style.numbered { text = [.text(number(for: level) + "  ")] + text }
        if style.uppercase { text = uppercased(text) }

        let lines = setter.layout(Rich.pieces(text), width: width, size: style.size, weight: style.weight,
                                  tracking: style.tracking)
        let before = atTop ? 0 : body * style.before
        let after = body * style.after
        let needed = before + setter.height(of: lines, leading: step) + after + leading * 2

        // A heading is kept with what follows it, or it is a heading of
        // nothing.
        if pdf.remaining() < needed, pdf.remaining() < pdf.height() - pdf.margin * 2 - 1 {
            pdf.pageBreak()
        } else {
            pdf.gap(before)
        }

        if level <= 2 { pdf.bookmark(inlines.plain) }

        let colour = palette.colour(style.colour) ?? palette.ink
        for line in lines {
            setter.draw(line, x: x, top: pdf.cursor(), width: width, size: style.size, weight: style.weight,
                        colour: colour, tracking: style.tracking)
            pdf.gap(step)
        }
        if style.rule {
            pdf.gap(2)
            pdf.line(from: x, pdf.cursor(), to: x + width, pdf.cursor(), color: palette.hairline, thickness: 0.6)
            pdf.gap(3)
        }
        pdf.gap(after)
    }

    private func number(for level: Int) -> String {
        let depth = max(level - shallowest + 1, 1)
        while numbers.count < depth { numbers.append(0) }
        numbers = Array(numbers.prefix(depth))
        numbers[depth - 1] += 1
        return numbers.map(String.init).joined(separator: ".")
    }

    private func uppercased(_ inlines: Inlines) -> Inlines {
        inlines.map {
            switch $0 {
            case .text(let text): return .text(text.uppercased())
            case .emphasis(let inner): return .emphasis(uppercased(inner))
            case .strong(let inner): return .strong(uppercased(inner))
            case .strikethrough(let inner): return .strikethrough(uppercased(inner))
            case .link(let inner, let url): return .link(uppercased(inner), url: url)
            default: return $0
            }
        }
    }

    // MARK: Lists

    func list(_ list: List, x: Double, width: Double, context: Context) {
        let indent = design.lists.indent
        var inner = context
        inner.tight = true

        for (index, item) in list.items.enumerated() {
            // The marker and the first line go together.
            pdf.breakIfNeeded(leading)
            let top = pdf.cursor()
            marker(for: list, index: index, item: item, x: x, top: top, context: context)
            blocks(item.blocks, x: x + indent, width: width - indent, context: inner)
            if index < list.items.count - 1 { space(body * 0.3, context: context) }
        }
    }

    private func marker(for list: List, index: Int, item: List.Item, x: Double, top: Double, context: Context) {
        let regular = setter.family.face(.regular)
        let baseline = top - (regular?.ascender(body) ?? body * 0.78)
        let colour = palette.colour(design.lists.colour) ?? palette.ink
        let indent = design.lists.indent

        if let checked = item.checked {
            let side = body * 0.78
            let boxY = baseline - side * 0.1
            let boxX = x + 1
            let ink = palette.muted
            pdf.line(from: boxX, boxY, to: boxX + side, boxY, color: ink, thickness: 0.7)
            pdf.line(from: boxX, boxY + side, to: boxX + side, boxY + side, color: ink, thickness: 0.7)
            pdf.line(from: boxX, boxY, to: boxX, boxY + side, color: ink, thickness: 0.7)
            pdf.line(from: boxX + side, boxY, to: boxX + side, boxY + side, color: ink, thickness: 0.7)
            if checked {
                pdf.rect(x: boxX + 2, y: boxY + 2, width: side - 4, height: side - 4, color: palette.accent)
            }
            return
        }

        if list.ordered {
            let label = "\(list.start + index)."
            pdf.textAt(label, x: x, y: baseline, size: body, color: colour, align: .right,
                       boxWidth: indent - 5, face: setter.family.face(.medium))
        } else {
            let glyph = design.lists.bullet
            let face = setter.family.face(.regular)
            let glyphWidth = pdf.width(of: glyph, size: body, face: face)
            pdf.textAt(glyph, x: x + (indent - 6 - glyphWidth) / 2, y: baseline, size: body, color: colour, face: face)
        }
    }

    // MARK: Code

    func code(_ code: String, language: String?, x: Double, width: Double) {
        let size = design.code.size
        let step = size * 1.42
        let pad: Double = 7
        let face = setter.mono.face(.regular)
        let fill = palette.colour(design.code.fill)
        let border = design.code.border ? palette.hairline : nil

        var lines: [String] = []
        for raw in code.components(separatedBy: "\n") {
            lines += wrapCode(raw.replacingOccurrences(of: "\t", with: "    "), width: width - pad * 2, size: size, face: face)
        }

        pdf.breakIfNeeded(step * min(Double(lines.count), 3) + pad * 2)

        func band(_ height: Double) {
            let top = pdf.cursor()
            if let fill { pdf.rect(x: x, y: top - height, width: width, height: height, color: fill) }
            if let border {
                pdf.line(from: x, top, to: x, top - height, color: border, thickness: 0.5)
                pdf.line(from: x + width, top, to: x + width, top - height, color: border, thickness: 0.5)
            }
        }

        // The fence's language sits in a slightly deeper top band, out of
        // the way of the first line.
        let labelled = design.code.label && !(language ?? "").isBlank
        let top = pad + (labelled ? 8 : 0)
        if let border { pdf.line(from: x, pdf.cursor(), to: x + width, pdf.cursor(), color: border, thickness: 0.5) }
        band(top)
        if labelled, let language {
            pdf.textAt(language, x: x, y: pdf.cursor() - 9.5, size: 7, color: palette.muted,
                       align: .right, boxWidth: width - pad, face: setter.family.face(.medium))
        }
        pdf.gap(top)

        for line in lines {
            if pdf.breakIfNeeded(step) { band(pad); pdf.gap(pad) }
            band(step)
            let baseline = pdf.cursor() - (face?.ascender(size) ?? size * 0.78) - (step - size) / 2
            pdf.textAt(line, x: x + pad, y: baseline, size: size, color: palette.ink, face: face)
            pdf.gap(step)
        }
        band(pad)
        pdf.gap(pad)
        if let border { pdf.line(from: x, pdf.cursor(), to: x + width, pdf.cursor(), color: border, thickness: 0.5) }
    }

    /// Code wraps by character, never by word: a line of code has no words.
    private func wrapCode(_ line: String, width: Double, size: Double, face: EmbeddedFont?) -> [String] {
        guard pdf.width(of: line, size: size, face: face) > width, !line.isEmpty else { return [line] }
        var out: [String] = []
        var current = ""
        for character in line {
            let candidate = current + String(character)
            if pdf.width(of: candidate, size: size, face: face) > width, !current.isEmpty {
                out.append(current)
                current = String(character)
            } else {
                current = candidate
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    // MARK: Quotes

    func quote(_ inner: [Block], x: Double, width: Double, context: Context) {
        var quoted = context
        quoted.style.italic = design.quote.italic || context.style.italic
        quoted.colour = design.quote.colour
        let bar = palette.colour(design.quote.bar)
        quoted.beside = { top, height in
            context.beside?(top, height)
            if let bar { self.pdf.rect(x: x, y: top - height, width: 2.2, height: height, color: bar) }
        }
        blocks(inner, x: x + design.quote.inset, width: width - design.quote.inset, context: quoted)
    }

    // MARK: Rules and figures

    func rule(x: Double, width: Double) {
        pdf.breakIfNeeded(body)
        pdf.gap(body * 0.4)
        pdf.line(from: x, pdf.cursor(), to: x + width, pdf.cursor(), color: palette.hairline, thickness: 0.6)
        pdf.gap(body * 0.4)
    }

    func figure(_ source: String, alt: String, x: Double, width: Double) {
        let url = manuscript.resolve(source)
        guard let picture = try? EmbeddedImage.load(url) else {
            // A box where the picture would be, so the gap is visible and
            // named rather than silent.
            let height = body * 3.2
            pdf.breakIfNeeded(height)
            let top = pdf.cursor()
            pdf.rect(x: x, y: top - height, width: width, height: height, color: palette.wash)
            let note = alt.isBlank ? "Missing image: \(source)" : "\(alt) — missing image: \(source)"
            pdf.textAt(note, x: x + width / 2, y: top - height / 2 - body * 0.35, size: body * 0.85,
                       color: palette.muted, align: .center, boxWidth: 0, face: setter.family.face(.regular, italic: true))
            pdf.gap(height)
            return
        }

        // Natural size at 96 dpi, capped to the column and to most of a page.
        var drawWidth = min(width, Double(picture.width) * 0.75)
        var drawHeight = drawWidth / picture.aspectRatio
        let tallest = (pdf.height() - pdf.margin * 2) * 0.8
        if drawHeight > tallest {
            drawHeight = tallest
            drawWidth = drawHeight * picture.aspectRatio
        }
        let caption = alt.isBlank ? 0 : leading
        pdf.breakIfNeeded(drawHeight + caption + 4)

        let left = x + (width - drawWidth) / 2
        pdf.image(picture, x: left, y: pdf.cursor() - drawHeight, width: drawWidth, height: drawHeight)
        pdf.gap(drawHeight)
        if !alt.isBlank {
            pdf.gap(4)
            pdf.textAt(alt, x: x, y: pdf.cursor() - body * 0.78, size: body * 0.85, color: palette.muted,
                       align: .center, boxWidth: width, face: setter.family.face(.regular, italic: true))
            pdf.gap(caption)
        }
    }

    // MARK: The title block

    func titleBlock() {
        let block = design.title
        guard block.style != .none else { return }
        let matter = manuscript.frontMatter
        let title = manuscript.title
        let x = pdf.left(), width = pdf.contentWidth()
        var logoWidth: Double = 0

        if block.logo, let path = theme.logo, !path.isBlank,
           let picture = try? EmbeddedImage.load(manuscript.resolve(path)) {
            let height: Double = 30
            logoWidth = height * picture.aspectRatio
            pdf.image(picture, x: x + width - logoWidth, y: pdf.cursor() - height, width: logoWidth, height: height)
            if block.style == .centred || block.style == .band { pdf.gap(height + body); logoWidth = 0 }
        }

        switch block.style {
        case .band:
            let height = block.size * 2.1
            pdf.rect(x: x, y: pdf.cursor() - height, width: width, height: height, color: palette.accent)
            let face = setter.family.face(block.weight.family)
            let text = block.uppercase ? title.uppercased() : title
            let fitted = pdf.fit(text, into: width - 32, size: block.size, face: face)
            pdf.textAt(fitted, x: x + 16, y: pdf.cursor() - height / 2 - block.size * 0.36, size: block.size,
                       color: palette.text(on: .accent), face: face, tracking: block.tracking)
            pdf.gap(height + body * 0.9)
            byline(block, x: x, width: width, align: .left)

        case .memo:
            let word = title.isBlank ? "Memorandum" : title
            let text = block.uppercase ? word.uppercased() : word
            let face = setter.family.face(block.weight.family)
            pdf.textAt(text, x: x, y: pdf.cursor() - block.size * 0.78, size: block.size, color: palette.ink,
                       face: face, tracking: block.tracking)
            pdf.gap(block.size * 1.15 + body * 0.6)
            memoFields(block.fields, x: x, width: width)

        case .plain, .centred:
            let centred = block.style == .centred
            let text = block.uppercase ? title.uppercased() : title
            if !text.isBlank {
                let lines = setter.layout(Rich.pieces([.text(text)]), width: width - logoWidth - (logoWidth > 0 ? 12 : 0),
                                          size: block.size, weight: block.weight, tracking: block.tracking)
                for line in lines {
                    setter.draw(line, x: x, top: pdf.cursor(), width: width - logoWidth, size: block.size,
                                weight: block.weight, colour: palette.ink, align: centred ? .center : .left,
                                tracking: block.tracking)
                    pdf.gap(block.size * 1.2)
                }
            }
            byline(block, x: x, width: width, align: centred ? .center : .left)

        case .none:
            break
        }

        if block.rule {
            pdf.gap(body * 0.7)
            pdf.line(from: x, pdf.cursor(), to: x + width, pdf.cursor(), color: palette.hairline, thickness: 0.7)
        }
        pdf.gap(body * block.gap)
        _ = matter
    }

    private func byline(_ block: Blueprint.TitleBlock, x: Double, width: Double, align: Align) {
        guard block.byline else { return }
        let matter = manuscript.frontMatter
        if !matter.subtitle.isBlank {
            let size = body * 1.25
            let lines = setter.layout(Rich.pieces([.text(matter.subtitle)]), width: width, size: size)
            for line in lines {
                setter.draw(line, x: x, top: pdf.cursor(), width: width, size: size, colour: palette.muted, align: align)
                pdf.gap(size * 1.35)
            }
        }
        let who = [matter.author, matter.date].filter { !$0.isBlank }.joined(separator: "  ·  ")
        if !who.isBlank {
            pdf.gap(body * 0.25)
            pdf.textAt(who, x: x, y: pdf.cursor() - body * 0.78, size: body * 0.95, color: palette.muted,
                       align: align, boxWidth: width, face: setter.family.face(.regular))
            pdf.gap(body * 1.3)
        }
    }

    private func memoFields(_ keys: [String], x: Double, width: Double) {
        let matter = manuscript.frontMatter
        let present = keys.compactMap { key -> (String, String)? in
            guard let value = matter[key], !value.isBlank else { return nil }
            return (key, value)
        }
        guard !present.isEmpty else { return }
        let labelWidth: Double = 64
        let size = body
        let step = leading
        for (key, value) in present {
            let label = key.uppercased()
            pdf.textAt(label, x: x, y: pdf.cursor() - size * 0.78, size: size * 0.8, color: palette.muted,
                       face: setter.family.face(.semibold), tracking: 0.8)
            let lines = setter.layout(Rich.pieces([.text(value)]), width: width - labelWidth, size: size)
            for line in lines {
                setter.draw(line, x: x + labelWidth, top: pdf.cursor(), width: width - labelWidth, size: size, colour: palette.ink)
                pdf.gap(step)
            }
        }
    }

    // MARK: Running header and footer

    func running() {
        let header = design.header, footer = design.footer
        guard !header.isEmpty || !footer.isEmpty else { return }

        let matter = manuscript.frontMatter
        let title = manuscript.title
        let face = setter.family.face(.regular)
        let size = body * 0.8
        let inset = design.page.runningInset
        let muted = palette.muted, hairline = palette.hairline

        func text(_ token: Blueprint.Running.Token, page: Int, total: Int) -> String {
            switch token {
            case .none: return ""
            case .title: return title
            case .subtitle: return matter.subtitle
            case .author: return matter.author
            case .date: return matter.date
            case .page: return "Page \(page) of \(total)"
            case .number: return "\(page)"
            }
        }

        pdf.onEachPage { doc, page, total in
            let left = doc.left(), right = doc.right(), width = doc.contentWidth()
            if !header.isEmpty, page > 1 || header.firstPage {
                let y = doc.height() - doc.margin + inset
                let baseline = y - size * 0.78
                let l = text(header.left, page: page, total: total)
                let c = text(header.centre, page: page, total: total)
                let r = text(header.right, page: page, total: total)
                if !l.isEmpty { doc.textAt(doc.fit(l, into: width * 0.6, size: size, face: face), x: left, y: baseline, size: size, color: muted, face: face) }
                if !c.isEmpty { doc.textAt(c, x: left, y: baseline, size: size, color: muted, align: .center, boxWidth: width, face: face) }
                if !r.isEmpty { doc.textAt(doc.fit(r, into: width * 0.6, size: size, face: face), x: left, y: baseline, size: size, color: muted, align: .right, boxWidth: width, face: face) }
                if header.rule { doc.line(from: left, y - size * 1.45, to: right, y - size * 1.45, color: hairline, thickness: 0.5) }
            }
            if !footer.isEmpty, page > 1 || footer.firstPage {
                let y = doc.margin - inset
                let baseline = y - size * 0.78
                let l = text(footer.left, page: page, total: total)
                let c = text(footer.centre, page: page, total: total)
                let r = text(footer.right, page: page, total: total)
                if footer.rule { doc.line(from: left, y + size * 0.6, to: right, y + size * 0.6, color: hairline, thickness: 0.5) }
                if !l.isEmpty { doc.textAt(doc.fit(l, into: width * 0.6, size: size, face: face), x: left, y: baseline, size: size, color: muted, face: face) }
                if !c.isEmpty { doc.textAt(c, x: left, y: baseline, size: size, color: muted, align: .center, boxWidth: width, face: face) }
                if !r.isEmpty { doc.textAt(doc.fit(r, into: width * 0.6, size: size, face: face), x: left, y: baseline, size: size, color: muted, align: .right, boxWidth: width, face: face) }
            }
        }
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
