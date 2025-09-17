//  ToolbarView.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI
import AppKit

struct ToolbarView: View {
    @Binding var brushSize: BrushSize
    @Binding var selectedColor: Color
    let palette: [Color]

    @Binding var customWidth: String
    @Binding var customHeight: String
    var applyCustomSize: () -> Void

    @Binding var backgroundColor: Color

    @Binding var zoom: CGFloat
    var clearCanvas: () -> Void
    var saveAction: () -> Void
    var openSystemColorPanel: () -> Void

    @State private var hoveredBrush: BrushSize? = nil
    @State private var hoveredPaletteIndex: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // App title
                Label("macPaint", systemImage: "paintbrush.pointed.fill")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)

                Divider().frame(height: 24)

                // Brush sizes
                HStack(spacing: 8) {
                    ForEach(BrushSize.allCases) { size in
                        Button {
                            brushSize = size
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        brushSize == size
                                        ? Color.accentColor.opacity(0.15)
                                        : (hoveredBrush == size ? Color.secondary.opacity(0.08) : Color.clear)
                                    )
                                VStack(spacing: 0) {
                                    Circle()
                                        .stroke(brushSize == size ? Color.accentColor : Color.secondary.opacity(0.3),
                                                lineWidth: brushSize == size ? 2 : 1)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .fill(Color.primary)
                                                .frame(width: max(6, CGFloat(size.rawValue)),
                                                       height: max(6, CGFloat(size.rawValue)))
                                        )
                                }
                            }
                            .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .onHover { hovering in hoveredBrush = hovering ? size : (hoveredBrush == size ? nil : hoveredBrush) }
                        .help("Brush: \(size.name)")
                    }
                }

                Divider().frame(height: 24)

                // Color palette + custom color opener
                HStack(spacing: 6) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { index, color in
                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        selectedColor == color
                                        ? Color.accentColor.opacity(0.12)
                                        : (hoveredPaletteIndex == index ? Color.secondary.opacity(0.06) : Color.clear)
                                    )
                                ZStack {
                                    Circle().fill(color).frame(width: 22, height: 22)
                                    Circle()
                                        .stroke(Color.primary.opacity(selectedColor == color ? 0.8 : 0.2),
                                                lineWidth: selectedColor == color ? 2 : 1)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .onHover { hovering in hoveredPaletteIndex = hovering ? index : (hoveredPaletteIndex == index ? nil : hoveredPaletteIndex) }
                        .help("Choose color")
                    }

                    Button {
                        openSystemColorPanel()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.06))
                            ZStack {
                                Circle().fill(Color.clear).frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(Color.secondary.opacity(0.6), lineWidth: 1))
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .help("More colors…")
                }

                Divider().frame(height: 24)

                // Custom canvas size
                HStack(spacing: 6) {
                    Text("Canvas:")
                    TextField("W", text: $customWidth)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(applyCustomSize)
                    Text("×")
                    TextField("H", text: $customHeight)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(applyCustomSize)
                    Button("Apply", action: applyCustomSize)
                        .buttonStyle(.bordered)
                        .help("Apply custom canvas size")
                }

                Divider().frame(height: 24)

                // Background color
                ColorPicker("", selection: $backgroundColor, supportsOpacity: true)
                    .labelsHidden()
                    .help("Canvas background color")

                Spacer()

                // Zoom
                HStack(spacing: 8) {
                    Button {
                        withAnimation { zoom = max(0.25, zoom - 0.25) }
                    } label: { Image(systemName: "minus.magnifyingglass") }
                    .help("Zoom out")

                    Text("\(Int(zoom * 100))%").monospacedDigit()

                    Button {
                        withAnimation { zoom = min(4.0, zoom + 0.25) }
                    } label: { Image(systemName: "plus.magnifyingglass") }
                    .help("Zoom in")
                }

                Divider().frame(height: 24)

                // Actions
                Button {
                    clearCanvas()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Button {
                    saveAction()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: [.command])
                .help("Save canvas as PNG")
            }
            .padding(10)
            .background(Color.white)
            .overlay(Divider(), alignment: .bottom)
        }
    }
}
