//
//  Blueprint.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  A design as data.
//
//  Every design the package carries is a JSON file in its resources, and this
//  is the shape of that file: the page, the scale, the title block, how each
//  level of heading is set, what code, quotes, tables and lists look like,
//  and what runs along the top and bottom of every page. The Swift under
//  `Render/` is the interpreter those choices are drawn by; a design of your
//  own is a copy of one of these files with the choices changed.
//

import Foundation
import TextPDF

/// A design, written as data.
public struct Blueprint: Codable, Equatable, Sendable {

    /// What it is called — `report`, or the name of your own.
    public var name: String

    /// One line on what it is for.
    public var description: String

    /// The face the design was drawn for, used when the theme names none.
    public var typeface: Face

    public var page: Page
    public var scale: Scale
    public var title: TitleBlock

    /// By level, `#` first. A deeper heading than the list covers takes
    /// the last style.
    public var headings: [HeadingStyle]

    public var code: CodeStyle
    public var quote: QuoteStyle
    public var table: TableStyle
    public var lists: ListStyle
    public var links: LinkStyle
    public var header: Running
    public var footer: Running

    public init(
        name: String, description: String = "", typeface: Face = .sans,
        page: Page = Page(), scale: Scale = Scale(), title: TitleBlock = TitleBlock(),
        headings: [HeadingStyle] = HeadingStyle.defaults,
        code: CodeStyle = CodeStyle(), quote: QuoteStyle = QuoteStyle(),
        table: TableStyle = TableStyle(), lists: ListStyle = ListStyle(),
        links: LinkStyle = LinkStyle(), header: Running = Running(), footer: Running = Running(centre: .page)
    ) {
        self.name = name
        self.description = description
        self.typeface = typeface
        self.page = page
        self.scale = scale
        self.title = title
        self.headings = headings.isEmpty ? HeadingStyle.defaults : headings
        self.code = code
        self.quote = quote
        self.table = table
        self.lists = lists
        self.links = links
        self.header = header
        self.footer = footer
    }

    /// The name as a person reads it.
    public var displayName: String { name.capitalised }

    /// The typeface the design was drawn for.
    public var intendedTypeface: Typeface {
        typeface == .serif ? .sourceSerif : .inter
    }

    /// The style for a heading level, the deepest listed standing in for
    /// anything deeper.
    func heading(_ level: Int) -> HeadingStyle {
        headings[min(max(level, 1), headings.count) - 1]
    }

    // MARK: The parts

    /// A bundled family, by the shape of its letters.
    public enum Face: String, Codable, CaseIterable, Sendable {
        case sans, serif
    }

    /// The page's geometry, in points.
    public struct Page: Codable, Equatable, Sendable {

        /// All four margins. The theme's density scales it.
        public var margin: Double

        /// How far outside the margin the running header and footer sit.
        public var runningInset: Double

        public init(margin: Double = 58, runningInset: Double = 26) {
            self.margin = margin
            self.runningInset = runningInset
        }
    }

    /// The type scale: the body size, and everything relative to it.
    public struct Scale: Codable, Equatable, Sendable {

        /// Body text, in points.
        public var body: Double

        /// Line height as a multiple of the body size.
        public var leading: Double

        /// Space after a paragraph, as a multiple of the body size.
        public var paragraphGap: Double

        /// Space around a block — a table, a code block, a figure — as a
        /// multiple of the body size.
        public var blockGap: Double

        public init(body: Double = 10.5, leading: Double = 1.45, paragraphGap: Double = 0.75, blockGap: Double = 1.0) {
            self.body = body
            self.leading = leading
            self.paragraphGap = paragraphGap
            self.blockGap = blockGap
        }
    }

    /// What the top of the first page says.
    public struct TitleBlock: Codable, Equatable, Sendable {

        public enum Style: String, Codable, CaseIterable, Sendable {
            /// The title large, subtitle and byline under it.
            case plain
            /// The same, centred.
            case centred
            /// The title reversed out of an accent band.
            case band
            /// A memo head: the word, then To / From / Date / Re from
            /// the front matter.
            case memo
            /// Nothing — the document starts with its own first heading.
            case none
        }

        public var style: Style

        /// Title size in points.
        public var size: Double

        public var weight: Weight
        public var uppercase: Bool
        public var tracking: Double

        /// Whether the subtitle, author and date are set under the title.
        public var byline: Bool

        /// A rule under the block.
        public var rule: Bool

        /// Whether the theme's logo, if it has one, is drawn beside the title.
        public var logo: Bool

        /// The front-matter keys a memo head lists, in order, as labels.
        public var fields: [String]

        /// Space below the block, as a multiple of the body size.
        public var gap: Double

        public init(
            style: Style = .plain, size: Double = 26, weight: Weight = .bold, uppercase: Bool = false,
            tracking: Double = 0, byline: Bool = true, rule: Bool = true, logo: Bool = true,
            fields: [String] = ["to", "from", "date", "re"], gap: Double = 2.0
        ) {
            self.style = style
            self.size = size
            self.weight = weight
            self.uppercase = uppercase
            self.tracking = tracking
            self.byline = byline
            self.rule = rule
            self.logo = logo
            self.fields = fields
            self.gap = gap
        }
    }

