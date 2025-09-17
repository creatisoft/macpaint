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
            .credits: credits
            // You can also override other keys if desired, e.g.:
            // .applicationVersion: "1.0",
            // .applicationName: "macPaint"
        ]
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
