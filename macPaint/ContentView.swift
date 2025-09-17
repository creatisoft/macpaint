//  ContentView.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//  this is a github test. 

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
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

    // UI
    @State private var zoom: CGFloat = 1.0

    // Color panel bridging
    @State private var colorPanelTarget = ColorPanelTarget()

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
        }
    }

    // MARK: - Layers management

    private func insertNewLayer(named name: String, at index: Int) {
        let new = Layer(name: name)
        let insertIndex = max(0, min(index, layers.count))
        layers.insert(new, at: insertIndex)
        selectedLayerIndex = insertIndex
    }

    private func addLayer() {
        layerCounter += 1
        let name = "Layer \(layerCounter)"
        insertNewLayer(named: name, at: selectedLayerIndex + 1)
    }

    private func removeSelectedLayer() {
        guard layers.indices.contains(selectedLayerIndex), layers.count > 1 else { return }
        layers.remove(at: selectedLayerIndex)
        selectedLayerIndex = min(selectedLayerIndex, max(0, layers.count - 1))
    }

    private func moveLayers(from offsets: IndexSet, to destination: Int) {
        layers.move(fromOffsets: offsets, toOffset: destination)
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
        canvasSize = CanvasSize(width: CGFloat(w), height: CGFloat(h))
    }

    // MARK: - Actions

    private func clearCanvas() {
        for i in layers.indices {
            layers[i].items.removeAll()
            layers[i].fillColor = nil
        }
        selectedItemID = nil
    }

    private func saveAsPNG() {
        let imageSize = CGSize(width: canvasSize.width, height: canvasSize.height)

        // Render to bitmap
        guard let bitmap = renderBitmap(size: imageSize) else { return }

        // Save panel
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["png"]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Artwork.png"
        panel.isExtensionHidden = false
        panel.title = "Save Canvas"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: url)
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
            guard response == .OK, let url = panel.url, let nsImage = NSImage(contentsOf: url) else { return }

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
            let imageItem = ImageItem(image: nsImage, rect: rect, rotation: 0, scale: .init(width: 1, height: 1))
            let drawable = Drawable.image(imageItem)
            layers[insertIndex].items.append(drawable)

            // Select the new layer and the imported image
            selectedLayerIndex = insertIndex
            selectedItemID = drawable.id

            // Switch to Select tool so the user can immediately resize/move the image
            currentTool = .select
        }
    }
}

#Preview {
    ContentView()
}

