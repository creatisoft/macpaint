//  ToolsPanelView.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI

struct ToolsPanelView: View {
    @Binding var currentTool: Tool
    @State private var hoveredTool: Tool? = nil

    // New: external action to import an image
    var importImageAction: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Tool.allCases) { tool in
                Button {
                    currentTool = tool
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .symbolRenderingMode(.monochrome)
                            // Keep theme as-is, but make icons white when selected for contrast.
                            .foregroundStyle(currentTool == tool ? Color.white : Color.primary)
                        Text(tool.displayName)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(Color.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                currentTool == tool
                                ? Color.accentColor.opacity(0.15)
                                : (hoveredTool == tool ? Color.secondary.opacity(0.08) : Color.clear)
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

            // Place "Import Image…" button underneath the ellipse/bucket buttons
            Divider().padding(.vertical, 4)

            Button {
                importImageAction()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.primary)
                    Text("Import Image…")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
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

