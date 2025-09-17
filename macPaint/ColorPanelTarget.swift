//  ColorPanelTarget.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import AppKit

final class ColorPanelTarget: NSObject {
    var onChange: ((NSColor) -> Void)?

    @objc func colorPanelDidChange(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}
