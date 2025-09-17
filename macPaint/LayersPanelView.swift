//  LayersPanelView.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI

struct LayersPanelView: View {
    @Binding var layers: [Layer]
    @Binding var selectedLayerIndex: Int

    @State private var renamingLayerID: UUID? = nil
    @FocusState private var isRenamingFocused: Bool

    var addLayer: () -> Void
    var removeSelectedLayer: () -> Void
    var moveLayers: (IndexSet, Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()
                Button {
                    addLayer()
                } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .help("Add layer")
                Button {
                    removeSelectedLayer()
                } label: { Image(systemName: "minus") }
                .buttonStyle(.borderless)
                .help("Delete selected layer")
                .disabled(layers.count <= 1)
            }
            .padding(8)
            .background(Color(nsColor: .underPageBackgroundColor))
            Divider()
            List(selection: Binding(get: {
                Set([selectedLayerIndex])
            }, set: { newSelection in
                if let idx = newSelection.first, layers.indices.contains(idx) {
                    selectedLayerIndex = idx
                }
            })) {
                ForEach(Array(layers.enumerated()), id: \.1.id) { index, layer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            if renamingLayerID == layer.id {
                                TextField("Layer", text: Binding(
                                    get: { layers[index].name },
                                    set: { newValue in layers[index].name = newValue }
                                ))
                                .textFieldStyle(.plain)
                                .focused($isRenamingFocused)
                                .onSubmit { finishRenaming() }
                                .onAppear { DispatchQueue.main.async { isRenamingFocused = true } }
                                .onChange(of: isRenamingFocused) { focused in
                                    if !focused && renamingLayerID == layer.id { finishRenaming() }
                                }
                            } else {
                                Text(layers[index].name).lineLimit(1)
                            }

                            Spacer()
                            Button {
                                layers[index].isVisible.toggle()
                            } label: {
                                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                                    .foregroundStyle(layer.isVisible ? .primary : .secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(layer.isVisible ? "Hide layer" : "Show layer")
                        }

                        // Opacity slider
                        HStack {
                            Text("Opacity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: Binding(
                                get: { layers[index].opacity },
                                set: { layers[index].opacity = $0 }
                            ), in: 0...1)
                        }

                        // Move controls: always visible; enabled based on possible movement in list order.
                        // Up = move toward top of the list (lower index). Down = move toward bottom (higher index).
                        HStack(spacing: 8) {
                            Button {
                                moveRowUp(index)
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .help("Move layer up")
                            .disabled(!canMoveRowUp(index))

                            Button {
                                moveRowDown(index)
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .help("Move layer down")
                            .disabled(!canMoveRowDown(index))
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background(index == selectedLayerIndex ? Color.accentColor.opacity(0.1) : Color.clear)
                    .onTapGesture { selectedLayerIndex = index }
                    .contextMenu {
                        Button("Rename") {
                            renamingLayerID = layer.id
                            selectedLayerIndex = index
                        }
                        // Delete Layer: disabled when only one layer OR this row is the last/topmost layer (highest index)
                        Button("Delete Layer") {
                            deleteLayer(at: index)
                        }
                        .disabled(layers.count <= 1 || index == layers.count - 1)
                    }
                }
                .onMove(perform: moveLayers)
            }
            .listStyle(.inset)
            .frame(minWidth: 220)
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(Divider(), alignment: .leading)
    }

    private func finishRenaming() {
        renamingLayerID = nil
        isRenamingFocused = false
    }

    // MARK: - Movement helpers (list-order semantics)

    private func canMoveRowUp(_ index: Int) -> Bool {
        // Up in the list = toward lower index
        return layers.indices.contains(index) && index > 0
    }

    private func canMoveRowDown(_ index: Int) -> Bool {
        // Down in the list = toward higher index
        return layers.indices.contains(index) && index < layers.count - 1
    }

    private func moveRowUp(_ index: Int) {
        guard canMoveRowUp(index) else { return }
        // Corrected: move item at 'index' to 'index - 1'
        layers.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
        // Adjust selection
        if selectedLayerIndex == index {
            selectedLayerIndex = index - 1
        } else if selectedLayerIndex == index - 1 {
            selectedLayerIndex = index
        }
    }

    private func moveRowDown(_ index: Int) {
        guard canMoveRowDown(index) else { return }
        // Move item at 'index' to just after 'index + 1'
        layers.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
        // Adjust selection
        if selectedLayerIndex == index {
            selectedLayerIndex = index + 1
        } else if selectedLayerIndex == index + 1 {
            selectedLayerIndex = index
        }
    }

    // MARK: - Delete

    private func deleteLayer(at index: Int) {
        guard layers.indices.contains(index) else { return }
        // Prevent deleting if only one layer, or if it's the last/topmost layer (highest index)
        guard layers.count > 1, index != layers.count - 1 else { return }

        layers.remove(at: index)

        // Maintain a sane selection after deletion
        if selectedLayerIndex == index {
            selectedLayerIndex = min(index, max(0, layers.count - 1))
        } else if selectedLayerIndex > index {
            selectedLayerIndex -= 1
        }
    }
}

