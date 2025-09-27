//  CanvasView.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI
import AppKit

struct CanvasView: View {
    // External state
    @Binding var layers: [Layer]
    @Binding var selectedLayerIndex: Int
    @Binding var currentTool: Tool
    @Binding var brushSize: BrushSize
    @Binding var selectedColor: Color
    @Binding var selectedItemID: UUID?
    @Binding var canvasSize: CanvasSize
    @Binding var backgroundColor: Color
    @Binding var zoom: CGFloat

    // Internal interaction state
    @State private var currentStroke: StrokeItem? = nil
    @State private var currentShapeStart: CGPoint? = nil
    @State private var currentTempDrawable: Drawable? = nil
    @State private var isDragging: Bool = false

    // Force Canvas re-evaluation each drag update
    @State private var dragTick: Int = 0

    // Geometry tracking for accurate pointer-to-canvas mapping
    @State private var canvasFrameInScroll: CGRect = .zero
    private let scrollCoordinateSpace = "scrollArea"

    // Selection/move interaction helpers
    private let overlayHandleSize: CGFloat = 8
    private let hitHandleSize: CGFloat = 12
    private let selectHitTolerance: CGFloat = 12

    @State private var lastDragLocationInScroll: CGPoint? = nil
    @State private var activeHandle: SelectionHandle? = nil
    @State private var originalItemState: Drawable? = nil

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            ScrollView([.horizontal, .vertical]) {
                drawingSurface
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .coordinateSpace(name: scrollCoordinateSpace)
            }
        }
    }

    private var drawingSurface: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .frame(width: canvasSize.width, height: canvasSize.height)

            Canvas { context, _ in
                // Explicitly read these so Canvas recomputes on every drag tick and while dragging
                _ = isDragging
                _ = dragTick

                // Draw each visible layer in order; scope in-progress content to its layer
                for (i, layer) in layers.enumerated() {
                    guard layer.isVisible else { continue }
                    context.drawLayer { layerContext in
                        // Per-layer fill (under items)
                        if let fill = layer.fillColor, fill != .clear {
                            let rect = CGRect(origin: .zero, size: CGSize(width: canvasSize.width, height: canvasSize.height))
                            let path = Path(rect)
                            layerContext.fill(path, with: .color(fill.opacity(layer.opacity)))
                        }

                        // Existing committed items
                        for item in layer.items {
                            item.draw(in: layerContext, layerOpacity: layer.opacity)
                        }

                        // In-progress temp drawable (line/rect/ellipse) scoped to selected layer
                        if i == selectedLayerIndex, let temp = currentTempDrawable {
                            temp.draw(in: layerContext, layerOpacity: layer.opacity)
                        }

                        // In-progress stroke (brush/eraser) scoped to selected layer
                        if i == selectedLayerIndex, let s = currentStroke {
                            let tempStroke = Drawable.stroke(s)
                            tempStroke.draw(in: layerContext, layerOpacity: layer.opacity)
                        }
                    }
                }

                // Selection overlay drawn on top (skip eraser strokes)
                if let sel = selectedItem(), layers.indices.contains(selectedLayerIndex) {
                    drawSelectionOverlay(for: sel, in: context)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .clipped()
        }
        .background(
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(scrollCoordinateSpace))
                Color.clear
                    .onChange(of: frame) { newValue in canvasFrameInScroll = newValue }
                    .onAppear { canvasFrameInScroll = frame }
            }
        )
        .scaleEffect(zoom, anchor: .center)
        .animation(.easeInOut(duration: 0.2), value: canvasSize)
        .animation(.easeInOut(duration: 0.2), value: zoom)
        .gesture(primaryGesture())
    }

    private func drawSelectionOverlay(for item: Drawable, in context: GraphicsContext) {
        // Safety: never show overlay for eraser strokes
        if case .stroke(let s) = item, s.isEraser { return }

        let box = item.boundingBox()
        var path = Path(roundedRect: box.insetBy(dx: -4, dy: -4), cornerRadius: 4)
        context.stroke(path, with: .color(.accentColor), lineWidth: 1)

        // 8 resize handles
        let handles: [CGPoint] = [
            CGPoint(x: box.minX, y: box.minY),
            CGPoint(x: box.midX, y: box.minY),
            CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.maxX, y: box.midY),
            CGPoint(x: box.maxX, y: box.maxY),
            CGPoint(x: box.midX, y: box.maxY),
            CGPoint(x: box.minX, y: box.maxY),
            CGPoint(x: box.minX, y: box.midY)
        ]
        for c in handles {
            let rect = CGRect(x: c.x - overlayHandleSize/2, y: c.y - overlayHandleSize/2, width: overlayHandleSize, height: overlayHandleSize)
            path = Path(roundedRect: rect, cornerRadius: 2)
            context.fill(path, with: .color(.accentColor))
        }

        // Rotation handle
        let rotCenter = CGPoint(x: box.midX, y: box.minY - 16)
        let rotRect = CGRect(x: rotCenter.x - overlayHandleSize/2, y: rotCenter.y - overlayHandleSize/2, width: overlayHandleSize, height: overlayHandleSize)
        path = Path(roundedRect: rotRect, cornerRadius: 2)
        context.fill(path, with: .color(.accentColor))
        var connector = Path()
        connector.move(to: CGPoint(x: box.midX, y: box.minY))
        connector.addLine(to: rotCenter)
        context.stroke(connector, with: .color(.accentColor), lineWidth: 1)
    }

    private func primaryGesture() -> some Gesture {
        DragGesture(minimumDistance: 0.1, coordinateSpace: .named(scrollCoordinateSpace))
            .onChanged { handleDragChanged($0) }
            .onEnded { handleDragEnded($0) }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        let locationInScroll = value.location
        let point = logicalPoint(from: locationInScroll)

        switch currentTool {
        case .brush, .eraser:
            beginStrokeIfNeeded(at: point)
            currentStroke?.points.append(point)
            isDragging = true

        case .line, .rectangle, .ellipse:
            if currentShapeStart == nil { currentShapeStart = point }
            updateTempShape(to: point)
            isDragging = true

        case .select:
            // Treat the first onChanged as "drag start"
            if lastDragLocationInScroll == nil {
                // If we started on a different item than currently selected, select it immediately
                if let (idx, id) = hitTest(point: point, tolerance: selectHitTolerance) {
                    if selectedItemID != id || selectedLayerIndex != idx {
                        selectedLayerIndex = idx
                        selectedItemID = id
                        touchLayers() // ensure overlay updates immediately
                    }
                }
                lastDragLocationInScroll = locationInScroll
            }

            guard let selectedItem = selectedItem() else {
                incrementDragTick()
                return
            }

            // If a handle is under the pointer and not yet active, activate it on drag start
            if activeHandle == nil, let handle = getHandleAt(point: point, for: selectedItem) {
                activeHandle = handle
                originalItemState = selectedItem
                isDragging = true
                touchLayers()
                incrementDragTick()
                return
            }

            if let handle = activeHandle, let original = originalItemState {
                manipulateItem(original: original, handle: handle, currentPoint: point)
                isDragging = true
            } else if let previous = lastDragLocationInScroll, let selIndex = indexOfSelectedItem() {
                // Move the selected item
                let dxScroll = locationInScroll.x - previous.x
                let dyScroll = locationInScroll.y - previous.y
                let z = max(zoom, .leastNonzeroMagnitude)
                let logicalDelta = CGSize(width: dxScroll / z, height: dyScroll / z)
                moveItem(at: selIndex, by: logicalDelta)
                isDragging = true
            }
            lastDragLocationInScroll = locationInScroll

        case .bucket:
            // No drag preview for bucket; do nothing on change
            break
        }

        // Force Canvas to recompute this frame
        incrementDragTick()
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        activeHandle = nil
        originalItemState = nil

        let locationInScroll = value.location
        let point = logicalPoint(from: locationInScroll)

        switch currentTool {
        case .brush, .eraser:
            if let s = currentStroke {
                if s.isEraser {
                    // Find the topmost item hit by any point along the eraser stroke
                    let tol = max(2, s.style.lineWidth / 2)
                    var hit: (Int, UUID)? = nil
                    for p in s.points {
                        if let res = hitTest(point: p, tolerance: tol) {
                            hit = res
                            break
                        }
                    }

                    if let (hitLayerIndex, hitID) = hit,
                       layers.indices.contains(hitLayerIndex),
                       let itemIndex = layers[hitLayerIndex].items.firstIndex(where: { $0.id == hitID }) {
                        attachEraserStroke(s, toItemAt: (hitLayerIndex, itemIndex))
                        // Selection stays as-is; eraser is not selectable
                    } else {
                        // No item hit anywhere along the stroke: keep a layer-level eraser
                        appendItem(.stroke(s))
                    }
                } else {
                    appendItem(.stroke(s))
                }
                currentStroke = nil
            }

        case .line:
            if case .line(let l)? = currentTempDrawable {
                appendItem(.line(l))
                currentTempDrawable = nil
                currentShapeStart = nil
            }

        case .rectangle:
            if case .rect(let r)? = currentTempDrawable {
                appendItem(.rect(r))
                currentTempDrawable = nil
                currentShapeStart = nil
            }

        case .ellipse:
            if case .ellipse(let e)? = currentTempDrawable {
                appendItem(.ellipse(e))
                currentTempDrawable = nil
                currentShapeStart = nil
            }

        case .select:
            if value.translation == .zero {
                if let (idx, id) = hitTest(point: point, tolerance: selectHitTolerance) {
                    selectedLayerIndex = idx
                    selectedItemID = id
                    touchLayers()
                } else {
                    selectedItemID = nil
                    touchLayers()
                }
            }
            lastDragLocationInScroll = nil

        case .bucket:
            applyBucketFill(at: point)
        }
        isDragging = false
        incrementDragTick()
    }

    // MARK: - Helpers

    private func incrementDragTick() {
        // Wrap to avoid overflow in long sessions
        dragTick &+= 1
    }

    // Force a visible change to the layers binding to invalidate Canvas
    private func touchLayers() {
        layers = Array(layers)
    }

    private func beginStrokeIfNeeded(at point: CGPoint) {
        guard currentStroke == nil else { return }
        let isEraserStroke = currentTool == .eraser
        let color = isEraserStroke ? .clear : selectedColor
        currentStroke = StrokeItem(
            points: [point],
            style: .init(color: color, lineWidth: brushSize.rawValue),
            isEraser: isEraserStroke
        )
        selectedItemID = nil
    }

    private func updateTempShape(to point: CGPoint) {
        guard let start = currentShapeStart else { return }
        switch currentTool {
        case .line:
            let line = LineItem(
                start: start,
                end: point,
                style: .init(color: selectedColor, lineWidth: brushSize.rawValue)
            )
            currentTempDrawable = .line(line)

        case .rectangle:
            let rect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )
            let item = RectItem(rect: rect, style: .init(color: selectedColor, lineWidth: brushSize.rawValue))
            currentTempDrawable = .rect(item)

        case .ellipse:
            let rect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )
            let item = EllipseItem(rect: rect, style: .init(color: selectedColor, lineWidth: brushSize.rawValue))
            currentTempDrawable = .ellipse(item)

        default:
            break
        }
    }

    private func logicalPoint(from locationInScroll: CGPoint) -> CGPoint {
        let origin = CGPoint(x: canvasFrameInScroll.midX, y: canvasFrameInScroll.midY)
        let translated = CGPoint(x: locationInScroll.x - origin.x, y: locationInScroll.y - origin.y)
        let z = max(zoom, .leastNonzeroMagnitude)
        let logicalLocal = CGPoint(x: translated.x / z, y: translated.y / z)
        return CGPoint(x: logicalLocal.x + canvasSize.width / 2, y: logicalLocal.y + canvasSize.height / 2)
    }

    private func selectedItem() -> Drawable? {
        guard layers.indices.contains(selectedLayerIndex) else { return nil }
        let item = layers[selectedLayerIndex].items.first(where: { $0.id == selectedItemID })
        // Safety: treat eraser strokes as non-selectable
        if case .stroke(let s)? = item, s.isEraser { return nil }
        return item
    }

    private func indexOfSelectedItem() -> (layer: Int, item: Int)? {
        guard layers.indices.contains(selectedLayerIndex),
              let id = selectedItemID else { return nil }
        let items = layers[selectedLayerIndex].items
        if let idx = items.firstIndex(where: { $0.id == id }) {
            return (selectedLayerIndex, idx)
        }
        return nil
    }

    private func moveItem(at index: (layer: Int, item: Int), by delta: CGSize) {
        guard layers.indices.contains(index.layer),
              layers[index.layer].items.indices.contains(index.item) else { return }

        var layer = layers[index.layer]
        var item = layer.items[index.item]

        // Never move eraser strokes (they are treated as permanent erasures)
        if case .stroke(let s) = item, s.isEraser {
            return
        }

        switch item {
        case .stroke(var s):
            s.points = s.points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
            // Move item-local erasers with the stroke
            s.erasers = s.erasers.map { er in
                var er = er
                er.points = er.points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
                return er
            }
            item = .stroke(s)
        case .rect(var r):
            r.rect = r.rect.offsetBy(dx: delta.width, dy: delta.height)
            // Erasers are stored in item-local, unrotated space, but as absolute points; translate them too.
            if !r.erasers.isEmpty {
                r.erasers = r.erasers.map { er in
                    var er = er
                    er.points = er.points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
                    return er
                }
            }
            item = .rect(r)
        case .ellipse(var e):
            e.rect = e.rect.offsetBy(dx: delta.width, dy: delta.height)
            if !e.erasers.isEmpty {
                e.erasers = e.erasers.map { er in
                    var er = er
                    er.points = er.points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
                    return er
                }
            }
            item = .ellipse(e)
        case .line(var l):
            l.start = CGPoint(x: l.start.x + delta.width, y: l.start.y + delta.height)
            l.end = CGPoint(x: l.end.x + delta.width, y: l.end.y + delta.height)
            // Line erasers are in canvas space; translate them to move together with the line.
            if !l.erasers.isEmpty {
                l.erasers = l.erasers.map { er in
                    var er = er
                    er.points = er.points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
                    return er
                }
            }
            item = .line(l)
        case .image(var i):
            i.rect = i.rect.offsetBy(dx: delta.width, dy: delta.height)
            if !i.erasers.isEmpty {
                i.erasers = i.erasers.map { er in
                    var er = er
                    er.points = er.points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
                    return er
                }
            }
            item = .image(i)
        }

        layer.items[index.item] = item
        layers[index.layer] = layer
    }

    private func hitTest(point: CGPoint, tolerance: CGFloat) -> (Int, UUID)? {
        for layerIndex in layers.indices.reversed() {
            let layer = layerIndex < layers.count ? layers[layerIndex] : nil
            guard let layer, layer.isVisible else { continue }
            for itemIndex in layer.items.indices.reversed() {
                let drawable = layer.items[itemIndex]

                // Skip eraser strokes for selection/hit-testing
                if case .stroke(let s) = drawable, s.isEraser { continue }

                if drawable.hitTest(point: point, tolerance: tolerance) {
                    return (layerIndex, drawable.id)
                }
            }
        }
        return nil
    }

    private func appendItem(_ item: Drawable) {
        guard layers.indices.contains(selectedLayerIndex) else { return }
        var layer = layers[selectedLayerIndex]
        layer.items.append(item)
        layers[selectedLayerIndex] = layer
    }

    private func getHandleAt(point: CGPoint, for item: Drawable) -> SelectionHandle? {
        let box = item.boundingBox()
        let handles: [(SelectionHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: box.minX, y: box.minY)),
            (.topCenter, CGPoint(x: box.midX, y: box.minY)),
            (.topRight, CGPoint(x: box.maxX, y: box.minY)),
            (.rightCenter, CGPoint(x: box.maxX, y: box.midY)),
            (.bottomRight, CGPoint(x: box.maxX, y: box.maxY)),
            (.bottomCenter, CGPoint(x: box.midX, y: box.maxY)),
            (.bottomLeft, CGPoint(x: box.minX, y: box.maxY)),
            (.leftCenter, CGPoint(x: box.minX, y: box.midY)),
            (.rotation, CGPoint(x: box.midX, y: box.minY - 20))
        ]
        for (handle, center) in handles {
            let hitRect = CGRect(x: center.x - hitHandleSize/2, y: center.y - hitHandleSize/2, width: hitHandleSize, height: hitHandleSize)
            if hitRect.contains(point) {
                return handle
            }
        }
        return nil
    }

    private func manipulateItem(original: Drawable, handle: SelectionHandle, currentPoint: CGPoint) {
        guard let selIndex = indexOfSelectedItem(),
              layers.indices.contains(selIndex.layer),
              layers[selIndex.layer].items.indices.contains(selIndex.item) else { return }

        var layer = layers[selIndex.layer]
        let originalBox = original.boundingBox()
        var newItem = original

        switch handle {
        case .rotation:
            let center = CGPoint(x: originalBox.midX, y: originalBox.midY)
            let angle = atan2(currentPoint.y - center.y, currentPoint.x - center.x)

            switch newItem {
            case .rect(var r):
                r.rotation = angle
                newItem = .rect(r)
            case .ellipse(var e):
                e.rotation = angle
                newItem = .ellipse(e)
            case .line(var l):
                let c = CGPoint(x: (l.start.x + l.end.x) / 2, y: (l.start.y + l.end.y) / 2)
                func rotate(_ p: CGPoint, around c: CGPoint, by theta: CGFloat) -> CGPoint {
                    let dx = p.x - c.x, dy = p.y - c.y
                    let cosT = cos(theta), sinT = sin(theta)
                    return CGPoint(x: c.x + dx * cosT - dy * sinT, y: c.y + dx * sinT + dy * cosT)
                }
                l.start = rotate(l.start, around: c, by: angle)
                l.end = rotate(l.end, around: c, by: angle)
                // Rotate line erasers (stored in canvas space) around the same center
                if !l.erasers.isEmpty {
                    l.erasers = l.erasers.map { er in
                        var er = er
                        er.points = er.points.map { rotate($0, around: c, by: angle) }
                        return er
                    }
                }
                newItem = .line(l)
            case .image(var i):
                i.rotation = angle
                newItem = .image(i)
            default: break
            }

        case .topLeft, .topRight, .bottomLeft, .bottomRight, .topCenter, .bottomCenter, .leftCenter, .rightCenter:
            switch newItem {
            case .rect(var r):
                let updated = rectByDraggingHandle(handle, from: originalBox, to: currentPoint)
                r.rect = updated
                r.scale = .init(width: 1, height: 1)
                newItem = .rect(r)
            case .ellipse(var e):
                let updated = rectByDraggingHandle(handle, from: originalBox, to: currentPoint)
                e.rect = updated
                e.scale = .init(width: 1, height: 1)
                newItem = .ellipse(e)
            case .line(var l):
                let anchor: CGPoint
                switch handle {
                case .topLeft: anchor = CGPoint(x: originalBox.maxX, y: originalBox.maxY)
                case .topRight: anchor = CGPoint(x: originalBox.minX, y: originalBox.maxY)
                case .bottomLeft: anchor = CGPoint(x: originalBox.maxX, y: originalBox.minY)
                case .bottomRight: anchor = CGPoint(x: originalBox.minX, y: originalBox.minY)
                case .topCenter: anchor = CGPoint(x: originalBox.midX, y: originalBox.maxY)
                case .bottomCenter: anchor = CGPoint(x: originalBox.midX, y: originalBox.minY)
                case .leftCenter: anchor = CGPoint(x: originalBox.maxX, y: originalBox.midY)
                case .rightCenter: anchor = CGPoint(x: originalBox.minX, y: originalBox.midY)
                default: anchor = CGPoint(x: (l.start.x + l.end.x)/2, y: (l.start.y + l.end.y)/2)
                }
                let sx: CGFloat
                let sy: CGFloat
                switch handle {
                case .topLeft:
                    sx = max(0.1, (originalBox.maxX - currentPoint.x) / max(originalBox.width, .leastNonzeroMagnitude))
                    sy = max(0.1, (originalBox.maxY - currentPoint.y) / max(originalBox.height, .leastNonzeroMagnitude))
                case .topRight:
                    sx = max(0.1, (currentPoint.x - originalBox.minX) / max(originalBox.width, .leastNonzeroMagnitude))
                    sy = max(0.1, (originalBox.maxY - currentPoint.y) / max(originalBox.height, .leastNonzeroMagnitude))
                case .bottomLeft:
                    sx = max(0.1, (originalBox.maxX - currentPoint.x) / max(originalBox.width, .leastNonzeroMagnitude))
                    sy = max(0.1, (currentPoint.y - originalBox.minY) / max(originalBox.height, .leastNonzeroMagnitude))
                case .bottomRight:
                    sx = max(0.1, (currentPoint.x - originalBox.minX) / max(originalBox.width, .leastNonzeroMagnitude))
                    sy = max(0.1, (currentPoint.y - originalBox.minY) / max(originalBox.height, .leastNonzeroMagnitude))
                case .topCenter:
                    sx = 1.0
                    sy = max(0.1, (originalBox.maxY - currentPoint.y) / max(originalBox.height, .leastNonzeroMagnitude))
                case .bottomCenter:
                    sx = 1.0
                    sy = max(0.1, (currentPoint.y - originalBox.minY) / max(originalBox.height, .leastNonzeroMagnitude))
                case .leftCenter:
                    sx = max(0.1, (originalBox.maxX - currentPoint.x) / max(originalBox.width, .leastNonzeroMagnitude))
                    sy = 1.0
                case .rightCenter:
                    sx = max(0.1, (currentPoint.x - originalBox.minX) / max(originalBox.width, .leastNonzeroMagnitude))
                    sy = 1.0
                default:
                    sx = 1; sy = 1
                }
                func scalePoint(_ p: CGPoint, around a: CGPoint, sx: CGFloat, sy: CGFloat) -> CGPoint {
                    let dx = p.x - a.x, dy = p.y - a.y
                    return CGPoint(x: a.x + dx * sx, y: a.y + dy * sy)
                }
                l.start = scalePoint(l.start, around: anchor, sx: sx, sy: sy)
                l.end = scalePoint(l.end, around: anchor, sx: sx, sy: sy)
                // Scale line erasers with the same anchor and factors
                if !l.erasers.isEmpty {
                    l.erasers = l.erasers.map { er in
                        var er = er
                        er.points = er.points.map { scalePoint($0, around: anchor, sx: sx, sy: sy) }
                        return er
                    }
                }
                newItem = .line(l)
            case .image(var i):
                let updated = rectByDraggingHandle(handle, from: originalBox, to: currentPoint)
                i.rect = updated
                i.scale = .init(width: 1, height: 1)
                newItem = .image(i)
            default:
                break
            }
        }

        layer.items[selIndex.item] = newItem
        layers[selIndex.layer] = layer
    }

    private func rectByDraggingHandle(_ handle: SelectionHandle, from original: CGRect, to p: CGPoint) -> CGRect {
        switch handle {
        case .topLeft:
            return CGRect(x: min(p.x, original.maxX), y: min(p.y, original.maxY), width: abs(original.maxX - p.x), height: abs(original.maxY - p.y))
        case .topRight:
            return CGRect(x: min(original.minX, p.x), y: min(p.y, original.maxY), width: abs(p.x - original.minX), height: abs(original.maxY - p.y))
        case .bottomLeft:
            return CGRect(x: min(p.x, original.maxX), y: min(original.minY, p.y), width: abs(original.maxX - p.x), height: abs(p.y - original.minY))
        case .bottomRight:
            return CGRect(x: min(original.minX, p.x), y: min(original.minY, p.y), width: abs(p.x - original.minX), height: abs(p.y - original.minY))
        case .topCenter:
            return CGRect(x: original.minX, y: min(p.y, original.maxY), width: original.width, height: abs(original.maxY - p.y))
        case .bottomCenter:
            return CGRect(x: original.minX, y: min(original.minY, p.y), width: original.width, height: abs(p.y - original.minY))
        case .leftCenter:
            return CGRect(x: min(p.x, original.maxX), y: original.minY, width: abs(original.maxX - p.x), height: original.height)
        case .rightCenter:
            return CGRect(x: min(original.minX, p.x), y: original.minY, width: abs(p.x - original.minX), height: original.height)
        case .rotation:
            return original
        }
    }

    // MARK: - Bucket

    private func applyBucketFill(at point: CGPoint) {
        // Try to find the topmost hit item
        if let (layerIndex, id) = hitTest(point: point, tolerance: 0),
           layers.indices.contains(layerIndex) {
            var layer = layers[layerIndex]
            if let itemIndex = layer.items.firstIndex(where: { $0.id == id }) {
                var item = layer.items[itemIndex]
                var filledShape = false

                switch item {
                case .rect(var r):
                    r.fill = selectedColor
                    item = .rect(r)
                    filledShape = true
                case .ellipse(var e):
                    e.fill = selectedColor
                    item = .ellipse(e)
                    filledShape = true
                default:
                    // Non-fillable item: set the layer's background color instead
                    filledShape = false
                }

                if filledShape {
                    layer.items[itemIndex] = item
                } else {
                    layer.fillColor = selectedColor
                }

                layers[layerIndex] = layer
                selectedLayerIndex = layerIndex
                selectedItemID = filledShape ? id : nil
                touchLayers()
                return
            }
        }

        // No item hit: set the selected layer's background color
        if layers.indices.contains(selectedLayerIndex) {
            layers[selectedLayerIndex].fillColor = selectedColor
            selectedItemID = nil
            touchLayers()
        }
    }

    // MARK: - Eraser attach

    private func attachEraserStroke(_ stroke: StrokeItem, toItemAt index: (layer: Int, item: Int)) {
        guard layers.indices.contains(index.layer),
              layers[index.layer].items.indices.contains(index.item) else { return }
        var layer = layers[index.layer]
        var item = layer.items[index.item]

        let lineWidth = stroke.style.lineWidth
        let points = stroke.points

        func toEraser(points: [CGPoint]) -> EraserStroke {
            EraserStroke(points: points, lineWidth: lineWidth)
        }

        switch item {
        case .stroke(var s):
            // Stroke has no rotation property; erasers are stored in canvas coords and translated with the stroke
            s.erasers.append(toEraser(points: points))
            item = .stroke(s)

        case .rect(var r):
            // Convert points into item-local (unrotated) space so eraser rotates with the rect
            let rect = r.rect.scaled(by: r.scale)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let theta = r.rotation
            let local = points.map { rotatePoint($0, around: center, by: -theta) }
            r.erasers.append(toEraser(points: local))
            item = .rect(r)

        case .ellipse(var e):
            let rect = e.rect.scaled(by: e.scale)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let theta = e.rotation
            let local = points.map { rotatePoint($0, around: center, by: -theta) }
            e.erasers.append(toEraser(points: local))
            item = .ellipse(e)

        case .line(var l):
            // Lines have no persisted rotation; store in canvas coords
            l.erasers.append(toEraser(points: points))
            item = .line(l)

        case .image(var i):
            let rect = i.rect.scaled(by: i.scale)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let theta = i.rotation
            let local = points.map { rotatePoint($0, around: center, by: -theta) }
            i.erasers.append(toEraser(points: local))
            item = .image(i)
        }

        layer.items[index.item] = item
        layers[index.layer] = layer
        selectedLayerIndex = index.layer
        selectedItemID = item.id
        touchLayers()
    }

    private func rotatePoint(_ p: CGPoint, around c: CGPoint, by theta: CGFloat) -> CGPoint {
        let dx = p.x - c.x, dy = p.y - c.y
        let cosT = cos(theta), sinT = sin(theta)
        return CGPoint(x: c.x + dx * cosT - dy * sinT, y: c.y + dx * sinT + dy * cosT)
    }
}
