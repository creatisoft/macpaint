//  ContentView.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//  this is a github test. 

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    // Undo
    @Environment(\.undoManager) private var undoManager

    // Layer system
    @State private var layers: [Layer] = []
    @State private var selectedLayerIndex: Int = 0
    @State private var layerCounter: Int = 1

    // Tools and selection
    @State private var currentTool: Tool = .brush
    @State private var brushSize: BrushSize = .medium
    @State private var selectedColor: Color = .black
    @State private var selectedItemID: UUID? = nil

    // Canvas
    @State private var canvasSize: CanvasSize = .medium
    @State private var customWidth: String = "1024"
    @State private var customHeight: String = "768"
    @State private var backgroundColor: Color = .white
    @State private var lastBackgroundColorForUndo: Color = .white

    // UI
    @State private var zoom: CGFloat = 1.0

    // Color panel bridging
    @StateObject private var colorPanelTarget = ColorPanelTarget()

    private let palette: [Color] = [
        .black, .gray, .red, .orange, .yellow,
        .green, .mint, .teal, .blue, .purple
    ]

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(
                brushSize: $brushSize,
                selectedColor: $selectedColor,
                palette: palette,
                customWidth: $customWidth,
                customHeight: $customHeight,
                applyCustomSize: applyCustomSize,
                backgroundColor: $backgroundColor,
                zoom: $zoom,
                clearCanvas: clearCanvas,
                saveAction: saveAsPNG,
                openSystemColorPanel: openSystemColorPanel
            )

            HStack(spacing: 0) {
                ToolsPanelView(currentTool: $currentTool, importImageAction: importImage)

                CanvasView(
                    layers: $layers,
                    selectedLayerIndex: $selectedLayerIndex,
                    currentTool: $currentTool,
                    brushSize: $brushSize,
                    selectedColor: $selectedColor,
                    selectedItemID: $selectedItemID,
                    canvasSize: $canvasSize,
                    backgroundColor: $backgroundColor,
                    zoom: $zoom
                )

                LayersPanelView(
                    layers: $layers,
                    selectedLayerIndex: $selectedLayerIndex,
                    addLayer: addLayer,
                    removeSelectedLayer: removeSelectedLayer,
                    moveLayers: moveLayers
                )
            }
        }
        .onAppear {
            customWidth = String(Int(canvasSize.width))
            customHeight = String(Int(canvasSize.height))
            initializeLayers()
            lastBackgroundColorForUndo = backgroundColor
        }
        // Background color undo registration (coarse; fires frequently during dragging)
        .onChange(of: backgroundColor) { newValue in
            let previous = lastBackgroundColorForUndo
            registerUndo("Change Background Color") {
                backgroundColor = previous
            } redo: {
                backgroundColor = newValue
            }
            lastBackgroundColorForUndo = newValue
        }
    }

    // MARK: - Undo helpers

    private func registerUndo(_ actionName: String, undo: @escaping () -> Void, redo: (() -> Void)? = nil) {
        undoManager?.registerUndo(withTarget: VoidBox { undo() }) { box in
            let oldRedo = redo
            undo() // perform undo
            self.undoManager?.setActionName(actionName)
            if let oldRedo {
                // Register redo as the inverse
                self.undoManager?.registerUndo(withTarget: VoidBox { oldRedo() }) { redoBox in
                    oldRedo()
                    self.undoManager?.setActionName(actionName)
                    // Re-register undo again
                    self.registerUndo(actionName, undo: undo, redo: oldRedo)
                }
            }
        }
        undoManager?.setActionName(actionName)
    }

    // Simple wrapper so we can use registerUndo with closures easily
    private final class VoidBox {
        let action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
    }

    // MARK: - Layers management

    private func insertNewLayer(named name: String, at index: Int) {
        let beforeLayers = layers
        let beforeSelection = selectedLayerIndex

        let new = Layer(name: name)
        let insertIndex = max(0, min(index, layers.count))
        layers.insert(new, at: insertIndex)
        selectedLayerIndex = insertIndex

        let afterLayers = layers
        let afterSelection = selectedLayerIndex

        registerUndo("Insert Layer") {
            layers = beforeLayers
            selectedLayerIndex = beforeSelection
        } redo: {
            layers = afterLayers
            selectedLayerIndex = afterSelection
        }
    }

    private func addLayer() {
        layerCounter += 1
        let name = "Layer \(layerCounter)"
        insertNewLayer(named: name, at: selectedLayerIndex + 1)
    }

    private func removeSelectedLayer() {
        guard layers.count > 1, layers.indices.contains(selectedLayerIndex) else { return }
        let beforeLayers = layers
        let beforeSelection = selectedLayerIndex

        layers.remove(at: selectedLayerIndex)
        selectedLayerIndex = min(selectedLayerIndex, layers.count - 1)

        let afterLayers = layers
        let afterSelection = selectedLayerIndex

        registerUndo("Delete Layer") {
            layers = beforeLayers
            selectedLayerIndex = beforeSelection
        } redo: {
            layers = afterLayers
            selectedLayerIndex = afterSelection
        }
    }

    private func moveLayers(from offsets: IndexSet, to destination: Int) {
        let beforeLayers = layers
        let beforeSelection = selectedLayerIndex

        layers.move(fromOffsets: offsets, toOffset: destination)

        let afterLayers = layers
        let afterSelection = selectedLayerIndex

        registerUndo("Move Layers") {
            layers = beforeLayers
            selectedLayerIndex = beforeSelection
        } redo: {
            layers = afterLayers
            selectedLayerIndex = afterSelection
        }
    }

    private func initializeLayers() {
        layers = [Layer(name: "Layer 1")]
        layerCounter = 1
        selectedLayerIndex = 0
    }

    // MARK: - Canvas sizing

    private func applyCustomSize() {
        guard let w = Double(customWidth), let h = Double(customHeight),
              w > 0, h > 0, w <= 10000, h <= 10000 else { return }

        let before = canvasSize
        let newSize = CanvasSize(width: CGFloat(w), height: CGFloat(h))
        canvasSize = newSize

        registerUndo("Change Canvas Size") {
            canvasSize = before
            customWidth = String(Int(before.width))
            customHeight = String(Int(before.height))
        } redo: {
            canvasSize = newSize
            customWidth = String(Int(newSize.width))
            customHeight = String(Int(newSize.height))
        }
    }

    // MARK: - Actions

    private func clearCanvas() {
        let beforeLayers = layers
        let beforeSelection = selectedItemID

        layers.indices.forEach { index in
            layers[index].items.removeAll()
            layers[index].fillColor = nil
        }
        selectedItemID = nil

        let afterLayers = layers
        let afterSelection = selectedItemID

        registerUndo("Clear Canvas") {
            layers = beforeLayers
            selectedItemID = beforeSelection
        } redo: {
            layers = afterLayers
            selectedItemID = afterSelection
        }
    }

    private func saveAsPNG() {
        let imageSize = CGSize(width: canvasSize.width, height: canvasSize.height)

        // Render to bitmap
        guard let bitmap = renderBitmap(size: imageSize) else { 
            print("Failed to render bitmap for save operation")
            return 
        }

        // Save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Artwork.png"
        panel.isExtensionHidden = false
        panel.title = "Save Canvas"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try data.write(to: url)
                } else {
                    print("Failed to create PNG data from bitmap")
                }
            } catch {
                print("Failed to save file: \(error.localizedDescription)")
            }
        }
    }

    // Render into an NSBitmapImageRep using a CG context that matches SwiftUI's y-down coordinates.
    // This ensures exact pixel parity with what Canvas draws (including layer order and eraser blend).
    private func renderBitmap(size: CGSize) -> NSBitmapImageRep? {
        let scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelWidth = max(1, Int(round(size.width * scale)))
        let pixelHeight = max(1, Int(round(size.height * scale)))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        guard let nsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        let cg = nsContext.cgContext
        cg.saveGState()

        // Match SwiftUI Canvas (y-down). First scale to pixels, then flip vertically.
        cg.scaleBy(x: scale, y: scale)
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: 1, y: -1)

        // High-quality strokes
        cg.setAllowsAntialiasing(true)
        cg.setShouldAntialias(true)
        cg.interpolationQuality = .high

        // Background
        cg.setFillColor(MacColorBridge.nsColor(from: backgroundColor).cgColor)
        cg.fill(CGRect(origin: .zero, size: size))

        // Draw items by visible layers with opacity, in the same order as CanvasView,
        // using a transparency layer per layer so destinationOut erasers are scoped.
        for layer in layers {
            guard layer.isVisible else { continue }
            cg.beginTransparencyLayer(auxiliaryInfo: nil)

            // Per-layer fill (under items)
            if let fill = layer.fillColor {
                let nsFill = MacColorBridge.nsColor(from: fill).withAlphaComponent(layer.opacity)
                cg.setFillColor(nsFill.cgColor)
                cg.fill(CGRect(origin: .zero, size: size))
            }

            for item in layer.items {
                item.drawToNSContext(layerOpacity: layer.opacity)
            }
            cg.endTransparencyLayer()
        }

        cg.restoreGState()
        NSGraphicsContext.restoreGraphicsState()

        return bitmap
    }

    // MARK: - Color Panel

    private func openSystemColorPanel() {
        colorPanelTarget.onChange = { nsColor in
            selectedColor = Color(nsColor: nsColor)
        }

        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.setTarget(colorPanelTarget)
        panel.setAction(#selector(ColorPanelTarget.colorPanelDidChange(_:)))
        panel.orderFront(nil)
        panel.makeKey()
    }

    // MARK: - Import Image

    private func importImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType.image]
        } else {
            panel.allowedFileTypes = ["png", "jpg", "jpeg", "tiff", "gif", "bmp", "heic"]
        }
        panel.title = "Import Image"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url),
                  let nsImage = NSImage(data: data) else { return }

            let beforeLayers = layers
            let beforeSelectionLayer = selectedLayerIndex
            let beforeSelectedItem = selectedItemID

            // Compute a target rect that fits the image nicely within the canvas (max 70% of canvas)
            let canvasW = canvasSize.width
            let canvasH = canvasSize.height
            let maxW = canvasW * 0.7
            let maxH = canvasH * 0.7

            let imgSize = nsImage.size
            let scale = min(maxW / max(1, imgSize.width), maxH / max(1, imgSize.height), 1.0)
            let drawW = imgSize.width * scale
            let drawH = imgSize.height * scale
            let rect = CGRect(
                x: (canvasW - drawW) / 2.0,
                y: (canvasH - drawH) / 2.0,
                width: drawW,
                height: drawH
            )

            // Create a new layer above the current one
            layerCounter += 1
            let newLayerName = "Image \(layerCounter)"
            let insertIndex = min(selectedLayerIndex + 1, layers.count)
            insertNewLayer(named: newLayerName, at: insertIndex)

            // Create the image item and add to the new layer
            let imageItem = ImageItem(imageData: data, rect: rect, rotation: 0, scale: .init(width: 1, height: 1))
            let drawable = Drawable.image(imageItem)
            layers[insertIndex].items.append(drawable)

            // Select the new layer and the imported image
            selectedLayerIndex = insertIndex
            selectedItemID = drawable.id

            // Switch to Select tool so the user can immediately resize/move the image
            currentTool = .select

            let afterLayers = layers
            let afterSelectionLayer = selectedLayerIndex
            let afterSelectedItem = selectedItemID

            registerUndo("Import Image") {
                layers = beforeLayers
                selectedLayerIndex = beforeSelectionLayer
                selectedItemID = beforeSelectedItem
            } redo: {
                layers = afterLayers
                selectedLayerIndex = afterSelectionLayer
                selectedItemID = afterSelectedItem
            }
        }
    }
}

#Preview {
    ContentView()
}

