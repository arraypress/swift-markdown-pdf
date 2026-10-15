//
//  MarkdownPDFError.swift
//  MarkdownPDF
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why a document could not be made as asked.
public enum MarkdownPDFError: Error, LocalizedError, Equatable {

    /// A design named that the package does not carry.
    case unknownDesign(String)

    public var errorDescription: String? {
        switch self {
        case .unknownDesign(let name):
            return "There is no design called '\(name)'."
        }
    }
}
