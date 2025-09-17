//  LayerModels.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI

struct Layer: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var isVisible: Bool = true
    var opacity: Double = 1.0
    var items: [Drawable] = []

    init(name: String) {
        self.name = name
    }
}

enum BrushSize: CGFloat, CaseIterable, Identifiable {
    case small = 4
    case medium = 8
    case large = 16

    var id: CGFloat { rawValue }

    var name: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

struct CanvasSize: Equatable {
    var width: CGFloat
    var height: CGFloat

    static let small = CanvasSize(width: 640, height: 480)
    static let medium = CanvasSize(width: 1024, height: 768)
    static let large = CanvasSize(width: 1920, height: 1080)
}

// Selection handles
enum SelectionHandle {
    case topLeft
    case topCenter
    case topRight
    case rightCenter
    case bottomRight
    case bottomCenter
    case bottomLeft
    case leftCenter
    case rotation
}
