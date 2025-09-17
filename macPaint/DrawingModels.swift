//  DrawingModels.swift
//  macPaint
//
//  Created by Christopher on 9/7/25.
//

import SwiftUI
import AppKit

// Tools available in the left toolbar
enum Tool: String, CaseIterable, Identifiable {
    case select
    case brush
    case eraser
    case line
    case rectangle
    case ellipse
    case bucket

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .brush: return "pencil.tip"
        case .eraser: return "eraser"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .bucket:
            // SF Symbols: "paintbucket" (macOS 14+). If unavailable, consider adding an asset alias.
            return "paintbucket"
        }
    }

    var displayName: String {
        switch self {
        case .select: return "Select"
        case .brush: return "Brush"
        case .eraser: return "Eraser"
        case .line: return "Line"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .bucket: return "Bucket"
        }
    }
}

// Style for stroked shapes and lines
struct StrokeStyleModel: Hashable {
    var color: Color
    var lineWidth: CGFloat
}

// Individual drawable item types
struct StrokeItem: Identifiable, Hashable {
    let id = UUID()
    var points: [CGPoint]
    var style: StrokeStyleModel
    var isEraser: Bool = false // Track if this is an eraser stroke
}

struct RectItem: Identifiable, Hashable {
    let id = UUID()
    // Stored as an axis-aligned rect in canvas coordinates before transform
    var rect: CGRect
    var style: StrokeStyleModel
    var rotation: CGFloat = 0 // radians
    var scale: CGSize = .init(width: 1, height: 1)
    // New: optional fill color (nil or .clear = no fill)
    var fill: Color? = nil
}

struct EllipseItem: Identifiable, Hashable {
    let id = UUID()
    var rect: CGRect
    var style: StrokeStyleModel
    var rotation: CGFloat = 0
    var scale: CGSize = .init(width: 1, height: 1)
    // New: optional fill color
    var fill: Color? = nil
}

struct LineItem: Identifiable, Hashable {
    let id = UUID()
    var start: CGPoint
    var end: CGPoint
    var style: StrokeStyleModel
    var rotation: CGFloat = 0
    var scale: CGSize = .init(width: 1, height: 1)
}

// Bitmap image drawable (stored as NSImage for macOS)
struct ImageItem: Identifiable {
    let id = UUID()
    var image: NSImage
    var rect: CGRect
    var rotation: CGFloat = 0
    var scale: CGSize = .init(width: 1, height: 1)
}

// MARK: - Small geometry helpers

private extension CGRect {
    func scaled(by scale: CGSize) -> CGRect {
        var r = self
        r.size.width *= scale.width
        r.size.height *= scale.height
        return r
    }
}

// Unified drawable
enum Drawable: Identifiable, Hashable {
    case stroke(StrokeItem)
    case rect(RectItem)
    case ellipse(EllipseItem)
    case line(LineItem)
    case image(ImageItem)

    var id: UUID {
        switch self {
        case .stroke(let s): return s.id
        case .rect(let r): return r.id
        case .ellipse(let e): return e.id
        case .line(let l): return l.id
        case .image(let i): return i.id
        }
    }

    // Provide custom Hashable/Equatable so we can carry NSImage in ImageItem without requiring Hashable
    static func == (lhs: Drawable, rhs: Drawable) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Quick accessors for common style (not applicable to image)
    var strokeColor: Color {
        switch self {
        case .stroke(let s): return s.style.color
        case .rect(let r): return r.style.color
        case .ellipse(let e): return e.style.color
        case .line(let l): return l.style.color
        case .image: return .clear
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .stroke(let s): return s.style.lineWidth
        case .rect(let r): return r.style.lineWidth
        case .ellipse(let e): return e.style.lineWidth
        case .line(let l): return l.style.lineWidth
        case .image: return 0
        }
    }

