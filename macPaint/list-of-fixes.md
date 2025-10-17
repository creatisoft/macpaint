# macPaint – Summary of Fixes and Improvements

This document summarizes recent fixes and enhancements applied across the project.

1) UndoManager target fixes (struct views)
- Files: ContentView.swift, CanvasView.swift
- Issue: Using UndoManager.registerUndo(withTarget:) with self (a SwiftUI struct) caused “requires that … be a class type” errors.
- Fix: Switched to using the UndoManager itself as the AnyObject target when registering undo/redo, mirroring the approach already used in LayersPanelView. This preserves paired undo/redo without targeting struct views.

2) Clear Canvas confirmation and destructive button styling
- File: ContentView.swift
- Issue: Destructive clear action had no confirmation dialog.
- Fix: Added an NSAlert confirmation before clearing all layers/items. The “Clear” button is tinted red and made the default key equivalent intentionally. Undo/redo registration preserved around the mutation.

3) Robust error handling for Save and Import
- File: ContentView.swift
- Issue: File write and read operations could fail silently or only log to console.
- Fixes:
  - saveAsPNG(): Show NSAlert if rendering fails, PNG encoding fails, or writing to disk throws. Use do/try/catch with user-visible error messages.
  - importImage(): Present alerts on file read failures and image decode failures; proceed only on success.

4) Safe optional handling in ellipse export fill
- File: DrawingModels.swift
- Issue: Force unwrap in NSGraphicsContext export path for ellipse fill (e.fill!).
- Fix: Replaced with safe optional binding (if let fill = e.fill, fill != .clear) and performed fill only when present.

5) Coordinate mapping guard in CanvasView
- File: CanvasView.swift
- Issue: logicalPoint(from:) assumed a valid canvasFrameInScroll; rapid geometry changes (zoom/resize) could yield stale .zero frames.
- Fix: Added a guard to return a safe fallback (.zero) if the frame is not yet valid, preventing bogus coordinates during transitions.

6) Consistent undo pairing patterns
- Files: ContentView.swift, CanvasView.swift, LayersPanelView.swift
- Improvement: Standardized undo registration to always pair undo with redo using the UndoManager as target, ensuring consistent, reversible state changes across insert/move/delete/transform operations.

7) Export parity and quality notes (no functional change here)
- File: ContentView.swift (renderBitmap)
- Note: Ensured the export path continues to match SwiftUI Canvas compositing (y-down transform, per-layer transparency layers, antialiasing/interpolation settings).