    /// How a level of heading is set.
    public struct HeadingStyle: Codable, Equatable, Sendable {

        public var size: Double
        public var weight: Weight
        public var colour: Paint
        public var uppercase: Bool
        public var tracking: Double

        /// A rule under the heading.
        public var rule: Bool

        /// Space above and below, as multiples of the body size.
        public var before: Double
        public var after: Double

        /// `1.2` before the text, counted through the document.
        public var numbered: Bool

        public init(
            size: Double, weight: Weight = .bold, colour: Paint = .ink, uppercase: Bool = false,
            tracking: Double = 0, rule: Bool = false, before: Double = 1.6, after: Double = 0.5,
            numbered: Bool = false
        ) {
            self.size = size
            self.weight = weight
            self.colour = colour
            self.uppercase = uppercase
            self.tracking = tracking
            self.rule = rule
            self.before = before
            self.after = after
            self.numbered = numbered
        }

        /// Three levels, plainly.
        public static let defaults: [HeadingStyle] = [
            HeadingStyle(size: 18, rule: true, before: 1.8, after: 0.6),
            HeadingStyle(size: 14, before: 1.5, after: 0.45),
            HeadingStyle(size: 11.5, weight: .semibold, before: 1.2, after: 0.35),
        ]
    }

    public struct CodeStyle: Codable, Equatable, Sendable {

        /// Behind the block, and behind inline code.
        public var fill: Paint

        /// A hairline round the block.
        public var border: Bool

        /// Size in points, for the block. Inline code follows the text.
        public var size: Double

        /// Whether the fence's language is set small at the block's corner.
        public var label: Bool

        public init(fill: Paint = .wash, border: Bool = false, size: Double = 8.8, label: Bool = true) {
            self.fill = fill
            self.border = border
            self.size = size
            self.label = label
        }
    }

    public struct QuoteStyle: Codable, Equatable, Sendable {

        /// The bar down the left: the accent, a hairline, or none.
        public var bar: Paint

        public var italic: Bool

        /// The text colour.
        public var colour: Paint

        /// How far the quote is set in, in points.
        public var inset: Double

        public init(bar: Paint = .accent, italic: Bool = false, colour: Paint = .muted, inset: Double = 14) {
            self.bar = bar
            self.italic = italic
            self.colour = colour
            self.inset = inset
        }
    }

    public struct TableStyle: Codable, Equatable, Sendable {

        /// Behind the header row.
        public var headerFill: Paint

        /// Alternate rows tinted.
        public var striped: Bool

        /// Hairlines between rows.
        public var rules: Bool

        /// Size in points.
        public var size: Double

        public init(headerFill: Paint = .wash, striped: Bool = false, rules: Bool = true, size: Double = 9.5) {
            self.headerFill = headerFill
            self.striped = striped
            self.rules = rules
            self.size = size
        }
    }

    public struct ListStyle: Codable, Equatable, Sendable {

        /// The bullet, as the character drawn.
        public var bullet: String

        /// The bullet's colour.
        public var colour: Paint

        /// How far an item's text sits in from the list's edge, in points.
        public var indent: Double

        public init(bullet: String = "•", colour: Paint = .ink, indent: Double = 16) {
            self.bullet = bullet
            self.colour = colour
            self.indent = indent
        }
    }

    public struct LinkStyle: Codable, Equatable, Sendable {

        public var colour: Paint
        public var underline: Bool

        public init(colour: Paint = .accent, underline: Bool = false) {
            self.colour = colour
            self.underline = underline
        }
    }

    /// What runs along the top or bottom of every page.
    public struct Running: Codable, Equatable, Sendable {

        /// What can be written there.
        public enum Token: String, Codable, CaseIterable, Sendable {
            case none, title, subtitle, author, date
            /// "Page 3 of 7"
            case page
            /// "3"
            case number
        }

        public var left: Token
        public var centre: Token
        public var right: Token

        /// A hairline between it and the page.
        public var rule: Bool

        /// Whether the first page has it. A page with a title block on it
        /// does not usually want the title again above it.
        public var firstPage: Bool

        public init(left: Token = .none, centre: Token = .none, right: Token = .none, rule: Bool = false, firstPage: Bool = false) {
            self.left = left
            self.centre = centre
            self.right = right
            self.rule = rule
            self.firstPage = firstPage
        }

        public var isEmpty: Bool { left == .none && centre == .none && right == .none }
    }

    /// Weights the designs choose between.
    public enum Weight: String, Codable, CaseIterable, Sendable {
        case regular, medium, semibold, bold

        var family: FontFamily.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }

    /// A colour, named by its role rather than its value, so a design
    /// works under any theme.
    public enum Paint: String, Codable, CaseIterable, Sendable {
        /// Body text.
        case ink
        /// Secondary text.
        case muted
        /// The theme's accent — or the ink, under a monochrome theme.
        case accent
        /// A pale tint of the accent, for fills.
        case wash
        /// The rule colour.
        case hairline
        /// The page itself: no fill, no bar.
        case none
    }
}

