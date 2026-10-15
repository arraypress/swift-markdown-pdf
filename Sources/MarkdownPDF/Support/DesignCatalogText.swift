//
//  DesignCatalogText.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The bundled designs, as data. Compiled in as strings rather than shipped
//  as resources: a resource bundle beside a Homebrew binary breaks when the
//  binary is reached through a symlink, and with these and the fonts gone
//  this package has none. Each is the JSON `press designs --blueprint`
//  prints; a test checks every one reads strictly, under a kebab-case name
//  that is its own.
//

enum DesignCatalogText {

    /// Every file, by name, in the order they are listed.
    static let all: [(name: String, json: String)] = [
        ("report", report),
        ("memo", memo),
        ("article", article),
        ("plain", plain),
        ("manual", manual),
    ]

    static let report = ##"""
    {
      "name": "report",
      "description": "A business report: title and byline, ruled headings, a running title and page numbers.",
      "typeface": "sans",
      "page": { "margin": 60, "runningInset": 26 },
      "scale": { "body": 10.5, "leading": 1.45, "paragraphGap": 0.75, "blockGap": 1.0 },
      "title": { "style": "plain", "size": 26, "weight": "bold", "byline": true, "rule": true, "logo": true, "gap": 2.2 },
      "headings": [
        { "size": 17, "weight": "bold", "colour": "ink", "rule": true, "before": 1.9, "after": 0.7 },
        { "size": 13, "weight": "bold", "colour": "ink", "before": 1.5, "after": 0.45 },
        { "size": 11, "weight": "semibold", "colour": "accent", "before": 1.2, "after": 0.35 }
      ],
      "code": { "fill": "wash", "border": false, "size": 8.8, "label": true },
      "quote": { "bar": "accent", "italic": false, "colour": "muted", "inset": 14 },
      "table": { "headerFill": "wash", "striped": false, "rules": true, "size": 9.5 },
      "lists": { "bullet": "•", "colour": "ink", "indent": 16 },
      "links": { "colour": "accent", "underline": false },
      "header": { "left": "none", "centre": "none", "right": "title", "rule": true, "firstPage": false },
      "footer": { "left": "none", "centre": "page", "right": "none", "rule": false, "firstPage": true }
    }

    """##

    static let memo = ##"""
    {
      "name": "memo",
      "description": "A memo: To, From, Date and Re from the front matter, a rule, then the text.",
      "typeface": "sans",
      "page": { "margin": 62, "runningInset": 26 },
      "scale": { "body": 10.5, "leading": 1.45, "paragraphGap": 0.75, "blockGap": 1.0 },
      "title": { "style": "memo", "size": 30, "weight": "bold", "uppercase": true, "tracking": 2, "byline": false, "rule": true, "logo": true, "fields": ["to", "from", "cc", "date", "re"], "gap": 1.8 },
      "headings": [
        { "size": 12.5, "weight": "bold", "colour": "ink", "before": 1.6, "after": 0.5 },
        { "size": 11, "weight": "semibold", "colour": "ink", "before": 1.3, "after": 0.4 },
        { "size": 10.5, "weight": "semibold", "colour": "muted", "before": 1.1, "after": 0.3 }
      ],
      "code": { "fill": "wash", "border": false, "size": 8.8, "label": false },
      "quote": { "bar": "hairline", "italic": true, "colour": "muted", "inset": 14 },
      "table": { "headerFill": "none", "striped": false, "rules": true, "size": 9.5 },
      "lists": { "bullet": "–", "colour": "ink", "indent": 14 },
      "links": { "colour": "accent", "underline": false },
      "header": { "left": "none", "centre": "none", "right": "none", "rule": false, "firstPage": false },
      "footer": { "left": "title", "centre": "none", "right": "number", "rule": true, "firstPage": false }
    }

