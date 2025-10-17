//  ColorPanelTarget.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import AppKit
import Combine

final class ColorPanelTarget: NSObject, ObservableObject {
    var onChange: ((NSColor) -> Void)?

    @objc func colorPanelDidChange(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}
