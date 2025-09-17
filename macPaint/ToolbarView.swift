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

    // Fixed palette for neutral hover/selection against white background
    private let selectionStroke = Color.black // outlines and rings
    private let selectionFill = Color.black.opacity(0.12) // selected background
    private let hoverFill = Color.black.opacity(0.06) // hover background
    private let controlStrokeDim = Color.black.opacity(0.25) // unselected outlines

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // App title with icon forced to black
                HStack(spacing: 6) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.black)
                    Text("macPaint")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.black)

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
                                        ? selectionFill
                                        : (hoveredBrush == size ? hoverFill : Color.clear)
                                    )
                                VStack(spacing: 0) {
                                    Circle()
                                        .stroke(brushSize == size ? selectionStroke : controlStrokeDim,
                                                lineWidth: brushSize == size ? 2 : 1)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .fill(Color.black)
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
                                        ? selectionFill
                                        : (hoveredPaletteIndex == index ? hoverFill : Color.clear)
                                    )
                                ZStack {
                                    Circle().fill(color).frame(width: 22, height: 22)
                                    Circle()
                                        .stroke(selectedColor == color ? selectionStroke.opacity(0.9) : controlStrokeDim,
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
                                .fill(hoverFill)
                            ZStack {
                                Circle().fill(Color.clear).frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(controlStrokeDim, lineWidth: 1))
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(Color.black)
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
                        .foregroundStyle(.black)
                    TextField("W", text: $customWidth)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(applyCustomSize)
                    Text("×")
                        .foregroundStyle(.black)
                    TextField("H", text: $customHeight)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(applyCustomSize)
                    Button("Apply", action: applyCustomSize)
                        .buttonStyle(.bordered)
                        .help("Apply custom canvas size")
                }
                .tint(.black) // button border/label to black

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
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.black)
                    }
                    .help("Zoom out")

                    Text("\(Int(zoom * 100))%").monospacedDigit()
                        .foregroundStyle(.black)

                    Button {
                        withAnimation { zoom = min(4.0, zoom + 0.25) }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.black)
                    }
                    .help("Zoom in")
                }

                Divider().frame(height: 24)

                // Actions
                Button {
                    clearCanvas()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.black)
                        Text("Clear")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.black)

                Button {
                    saveAction()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.black)
                        Text("Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .keyboardShortcut("s", modifiers: [.command])
                .help("Save canvas as PNG")
            }
            .padding(10)
            .background(Color.white)
            .overlay(Divider(), alignment: .bottom)
        }
    }
}