    """##

    static let article = ##"""
    {
      "name": "article",
      "description": "Serif and centred, for an essay, a long read or a piece of writing.",
      "typeface": "serif",
      "page": { "margin": 68, "runningInset": 28 },
      "scale": { "body": 11, "leading": 1.5, "paragraphGap": 0.7, "blockGap": 1.1 },
      "title": { "style": "centred", "size": 28, "weight": "bold", "byline": true, "rule": false, "logo": false, "gap": 2.6 },
      "headings": [
        { "size": 16, "weight": "bold", "colour": "ink", "before": 2.0, "after": 0.6 },
        { "size": 12.5, "weight": "semibold", "colour": "ink", "before": 1.6, "after": 0.45 },
        { "size": 10.5, "weight": "semibold", "colour": "muted", "uppercase": true, "tracking": 1.2, "before": 1.4, "after": 0.4 }
      ],
      "code": { "fill": "wash", "border": false, "size": 8.6, "label": false },
      "quote": { "bar": "none", "italic": true, "colour": "ink", "inset": 24 },
      "table": { "headerFill": "none", "striped": false, "rules": true, "size": 9.5 },
      "lists": { "bullet": "•", "colour": "ink", "indent": 18 },
      "links": { "colour": "accent", "underline": true },
      "header": { "left": "none", "centre": "none", "right": "none", "rule": false, "firstPage": false },
      "footer": { "left": "none", "centre": "number", "right": "none", "rule": false, "firstPage": true }
    }

    """##

    static let plain = ##"""
    {
      "name": "plain",
      "description": "Nothing but the text, set well: what a README looks like on paper.",
      "typeface": "sans",
      "page": { "margin": 56, "runningInset": 24 },
      "scale": { "body": 10.5, "leading": 1.45, "paragraphGap": 0.75, "blockGap": 0.9 },
      "title": { "style": "none", "size": 22, "weight": "bold", "byline": false, "rule": false, "logo": false, "gap": 1.0 },
      "headings": [
        { "size": 20, "weight": "bold", "colour": "ink", "rule": true, "before": 1.6, "after": 0.6 },
        { "size": 15, "weight": "bold", "colour": "ink", "rule": true, "before": 1.5, "after": 0.5 },
        { "size": 12, "weight": "bold", "colour": "ink", "before": 1.3, "after": 0.4 },
        { "size": 10.5, "weight": "bold", "colour": "ink", "before": 1.1, "after": 0.3 }
      ],
      "code": { "fill": "wash", "border": false, "size": 8.8, "label": false },
      "quote": { "bar": "hairline", "italic": false, "colour": "muted", "inset": 14 },
      "table": { "headerFill": "none", "striped": true, "rules": true, "size": 9.5 },
      "lists": { "bullet": "•", "colour": "ink", "indent": 16 },
      "links": { "colour": "accent", "underline": false },
      "header": { "left": "none", "centre": "none", "right": "none", "rule": false, "firstPage": false },
      "footer": { "left": "none", "centre": "none", "right": "number", "rule": false, "firstPage": true }
    }

    """##

    static let manual = ##"""
    {
      "name": "manual",
      "description": "Technical: an accent band, numbered headings, bordered code and a running title.",
      "typeface": "sans",
      "page": { "margin": 58, "runningInset": 26 },
      "scale": { "body": 10, "leading": 1.48, "paragraphGap": 0.75, "blockGap": 1.0 },
      "title": { "style": "band", "size": 24, "weight": "bold", "byline": true, "rule": false, "logo": true, "gap": 2.2 },
      "headings": [
        { "size": 16, "weight": "bold", "colour": "accent", "rule": true, "before": 1.9, "after": 0.7, "numbered": true },
        { "size": 12.5, "weight": "bold", "colour": "ink", "before": 1.5, "after": 0.45, "numbered": true },
        { "size": 10.5, "weight": "semibold", "colour": "ink", "before": 1.2, "after": 0.35, "numbered": true }
      ],
      "code": { "fill": "wash", "border": true, "size": 8.6, "label": true },
      "quote": { "bar": "accent", "italic": false, "colour": "ink", "inset": 14 },
      "table": { "headerFill": "accent", "striped": true, "rules": false, "size": 9.2 },
      "lists": { "bullet": "▪", "colour": "accent", "indent": 16 },
      "links": { "colour": "accent", "underline": false },
      "header": { "left": "title", "centre": "none", "right": "date", "rule": true, "firstPage": false },
      "footer": { "left": "author", "centre": "none", "right": "page", "rule": false, "firstPage": true }
    }

    """##

}
