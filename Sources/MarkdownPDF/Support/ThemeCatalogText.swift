//
//  ThemeCatalogText.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//
//  The preset themes, as data, compiled in for the same reason the designs
//  are. The shape is DocumentTheme's, shared with the résumé library.
//

enum ThemeCatalogText {

    /// Every file, by name, in the order they are listed.
    static let all: [(name: String, json: String)] = [
        ("plain", plain),
        ("navy", navy),
        ("classic", classic),
        ("american", american),
    ]

    static let plain = ##"""
    {
      "accent": "#111111",
      "pageSize": "A4",
      "density": "normal",
      "justified": false
    }

    """##

    static let navy = ##"""
    {
      "accent": "#1F3A5F",
      "pageSize": "A4",
      "density": "normal",
      "justified": false
    }

    """##

    static let classic = ##"""
    {
      "typeface": "serif",
      "accent": "#3A2A1A",
      "pageSize": "A4",
      "density": "relaxed",
      "justified": true
    }

    """##

    static let american = ##"""
    {
      "accent": "#111111",
      "pageSize": "Letter",
      "density": "normal",
      "justified": false
    }

    """##

}
