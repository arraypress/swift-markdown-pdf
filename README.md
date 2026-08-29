# MarkdownPDF

Markdown into a document somebody would hand over. Five designs, every one a JSON file; real typography; a Word document, plain text and a check that says what a reader would notice — all on-device, nothing to install but Swift.

```swift
import MarkdownPDF

let manuscript = try Manuscript(contentsOf: url)          // front matter + CommonMark/GFM
try manuscript.save(to: out, design: .report)              // a PDF
try manuscript.saveDocx(to: docx)                          // a Word document
let pasted = manuscript.plainText()                        // for the box that takes nothing else
```

## Why

Agents write Markdown all day, and every route from that to a decent PDF runs through a LaTeX install or a headless browser. This is the other route: parse once with Apple's [swift-markdown](https://github.com/apple/swift-markdown) — CommonMark and the GFM extensions, the parser DocC uses — then set the same blocks in a chosen design, embed the fonts, and write the file. A report, a memo, an article, a manual and a plain page, each a JSON file you can copy and change without a toolchain.

## Features

- 🎨 **Five designs, all JSON** — `report`, `memo`, `article`, `plain`, `manual`; a design of your own is a copy of one with the choices changed
- 🔤 **Real typography** — Inter, Source Serif 4 and JetBrains Mono travel with the package and are embedded, subset, into the file; or bring your own family
- 📐 **Everything Markdown does** — six heading levels, nested emphasis, code, links that click, figures with captions, nested and task lists, quotes, GFM tables that wrap, rules, escapes, entities, reference links, autolinks
- 📄 **The page as a page** — running headers and footers, "Page 3 of 7", bookmarks for the outline, headings kept with what follows them, no widows
- 🗂️ **Front matter** — `title`, `subtitle`, `author`, `date`, and whatever a memo needs
- 🎛️ **Themes** — accent, typeface, page size, density, justification, a logo: the brand, apart from the design
- 📝 **Word, plain text** — `docx()` for the form that takes nothing else, `plainText()` for the paste
- ✅ **A check** — a missing picture, a heading of nothing, a skipped level, a table wider than the page, HTML that will not draw
- 📐 **JSON Schemas** — for a design and a theme, kept honest by the tests
- 🪶 **Three dependencies** — the PDF writer, the Word writer, the parser

## The designs

| Design | What it is | Title block |
|---|---|---|
| `report` | Business report: ruled headings, running title, page numbers. The default. | Title, subtitle, byline, rule |
| `memo` | To / From / Date / Re from the front matter, then the text. | Memo head |
| `article` | Serif, centred, for an essay or a long read. | Centred |
| `plain` | Nothing but the text, set well — a README on paper. | None: the `#` is the title |
| `manual` | Technical: accent band, numbered headings, bordered code. | Band |

Every design is rendered from the same sample under [Examples/](Examples/).

```swift
try manuscript.save(to: url, design: .memo)
try manuscript.save(to: url, design: .article, theme: .classic)
let data = try manuscript.render(design: .manual, theme: Theme(accent: "#1F3A5F"))
```

## Front matter

```markdown
---
title: Ledger Write Path Review
subtitle: Findings from the Q3 reliability audit
author: Alex Moreau
date: 14 August 2026
to: Platform Engineering
re: p99 latency
---
```

`key: value` lines between `---` fences, quoted or not. The known keys set the title block, the running header and the PDF's own metadata; a memo lists whichever of its `fields` are present. A document with no `title:` takes its opening `#` heading as the title, and a design that draws a title block does not set that heading twice.

## Themes

```swift
Theme(accent: "#1F3A5F"),                         // an ink blue on rules, headings and links
Theme(typeface: .sourceSerif),                    // the serif, whatever the design was drawn for
Theme(pageSize: .letter, density: .compact),      // US paper, tighter
Theme(justified: true, logo: "logo.png"),         // flush edges, a logo where the design has a place
Theme.named("navy"),                              // a preset, from its file
```

The presets — `plain`, `navy`, `classic`, `american` — are JSON files in the package's resources, the way the designs are. A theme is the brand and a design is the arrangement, so one theme makes a report, a memo and an article that visibly belong together — and its fields are the same handful the family's other document libraries read.

## As a Word document, as text

```swift
try manuscript.saveDocx(to: url)                 // headings, emphasis, links, lists, in the theme's face
let text = manuscript.plainText()                // headings on their lines, a dash per item, tables as columns
```

One layout, not five: a `.docx` goes where a form or a colleague demands one, and it carries the words with their structure — the things Word can be trusted with. What a design does with the page is a property of the PDF. Tables in Word are set as spaced lines; the writer does not draw Word tables yet.

## The check

```swift
let report = try manuscript.check(design: .report)
let clean = report.isClean                       // no blockers
let pages = report.pages                         // how many it ran to
for finding in report.findings { print(finding.severity, finding.message, finding.detail) }
```

A **blocker** is something wrong on the page: a picture that is not there or cannot be used. A **warning** reads: a heading with nothing under it, a level skipped, an HTML block that nothing draws, a link with no address, a table with more columns than the page can set. A **note** advises: no title, a line of code longer than the block is wide.

## A design of your own

```swift
let mine = try Blueprint(contentsOf: file)       // a JSON file, edited from one of the five
try manuscript.save(to: url, design: mine)
let json = try DesignKind.report.blueprint.encoded()   // the report, to start from
```

A blueprint is the page, the scale, the title block, how each level of heading is set, and what code, quotes, tables and lists look like. Every key is optional — a file that says only `{ "name": "mine" }` is the plain design. Colours are named by role (`ink`, `muted`, `accent`, `wash`, `hairline`) so a design works under any theme.

## The schemas

```swift
let schema = Schema.blueprint.json               // JSON Schema, draft 2020-12
```

One for a design and one for a theme. The tests validate every file the package carries against them.

## What Markdown is covered

Parsing is CommonMark plus the GFM extensions the parser enables — tables, strikethrough, task lists — and bare `https://` URLs are autolinked here. Everything parsed is drawn except raw HTML, which is dropped and reported by the check (`<br>` is honoured). Footnotes, maths, heading `{#ids}` and emoji shortcodes are other tools' extensions: their text is set as written. Code blocks are monospaced, not coloured.

## Requirements

- macOS 14+ / iOS 17+
- Swift 6

## Built on

- [swift-text-pdf](https://github.com/arraypress/swift-text-pdf) — the writer: text, links, images, embedded fonts, bookmarks
- [swift-text-docx](https://github.com/arraypress/swift-text-docx) — the Word writer
- [swift-markdown](https://github.com/apple/swift-markdown) — Apple's CommonMark + GFM parser

## License

MIT
