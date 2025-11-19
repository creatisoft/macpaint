# Plan: Drag-and-Drop Images to Canvas

Add native macOS drag-and-drop support for images onto the canvas. When an image is dropped, it will be added to a new layer (or the existing single layer if only one exists) and automatically switches to Select tool for immediate resizing and positioning. This preserves all current functionality while providing a faster, more intuitive workflow than the existing "Import Image…" button.

### Steps

1. **Extract image creation logic in [`ContentView.swift`](macPaint/ContentView.swift)** — Refactor `importImage()` to separate core logic into a reusable `createImageItem(from:imageData:at:)` helper that handles image decoding, sizing, ImageItem creation, layer management, tool switching, and undo registration. Keep existing import button functional.

2. **Add drop acceptance to [`CanvasView.swift`](macPaint/CanvasView.swift)** — Apply `.onDrop(of: [.image], isTargeted:)` modifier to the `drawingSurface` ZStack, implementing drop handler to extract image data from `NSItemProvider`, map drop location to canvas coordinates, and call the new helper function in `ContentView` with the image data and drop position.

3. **Implement smart layer selection logic in [`ContentView.swift`](macPaint/ContentView.swift)** — Update the extracted helper to check layer count: if only 1 layer exists, append `ImageItem` to that layer's items array; if multiple layers exist, create new layer above current selection (matching existing import behavior). Both paths register appropriate undo actions.

4. **Add visual drop feedback to [`CanvasView.swift`](macPaint/CanvasView.swift)** — Use the `isTargeted` binding from `.onDrop()` to show a subtle border or overlay on the canvas when dragging an image over it, providing clear visual indication of the drop zone. Remove feedback when drag exits or completes.

5. **Support multiple image drops in [`ContentView.swift`](macPaint/ContentView.swift)** — Enhance drop handler to iterate through all image providers in the drop, creating an `ImageItem` for each with slight position offsets (e.g., +20pt x/y cascade), and group all operations in a single undo registration named "Drop Images" (plural if >1).

### Further Considerations

1. **Drop positioning preference?** Currently centering images (matching import button). Should dropped images appear at the exact drop location instead, or centered? **Recommendation**: Use drop location for more intuitive drag-and-drop UX.

2. **Visual feedback style?** Options: A) Dashed border around canvas, B) Semi-transparent overlay with "Drop Image Here" text, C) Subtle glow effect, D) Change cursor only. **Recommendation**: Dashed border (minimal, non-intrusive).

3. **Multi-image drop behavior?** When dropping multiple images: A) All on same new layer, B) Each on its own new layer, C) Configurable via modifier key (Option = separate layers). **Recommendation**: All on same layer with cascade positioning, simpler UX.

4. **Image size on drop?** Current import auto-scales to 70% of canvas if larger. Should drops: A) Use same auto-scaling, B) Use original size always, C) Scale only if exceeds canvas bounds. **Recommendation**: Use same auto-scaling for consistency.

5. **Drop rejection handling?** If drop contains non-image data or unsupported format: A) Ignore silently, B) Show alert/error, C) Show temporary toast notification. **Recommendation**: Show 2-second toast notification at drop location for user feedback.
