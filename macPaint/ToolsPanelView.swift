//  ToolsPanelView.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI

struct ToolsPanelView: View {
    @Binding var currentTool: Tool
    @State private var hoveredTool: Tool? = nil

    // External action to import an image
    var importImageAction: () -> Void = {}

    // Dynamic, appearance-friendly colors
    private let selectionFill = Color.accentColor.opacity(0.15)
    private let hoverFill = Color.primary.opacity(0.06)

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Tool.allCases) { tool in
                Button {
                    currentTool = tool
                } label: {
                    HStack(spacing: 8) {
                        if tool == .bucket {
                            HStack(spacing: 4) {
                                Image(systemName: tool.systemImage)
                                    .font(.system(size: 16, weight: .medium))
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .opacity(0.95)
                            }
                            .foregroundStyle(.primary)
                        } else {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                        }

                        Text(tool.displayName)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                currentTool == tool
                                ? selectionFill
                                : (hoveredTool == tool ? hoverFill : Color.clear)
                            )
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .onHover { hovering in
                    hoveredTool = hovering ? tool : (hoveredTool == tool ? nil : hoveredTool)
                }
                .help(tool.displayName)
            }

            Divider().padding(.vertical, 4)

            Button {
                importImageAction()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Import Image…")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hoverFill)
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Import an image as a new layer")

            Spacer()
        }
        .padding(8)
        .frame(width: 140)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(Divider(), alignment: .trailing)
    }
}
