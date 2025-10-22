//
//  macPaintApp.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI
import AppKit

@main
struct macPaintApp: App {
    // Focused actions the menus will invoke
    @FocusedValue(\.setToolAction) private var setTool
    @FocusedValue(\.deleteSelectionAction) private var deleteSelection
    @FocusedValue(\.zoomInAction) private var zoomIn
    @FocusedValue(\.zoomOutAction) private var zoomOut
    @FocusedValue(\.zoomResetAction) private var zoomReset

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // Replace the default "About" menu item to inject custom credits.
            CommandGroup(replacing: .appInfo) {
                Button("About macPaint") {
                    showAboutPanel()
                }
            }

            // Tools menu with single-key shortcuts
            CommandMenu("Tools") {
                Button("Select") { setTool?(.select) }
                    .keyboardShortcut("v", modifiers: [])
                Button("Brush") { setTool?(.brush) }
                    .keyboardShortcut("b", modifiers: [])
                Button("Eraser") { setTool?(.eraser) }
                    .keyboardShortcut("e", modifiers: [])
                Button("Line") { setTool?(.line) }
                    .keyboardShortcut("l", modifiers: [])
                Button("Rectangle") { setTool?(.rectangle) }
                    .keyboardShortcut("r", modifiers: [])
                Button("Ellipse") { setTool?(.ellipse) }
                    .keyboardShortcut("o", modifiers: [])
                Button("Bucket") { setTool?(.bucket) }
                    .keyboardShortcut("g", modifiers: [])
            }

            // Edit group for deleting selected item
            CommandGroup(after: .pasteboard) {
                Button("Delete Selection") { deleteSelection?() }
                    .keyboardShortcut(.delete, modifiers: [])
                Button("Delete Selection (Forward)") { deleteSelection?() }
                    .keyboardShortcut(.deleteForward, modifiers: [])
            }

            // View menu for zoom
            CommandMenu("View") {
                Button("Zoom In") { zoomIn?() }
                    .keyboardShortcut("+", modifiers: [.command])
                Button("Zoom Out") { zoomOut?() }
                    .keyboardShortcut("-", modifiers: [.command])
                Button("Actual Size") { zoomReset?() }
                    .keyboardShortcut("0", modifiers: [.command])
            }
        }
    }
}

private extension macPaintApp {
    func showAboutPanel() {
        // Centered paragraph style for the credits text
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.lineBreakMode = .byWordWrapping
        centered.lineSpacing = 2

        let credits = NSAttributedString(
            string: "Created by:\nChristopher Moya\nX: @creatisoft\n(2025)",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: centered
            ]
        )

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .credits: credits,
            // You can also override other keys if desired, e.g.:
             .applicationVersion: "0.1.0",
            // .applicationName: "macPaint"
        ]
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

// MARK: - Focused Value Keys for Commands wiring

struct SetToolActionKey: FocusedValueKey {
    typealias Value = (Tool) -> Void
}
struct DeleteSelectionActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
struct ZoomInActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
struct ZoomOutActionKey: FocusedValueKey {
    typealias Value = () -> Void
}
struct ZoomResetActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var setToolAction: ((Tool) -> Void)? {
        get { self[SetToolActionKey.self] }
        set { self[SetToolActionKey.self] = newValue }
    }
    var deleteSelectionAction: (() -> Void)? {
        get { self[DeleteSelectionActionKey.self] }
        set { self[DeleteSelectionActionKey.self] = newValue }
    }
    var zoomInAction: (() -> Void)? {
        get { self[ZoomInActionKey.self] }
        set { self[ZoomInActionKey.self] = newValue }
    }
    var zoomOutAction: (() -> Void)? {
        get { self[ZoomOutActionKey.self] }
        set { self[ZoomOutActionKey.self] = newValue }
    }
    var zoomResetAction: (() -> Void)? {
        get { self[ZoomResetActionKey.self] }
        set { self[ZoomResetActionKey.self] = newValue }
    }
}