    // Axis-aligned bounding box in canvas coordinates (ignoring rotation for simplicity)
    func boundingBox() -> CGRect {
        switch self {
        case .stroke(let s):
            guard let first = s.points.first else { return .zero }
            var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
            for p in s.points {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
        case .rect(let r):
            return r.rect.scaled(by: r.scale)
        case .ellipse(let e):
            return e.rect.scaled(by: e.scale)
        case .line(let l):
            let minX = min(l.start.x, l.end.x)
            let minY = min(l.start.y, l.end.y)
            let maxX = max(l.start.x, l.end.x)
            let maxY = max(l.start.y, l.end.y)
            return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
        case .image(let i):
            return i.rect.scaled(by: i.scale)
        }
    }

    // Simple hit test using bounding box (ignores rotation for simplicity)
    func hitTest(point: CGPoint, tolerance: CGFloat = 6) -> Bool {
        switch self {
        case .stroke(let s):
            // Hit test polyline by checking distance to segments
            guard s.points.count > 1 else { return false }
            let tol2 = tolerance * tolerance
            for i in 0..<s.points.count - 1 {
                if distanceSquaredFromPoint(point, toSegment: (s.points[i], s.points[i+1])) <= tol2 {
                    return true
                }
            }
            return false
        case .rect, .ellipse, .image:
            return boundingBox().insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .line(let l):
            let tol2 = tolerance * tolerance
            return distanceSquaredFromPoint(point, toSegment: (l.start, l.end)) <= tol2
        }
    }

    // Drawing into SwiftUI Canvas
    func draw(in context: GraphicsContext, layerOpacity: Double) {
        switch self {
        case .stroke(let s):
            guard s.points.count > 1 else { return }
            var path = Path()
            path.addLines(s.points)
            let style = StrokeStyle(lineWidth: s.style.lineWidth, lineCap: .round, lineJoin: .round)

            if s.isEraser {
                // Use destination out blend mode for true erasing.
                // Apply layerOpacity to match export strength.
                var ctx = context
                ctx.blendMode = .destinationOut
                ctx.stroke(path, with: .color(.black.opacity(layerOpacity)), style: style)
            } else {
                context.stroke(path, with: .color(s.style.color.opacity(layerOpacity)), style: style)
            }

        case .rect(let r):
            let rect = r.rect.scaled(by: r.scale)
            var path = Path(roundedRect: rect, cornerRadius: 2)
            if r.rotation != 0 {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let t = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: r.rotation)
                    .translatedBy(x: -center.x, y: -center.y)
                path = path.applying(t)
            }
            // Fill first (if present), then stroke
            if let fill = r.fill, fill != .clear {
                context.fill(path, with: .color(fill.opacity(layerOpacity)))
            }
            context.stroke(path, with: .color(r.style.color.opacity(layerOpacity)), lineWidth: r.style.lineWidth)

        case .ellipse(let e):
            let rect = e.rect.scaled(by: e.scale)
            var path = Path(ellipseIn: rect)
            if e.rotation != 0 {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let t = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: e.rotation)
                    .translatedBy(x: -center.x, y: -center.y)
                path = path.applying(t)
            }
            if let fill = e.fill, fill != .clear {
                context.fill(path, with: .color(fill.opacity(layerOpacity)))
            }
            context.stroke(path, with: .color(e.style.color.opacity(layerOpacity)), lineWidth: e.style.lineWidth)

        case .line(let l):
            var path = Path()
            path.move(to: l.start)
            path.addLine(to: l.end)
            // rotation/scale omitted for simplicity on lines (endpoints define it)
            context.stroke(path, with: .color(l.style.color.opacity(layerOpacity)), lineWidth: l.style.lineWidth)

        case .image(let i):
            let rect = i.rect.scaled(by: i.scale)
            var ctx = context
            if i.rotation != 0 {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                // GraphicsContext doesn't support anchor parameter; do anchored rotation manually.
                ctx.translateBy(x: center.x, y: center.y)
                ctx.rotate(by: Angle(radians: i.rotation))
                ctx.translateBy(x: -center.x, y: -center.y)
            }
            // SwiftUI Image draw path
            let swiftUIImage = Image(nsImage: i.image)
            // Apply layer opacity via context, then draw image
            ctx.opacity = layerOpacity
            ctx.draw(swiftUIImage, in: rect)
        }
    }

    // Drawing into AppKit NSGraphicsContext for export
    func drawToNSContext(layerOpacity: Double) {
        switch self {
        case .stroke(let s):
            guard let cg = NSGraphicsContext.current?.cgContext else {
                // Fallback to NSBezierPath-only if no cgContext (unlikely when locked focus)
                let path = NSBezierPath()
                if let first = s.points.first {
                    path.move(to: first)
                    for p in s.points.dropFirst() { path.line(to: p) }
                }
                path.lineJoinStyle = .round
                path.lineCapStyle = .round
                path.lineWidth = s.style.lineWidth
                if s.isEraser {
                    // Without cgContext we can't set blend mode; best-effort: draw nothing
                } else {
                    MacColorBridge.nsColor(from: s.style.color).withAlphaComponent(layerOpacity).setStroke()
                    path.stroke()
                }
                return
            }

            // Use Core Graphics so we can set blend mode for eraser
            cg.saveGState()
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.setLineWidth(s.style.lineWidth)

            if s.isEraser {
                cg.setBlendMode(.destinationOut)
                cg.setStrokeColor(NSColor.black.withAlphaComponent(layerOpacity).cgColor)
            } else {
                let ns = MacColorBridge.nsColor(from: s.style.color).withAlphaComponent(layerOpacity)
                cg.setStrokeColor(ns.cgColor)
            }

            let path = CGMutablePath()
            if let first = s.points.first {
                path.move(to: first)
                for p in s.points.dropFirst() { path.addLine(to: p) }
            }
            cg.addPath(path)
            cg.strokePath()
            cg.restoreGState()

        case .rect(let r):
            let rect = r.rect.scaled(by: r.scale)
            guard let ctx = NSGraphicsContext.current?.cgContext else {
                let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
                if let fill = r.fill, fill != .clear {
                    MacColorBridge.nsColor(from: fill).withAlphaComponent(layerOpacity).setFill()
                    path.fill()
                }
                MacColorBridge.nsColor(from: r.style.color).withAlphaComponent(layerOpacity).setStroke()
                path.lineWidth = r.style.lineWidth
                path.stroke()
                return
            }
            ctx.saveGState()
            if r.rotation != 0 {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                ctx.translateBy(x: center.x, y: center.y)
                ctx.rotate(by: r.rotation)
                ctx.translateBy(x: -center.x, y: -center.y)
            }
            let path = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)
            if let fill = r.fill, fill != .clear {
                ctx.addPath(path)
                ctx.setFillColor(MacColorBridge.nsColor(from: fill).withAlphaComponent(layerOpacity).cgColor)
                ctx.fillPath()
            }
            ctx.addPath(path)
            ctx.setStrokeColor(MacColorBridge.nsColor(from: r.style.color).withAlphaComponent(layerOpacity).cgColor)
            ctx.setLineWidth(r.style.lineWidth)
            ctx.strokePath()
            ctx.restoreGState()

        case .ellipse(let e):
            let rect = e.rect.scaled(by: e.scale)
            guard let ctx = NSGraphicsContext.current?.cgContext else {
                let path = NSBezierPath(ovalIn: rect)
                if let fill = e.fill, fill != .clear {
                    MacColorBridge.nsColor(from: fill).withAlphaComponent(layerOpacity).setFill()
                    path.fill()
                }
                MacColorBridge.nsColor(from: e.style.color).withAlphaComponent(layerOpacity).setStroke()
                path.lineWidth = e.style.lineWidth
                path.stroke()
                return
            }
            ctx.saveGState()
            if e.rotation != 0 {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                ctx.translateBy(x: center.x, y: center.y)
                ctx.rotate(by: e.rotation)
                ctx.translateBy(x: -center.x, y: -center.y)
            }
            let path = CGPath(ellipseIn: rect, transform: nil)
            if let fill = e.fill, fill != .clear {
                ctx.addPath(path)
                ctx.setFillColor(MacColorBridge.nsColor(from: fill).withAlphaComponent(layerOpacity).cgColor)
                ctx.fillPath()
            }
            ctx.addPath(path)
            ctx.setStrokeColor(MacColorBridge.nsColor(from: e.style.color).withAlphaComponent(layerOpacity).cgColor)
            ctx.setLineWidth(e.style.lineWidth)
            ctx.strokePath()
            ctx.restoreGState()

        case .line(let l):
            guard let ctx = NSGraphicsContext.current?.cgContext else {
                let path = NSBezierPath()
                path.move(to: l.start)
                path.line(to: l.end)
                path.lineWidth = l.style.lineWidth
                MacColorBridge.nsColor(from: l.style.color).withAlphaComponent(layerOpacity).setStroke()
                path.stroke()
                return
            }
            ctx.saveGState()
            ctx.setLineWidth(l.style.lineWidth)
            ctx.setStrokeColor(MacColorBridge.nsColor(from: l.style.color).withAlphaComponent(layerOpacity).cgColor)
            ctx.move(to: l.start)
            ctx.addLine(to: l.end)
            ctx.strokePath()
            ctx.restoreGState()

        case .image(let i):
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            guard let cgImage = i.image.toCGImage() else { return }
            let rect = i.rect.scaled(by: i.scale)

            ctx.saveGState()
            if i.rotation != 0 {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                ctx.translateBy(x: center.x, y: center.y)
                ctx.rotate(by: i.rotation)
                ctx.translateBy(x: -center.x, y: -center.y)
            }
            ctx.setAlpha(layerOpacity)
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: rect)
            ctx.restoreGState()
        }
    }
}

// Distance helper for hit testing
func distanceSquaredFromPoint(_ p: CGPoint, toSegment seg: (CGPoint, CGPoint)) -> CGFloat {
    let (a, b) = seg
    let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
    let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
    let abLen2 = max(ab.x * ab.x + ab.y * ab.y, .leastNonzeroMagnitude)
    var t = (ap.x * ab.x + ap.y * ab.y) / abLen2
    t = min(1, max(0, t))
    let closest = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
    let dx = p.x - closest.x, dy = p.y - closest.y
    return dx*dx + dy*dy
}

// MARK: - NSImage to CGImage helper
extension NSImage {
    func toCGImage() -> CGImage? {
        // Try best available representations in NSImage
        var rect = CGRect(origin: .zero, size: size)
        guard let cgImage = cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            // Fallback via bitmap representation
            guard let tiffData = tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiffData),
                  let cg = rep.cgImage else {
                return nil
            }
            return cg
        }
        return cgImage
    }
}

