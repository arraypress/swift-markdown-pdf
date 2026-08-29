//
//  Tables.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  A GFM table, drawn.
//
//  Drawn here rather than by the writer's own table, because a cell can
//  carry a link or a bold word and can wrap — the writer's table takes
//  plain strings on one line. Columns take their natural width when it
//  fits and share the page when it does not; a row that does not fit the
//  page goes to the next with the header row drawn again.
//

import Foundation
import TextPDF

extension Typesetter {

    func table(_ table: Table, x: Double, width: Double) {
        let style = design.table
        let size = style.size
        let step = size * 1.4
        let pad: Double = 5
        let columns = table.columnCount
        guard columns > 0 else { return }

        // Natural widths: the widest cell in each column, unwrapped — with
        // half a point of slack, so a cell measured to exactly its column
        // never wraps on a rounding error.
        var natural = [Double](repeating: 0, count: columns)
        for (index, cell) in table.header.enumerated() {
            natural[index] = max(natural[index], cellWidth(cell, size: size, weight: .semibold) + pad * 2)
        }
        for row in table.rows {
            for (index, cell) in row.prefix(columns).enumerated() {
                natural[index] = max(natural[index], cellWidth(cell, size: size, weight: .regular) + pad * 2)
            }
        }
        let widths = fit(natural.map { $0 + 0.5 }, into: width, minimum: 44)
        let total = widths.reduce(0, +)

        func draw(_ cells: [Inlines], header: Bool, stripe: Bool) {
            let weight: Blueprint.Weight = header ? .semibold : .regular
            let laid = (0..<columns).map { index -> [Line] in
                let cell = index < cells.count ? cells[index] : []
                return setter.layout(Rich.pieces(cell), width: widths[index] - pad * 2, size: size, weight: weight)
            }
            let tallest = laid.map(\.count).max() ?? 1
            let height = Double(max(tallest, 1)) * step + pad * 2

            if pdf.breakIfNeeded(height), !header, !table.header.isEmpty {
                draw(table.header, header: true, stripe: false)
            }
            let top = pdf.cursor()
            if header, let fill = palette.colour(style.headerFill) {
                pdf.rect(x: x, y: top - height, width: total, height: height, color: fill)
            } else if stripe {
                pdf.rect(x: x, y: top - height, width: total, height: height, color: palette.wash)
            }
            let colour = header ? palette.text(on: style.headerFill) : palette.ink

            var cellX = x
            for index in 0..<columns {
                let align: Align
                switch index < table.alignments.count ? table.alignments[index] : nil {
                case .centre?: align = .center
                case .right?: align = .right
                default: align = .left
                }
                var lineTop = top - pad
                for line in laid[index] {
                    setter.draw(line, x: cellX + pad, top: lineTop, width: widths[index] - pad * 2, size: size,
                                weight: weight, colour: colour, align: align)
                    lineTop -= step
                }
                cellX += widths[index]
            }
            if style.rules {
                pdf.line(from: x, top - height, to: x + total, top - height, color: palette.hairline, thickness: 0.5)
            }
            pdf.move(to: top - height)
        }

        pdf.breakIfNeeded(step * 3 + pad * 4)
        if style.rules, !table.header.isEmpty {
            pdf.line(from: x, pdf.cursor(), to: x + total, pdf.cursor(), color: palette.hairline, thickness: 0.5)
        }
        if !table.header.isEmpty { draw(table.header, header: true, stripe: false) }
        for (index, row) in table.rows.enumerated() {
            draw(row, header: false, stripe: style.striped && index % 2 == 1)
        }
    }

    private func cellWidth(_ cell: Inlines, size: Double, weight: Blueprint.Weight) -> Double {
        var total: Double = 0
        for piece in Rich.pieces(cell) {
            switch piece {
            case .word(let text, let style): total += setter.width(text, style, size: size, weight: weight)
            case .space(let style): total += setter.width(" ", style, size: size, weight: weight)
            case .newline: break
            }
        }
        return total
    }

    /// Column widths that fit the page: natural when there is room, shared
    /// in proportion when there is not — never narrower than a word.
    private func fit(_ natural: [Double], into width: Double, minimum: Double) -> [Double] {
        let sum = natural.reduce(0, +)
        guard sum > width else {
            // Narrow tables stay narrow; wide ones take the measure.
            return sum > width * 0.6 ? natural.map { $0 / sum * width } : natural
        }
        var widths = natural.map { max(minimum, $0 / sum * width) }
        // Clamping to the minimum can overflow; take it back from the widest.
        var excess = widths.reduce(0, +) - width
        while excess > 0.5, let widest = widths.indices.max(by: { widths[$0] < widths[$1] }), widths[widest] > minimum {
            let cut = min(excess, widths[widest] - minimum)
            widths[widest] -= cut
            excess -= cut
        }
        return widths
    }
}
