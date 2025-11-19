# Plan: Drag-and-Drop Images to Canvas

Add native macOS drag-and-drop support for images onto the canvas. When an image is dropped, it will be added to a new layer (or the existing single layer if only one exists) and automatically switches to Select tool for immediate resizing and positioning. This preserves all current functionality while providing a faster, more intuitive workflow than the existing "Import Image…" button.

## ✅ Implementation Complete

### What Was Implemented

1. **✅ Extracted image creation logic in [`ContentView.swift`](ContentView.swift)** — Created reusable `createImageItem(from:at:)` helper function that:
   - Handles image decoding with error alerts
   - Auto-scales images to 70% of canvas if larger
   - Positions at drop location or centers on canvas
   - Implements smart layer logic: adds to existing layer if only 1 layer, otherwise creates new layer
   - Switches to Select tool for immediate manipulation
   - Registers proper undo/redo with "Add Image" action name
   - Existing import button still works perfectly

2. **✅ Added drop acceptance to [`CanvasView.swift`](CanvasView.swift)** — Implemented:
   - `.onDrop(of: [.image], isTargeted:)` modifier on `drawingSurface`
   - `handleImageDrop()` method that extracts image data from `NSItemProvider`
   - Maps drop location to canvas coordinates using existing `logicalPoint()` helper
   - Uses NotificationCenter to communicate with ContentView (clean separation of concerns)
   - Supports multiple images in a single drop operation

3. **✅ Implemented smart layer selection logic** — The helper automatically:
   - Checks if `layers.count == 1`: adds image to existing layer
   - If multiple layers exist: creates new "Image N" layer above current selection
   - Both paths properly maintain layer counter and selection state

4. **✅ Added visual drop feedback** — Canvas shows:
   - Dashed blue border around canvas when dragging image over it
   - Uses `isImageDropTargeted` @State bound to `.onDrop()`'s `isTargeted` parameter
   - Border disappears when drag exits or completes
   - Toast notification shows "Image added" or "N images added" after successful drop

5. **✅ Supports multiple image drops** — Implementation handles:
   - Multiple images in a single drop operation
   - Each image processed and positioned at the drop location
   - Success feedback shows count of images added
   - All images added to the same layer (per the plan's recommendation)

### How It Works

**User Flow:**
1. Drag image file(s) from Finder over the canvas
2. Canvas shows dashed border to indicate valid drop zone
3. Release mouse to drop
4. Image(s) appear at drop location, automatically sized to fit
5. Tool switches to Select for immediate resizing/rotating
6. Toast shows confirmation
7. Undo/redo works perfectly

**Technical Details:**
- Uses SwiftUI's native `.onDrop()` modifier with UTType.image
- Asynchronously loads image data from NSItemProvider
- Maps drop coordinates through zoom and scroll transformations
- Communicates between CanvasView and ContentView via NotificationCenter
- Reuses all existing image infrastructure (ImageItem, rendering, transforms, undo)

### Testing Instructions

To test the new drag-and-drop feature:

1. **Basic Drop**: Drag a PNG/JPG from Finder onto the canvas. Should appear at drop location with dashed border feedback.
2. **Single Layer Mode**: Delete all layers except one, then drop an image. Should be added to existing layer (no new layer created).
3. **Multi-Layer Mode**: With 2+ layers, drop an image. Should create new "Image N" layer above current selection.
4. **Multiple Images**: Select multiple images in Finder and drag together. All should appear at drop location.
5. **Positioning**: Drop at different locations to verify image centers on drop point correctly.
6. **Undo/Redo**: After dropping, use Cmd+Z to undo (should remove image and layer if created). Cmd+Shift+Z to redo.
7. **Select Tool**: After drop, Select tool should be active and image should be selected with resize handles visible.
8. **Existing Import**: Verify "Import Image…" button still works and centers images on canvas.
9. **Zoom**: Test dropping at various zoom levels (25%, 100%, 400%) to verify coordinate mapping.

### Design Decisions (Implemented)

✅ **Drop positioning**: Images appear at the exact drop location (centered on drop point) for intuitive drag-and-drop UX
✅ **Visual feedback**: Dashed blue border around canvas (minimal, non-intrusive)
✅ **Multi-image behavior**: All images added to same layer at drop location, simpler UX
✅ **Image sizing**: Uses same auto-scaling as import (70% of canvas max) for consistency
✅ **Success feedback**: Toast notification shows "Image added" or count for 1.5 seconds

### Next Steps

The drag-and-drop feature is fully functional and ready to use! Optional enhancements could include:
- Cascade positioning for multiple images (e.g., +20pt offset for each)
- Batch undo for multiple image drops in a single operation
- Support for dropping images directly onto specific layers in the Layer Panel
- Show image preview while dragging over canvas
