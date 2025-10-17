//  LayersPanelView.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI

struct LayersPanelView: View {
    @Environment(\.undoManager) private var undoManager

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
                // Selection must match row identity (UUID)
                guard layers.indices.contains(selectedLayerIndex) else { return Set<UUID>() }
                return Set([layers[selectedLayerIndex].id])
            }, set: { newSelection in
                if let selID = newSelection.first,
                   let idx = layers.firstIndex(where: { $0.id == selID }) {
                    selectedLayerIndex = idx
                } else if !layers.isEmpty {
                    selectedLayerIndex = clampIndex(selectedLayerIndex, for: layers)
                }
            })) {
                ForEach(Array(layers.enumerated()), id: \.1.id) { initialIndex, layer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            if renamingLayerID == layer.id {
                                TextField("Layer", text: Binding(
                                    get: {
                                        if let idx = currentIndex(for: layer.id) {
                                            return layers[idx].name
                                        }
                                        return ""
                                    },
                                    set: { newValue in
                                        guard let idx = currentIndex(for: layer.id) else { return }
                                        let before = layers
                                        layers[idx].name = newValue
                                        let after = layers
                                        registerUndoLayersChange(action: "Rename Layer", before: before, after: after)
                                    }
                                ))
                                .textFieldStyle(.plain)
                                .focused($isRenamingFocused)
                                .onSubmit { finishRenaming() }
                                .onAppear { DispatchQueue.main.async { isRenamingFocused = true } }
                                .onChange(of: isRenamingFocused) { focused in
                                    if !focused && renamingLayerID == layer.id { finishRenaming() }
                                }
                            } else {
                                Text(layerName(for: layer.id))
                                    .lineLimit(1)
                            }

                            Spacer()
                            Button {
                                guard let idx = currentIndex(for: layer.id) else { return }
                                let before = layers
                                layers[idx].isVisible.toggle()
                                let after = layers
                                registerUndoLayersChange(action: layers[idx].isVisible ? "Show Layer" : "Hide Layer", before: before, after: after)
                            } label: {
                                Image(systemName: isVisible(for: layer.id) ? "eye" : "eye.slash")
                                    .foregroundStyle(isVisible(for: layer.id) ? .primary : .secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(isVisible(for: layer.id) ? "Hide layer" : "Show layer")
                        }

                        // Opacity slider
                        HStack {
                            Text("Opacity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: Binding(
                                get: {
                                    opacity(for: layer.id)
                                },
                                set: { newVal in
                                    guard let idx = currentIndex(for: layer.id) else { return }
                                    let before = layers
                                    layers[idx].opacity = newVal
                                    let after = layers
                                    registerUndoLayersChange(action: "Change Layer Opacity", before: before, after: after)
                                }
                            ), in: 0...1)
                        }

                        // Move controls: always visible; enabled based on possible movement in list order.
                        // Up = move toward top of the list (lower index). Down = move toward bottom (higher index).
                        HStack(spacing: 8) {
                            Button {
                                if let idx = currentIndex(for: layer.id) {
                                    moveRowUp(idx)
                                }
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .help("Move layer up")
                            .disabled({
                                guard let idx = currentIndex(for: layer.id) else { return true }
                                return !canMoveRowUp(idx)
                            }())

                            Button {
                                if let idx = currentIndex(for: layer.id) {
                                    moveRowDown(idx)
                                }
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .help("Move layer down")
                            .disabled({
                                guard let idx = currentIndex(for: layer.id) else { return true }
                                return !canMoveRowDown(idx)
                            }())
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background({
                        if let idx = currentIndex(for: layer.id), idx == selectedLayerIndex {
                            Color.accentColor.opacity(0.1)
                        } else {
                            Color.clear
                        }
                    }())
                    .onTapGesture {
                        if let idx = currentIndex(for: layer.id) {
                            selectedLayerIndex = idx
                        }
                    }
                    .contextMenu {
                        Button("Rename") {
                            renamingLayerID = layer.id
                            if let idx = currentIndex(for: layer.id) {
                                selectedLayerIndex = idx
                            }
                        }
                        Button("Delete Layer") {
                            if let idx = currentIndex(for: layer.id) {
                                deleteLayer(at: idx)
                            }
                        }
                        .disabled(layers.count <= 1)
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

    // MARK: - Safe access helpers

    private func currentIndex(for id: UUID) -> Int? {
        layers.firstIndex(where: { $0.id == id })
    }

    private func layerName(for id: UUID) -> String {
        guard let idx = currentIndex(for: id) else { return "" }
        return layers[idx].name
    }

    private func isVisible(for id: UUID) -> Bool {
        guard let idx = currentIndex(for: id) else { return false }
        return layers[idx].isVisible
    }

    private func opacity(for id: UUID) -> Double {
        guard let idx = currentIndex(for: id) else { return 1.0 }
        return layers[idx].opacity
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
        let before = layers
        // Move item at 'index' to 'index - 1'
        layers.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
        let after = layers
        registerUndoLayersChange(action: "Move Layer Up", before: before, after: after)

        // Adjust selection
        if selectedLayerIndex == index {
            selectedLayerIndex = index - 1
        } else if selectedLayerIndex == index - 1 {
            selectedLayerIndex = index
        }
    }

    private func moveRowDown(_ index: Int) {
        guard canMoveRowDown(index) else { return }
        let before = layers
        // Move item at 'index' to just after 'index + 1'
        layers.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
        let after = layers
        registerUndoLayersChange(action: "Move Layer Down", before: before, after: after)

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
        // Allow deletion of any layer as long as at least one remains
        guard layers.count > 1 else { return }

        let before = layers
        let beforeSelection = selectedLayerIndex

        layers.remove(at: index)

        // Maintain a sane selection after deletion
        if selectedLayerIndex == index {
            selectedLayerIndex = min(index, max(0, layers.count - 1))
        } else if selectedLayerIndex > index {
            selectedLayerIndex -= 1
        }

        let after = layers
        let afterSelection = selectedLayerIndex

        registerUndoLayersChange(
            action: "Delete Layer",
            before: before,
            after: after,
            beforeSelection: beforeSelection,
            afterSelection: afterSelection
        )
    }

    // MARK: - Undo helpers

    private func registerUndoLayersChange(action: String, before: [Layer], after: [Layer], beforeSelection: Int? = nil, afterSelection: Int? = nil) {
        let prevSelection = clampIndex(beforeSelection ?? selectedLayerIndex, for: before)
        let nextSelection = clampIndex(afterSelection ?? selectedLayerIndex, for: after)

        registerUndo(action) {
            layers = before
            selectedLayerIndex = prevSelection
        } redo: {
            layers = after
            selectedLayerIndex = nextSelection
        }
    }

    private func clampIndex(_ index: Int, for layers: [Layer]) -> Int {
        return min(max(0, index), max(0, layers.count - 1))
    }

    private func registerUndo(_ actionName: String, undo: @escaping () -> Void, redo: @escaping () -> Void) {
        guard let undoManager = undoManager else { return }

        // Use the UndoManager itself as the AnyObject target and avoid recursive re-registration.
        undoManager.registerUndo(withTarget: undoManager) { _ in
            undo()
            undoManager.setActionName(actionName)
            // Register redo
            undoManager.registerUndo(withTarget: undoManager) { _ in
                redo()
                undoManager.setActionName(actionName)
            }
        }
        undoManager.setActionName(actionName)
    }
}
