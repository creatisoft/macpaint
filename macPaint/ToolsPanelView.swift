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

    // Fixed colors for consistent appearance on white background
    private let selectionFill = Color.black.opacity(0.12)   // selected row background
    private let hoverFill = Color.black.opacity(0.06)       // hover row background
    private let iconColor = Color.black                      // tool icons
    private let textColor = Color.black                      // labels

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Tool.allCases) { tool in
                Button {
                    currentTool = tool
                } label: {
                    HStack(spacing: 8) {
                        // Leading icons
                        if tool == .bucket {
                            // Show both the bucket and an extra droplet icon on the left
                            HStack(spacing: 4) {
                                Image(systemName: tool.systemImage)
                                    .font(.system(size: 16, weight: .medium))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(iconColor)
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(iconColor)
                                    .opacity(0.95)
                            }
                        } else {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 16, weight: .medium))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(iconColor)
                        }

                        // Text
                        Text(tool.displayName)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(textColor)

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

            // Place "Import Image…" button underneath the tool list
            Divider().padding(.vertical, 4)

            Button {
                importImageAction()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(iconColor)
                    Text("Import Image…")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(textColor)
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
        .background(Color.white)
        .overlay(Divider(), alignment: .trailing)
    }
}