// MARK: - Reading one

extension Blueprint {

    /// Every part is optional in the file: a design is a copy of another
    /// with the differences written, and a file naming nothing but its
    /// `name` is the plain design.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try c.value(.name, or: "custom"),
            description: try c.value(.description, or: ""),
            typeface: try c.choice(.typeface, or: .sans, called: "typeface"),
            page: try c.value(.page, or: Page()),
            scale: try c.value(.scale, or: Scale()),
            title: try c.value(.title, or: TitleBlock()),
            headings: try c.value(.headings, or: HeadingStyle.defaults),
            code: try c.value(.code, or: CodeStyle()),
            quote: try c.value(.quote, or: QuoteStyle()),
            table: try c.value(.table, or: TableStyle()),
            lists: try c.value(.lists, or: ListStyle()),
            links: try c.value(.links, or: LinkStyle()),
            header: try c.value(.header, or: Running()),
            footer: try c.value(.footer, or: Running(centre: .page))
        )
    }

    enum CodingKeys: String, CodingKey {
        case name, description, typeface, page, scale, title, headings, code, quote, table, lists, links, header, footer
    }
}

extension Blueprint.Page {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(margin: try c.value(.margin, or: 58), runningInset: try c.value(.runningInset, or: 26))
    }
    enum CodingKeys: String, CodingKey { case margin, runningInset }
}

extension Blueprint.Scale {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(body: try c.value(.body, or: 10.5), leading: try c.value(.leading, or: 1.45),
                  paragraphGap: try c.value(.paragraphGap, or: 0.75), blockGap: try c.value(.blockGap, or: 1.0))
    }
    enum CodingKeys: String, CodingKey { case body, leading, paragraphGap, blockGap }
}

extension Blueprint.TitleBlock {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            style: try c.choice(.style, or: .plain, called: "title style"),
            size: try c.value(.size, or: 26),
            weight: try c.choice(.weight, or: .bold, called: "weight"),
            uppercase: try c.value(.uppercase, or: false),
            tracking: try c.value(.tracking, or: 0),
            byline: try c.value(.byline, or: true),
            rule: try c.value(.rule, or: true),
            logo: try c.value(.logo, or: true),
            fields: try c.value(.fields, or: ["to", "from", "date", "re"]),
            gap: try c.value(.gap, or: 2.0)
        )
    }
    enum CodingKeys: String, CodingKey { case style, size, weight, uppercase, tracking, byline, rule, logo, fields, gap }
}

extension Blueprint.HeadingStyle {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            size: try c.value(.size, or: 14),
            weight: try c.choice(.weight, or: .bold, called: "weight"),
            colour: try c.choice(.colour, or: .ink, called: "colour"),
            uppercase: try c.value(.uppercase, or: false),
            tracking: try c.value(.tracking, or: 0),
            rule: try c.value(.rule, or: false),
            before: try c.value(.before, or: 1.6),
            after: try c.value(.after, or: 0.5),
            numbered: try c.value(.numbered, or: false)
        )
    }
    enum CodingKeys: String, CodingKey { case size, weight, colour, uppercase, tracking, rule, before, after, numbered }
}

extension Blueprint.CodeStyle {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fill: try c.choice(.fill, or: .wash, called: "fill"), border: try c.value(.border, or: false),
                  size: try c.value(.size, or: 8.8), label: try c.value(.label, or: true))
    }
    enum CodingKeys: String, CodingKey { case fill, border, size, label }
}

extension Blueprint.QuoteStyle {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(bar: try c.choice(.bar, or: .accent, called: "bar"), italic: try c.value(.italic, or: false),
                  colour: try c.choice(.colour, or: .muted, called: "colour"), inset: try c.value(.inset, or: 14))
    }
    enum CodingKeys: String, CodingKey { case bar, italic, colour, inset }
}

extension Blueprint.TableStyle {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(headerFill: try c.choice(.headerFill, or: .wash, called: "header fill"),
                  striped: try c.value(.striped, or: false), rules: try c.value(.rules, or: true),
                  size: try c.value(.size, or: 9.5))
    }
    enum CodingKeys: String, CodingKey { case headerFill, striped, rules, size }
}

extension Blueprint.ListStyle {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(bullet: try c.value(.bullet, or: "•"), colour: try c.choice(.colour, or: .ink, called: "colour"),
                  indent: try c.value(.indent, or: 16))
    }
    enum CodingKeys: String, CodingKey { case bullet, colour, indent }
}

extension Blueprint.LinkStyle {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(colour: try c.choice(.colour, or: .accent, called: "colour"), underline: try c.value(.underline, or: false))
    }
    enum CodingKeys: String, CodingKey { case colour, underline }
}

extension Blueprint.Running {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(left: try c.choice(.left, or: .none, called: "running token"),
                  centre: try c.choice(.centre, or: .none, called: "running token"),
                  right: try c.choice(.right, or: .none, called: "running token"),
                  rule: try c.value(.rule, or: false), firstPage: try c.value(.firstPage, or: false))
    }
    enum CodingKeys: String, CodingKey { case left, centre, right, rule, firstPage }
}
