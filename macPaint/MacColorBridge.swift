//  MacColorBridge.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI
import AppKit

enum MacColorBridge {
    static func nsColor(from color: Color) -> NSColor {
        // 1) Best path on modern macOS: direct initializer
        if #available(macOS 12.0, *) {
            // This initializer resolves dynamic/system colors correctly.
            return NSColor(color)
        }

        // 2) Try CGColor if available (common for fixed sRGB colors)
        if let cg = color.cgColor, let ns = NSColor(cgColor: cg) {
            return ns
        }

        // 3) Fallback: assume sRGB and try to pull RGBA via SwiftUI -> CGColor conversion
        // If still unavailable, return black as a safe default (not white, to avoid "invisible" strokes on white bg).
        return .black
    }
}
