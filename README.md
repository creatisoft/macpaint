# macPaint (SwiftUI, macOS)

A lightweight, layer-based drawing app built with SwiftUI for macOS. It provides a simple canvas, core vector tools (brush, line, rectangle, ellipse), image import, per-layer visibility/opacity, selection and transform handles, and pixel-perfect export to PNG.

- Platform: macOS (SwiftUI + AppKit bridges where needed)
- Rendering: SwiftUI Canvas for on-screen drawing, Core Graphics for export (pixel parity)
- Status: Early preview (single-session, no document persistence yet)
  
- This is vibe coded. 

## Preview

<img width="1440" height="827" alt="macpaint-screenshot" src="https://github.com/user-attachments/assets/d8f12271-a56c-4eca-9e1f-47cf24ea1c8f" />


## Features

- Drawing tools
  - Brush/Eraser: pressure-insensitive freehand strokes with round caps/joins
  - Line: straight line between start and current pointer
  - Rectangle/Ellipse: drag to size; rotation handle for shapes
  - Selection: click to select, drag to move, handles to resize/rotate
  - Image: import as bitmap item; select/move/resize/rotate like shapes

- Layers
  - Add, rename, delete (with safety constraints)
  - Toggle visibility (eye icon)
  - Opacity per layer (0–100%)
  - Reorder with per-row Up/Down arrows or List reordering
  - Hit-testing respects layer order (topmost wins)

- Canvas
  - Custom width/height (validated)
  - Background color with alpha
  - Zoom in/out (25%–400%)

- Export
  - Save to PNG via a high-DPI-aware bitmap context
  - Matches on-screen compositing (including eraser’s destinationOut blend mode)

## Requirements

- Xcode 26

## Installation

- Clone the repository
- Open the Xcode project/workspace
- Select the macOS target
- Build and run (⌘R)

No external dependencies are required.

## Usage

- Choose a tool from the left Tools panel (Select, Brush, Eraser, Line, Rectangle, Ellipse)
- Draw on the canvas in the center
- Manage layers from the right Layers panel (rename, visibility, opacity, reorder, delete)
- Adjust brush size and color from the top toolbar
- Change canvas size, background color, and zoom from the top toolbar
- Import an image via the Tools panel; it’s placed as a new layer, auto-centered and scaled to fit
- Export to PNG from the toolbar (Save)

## Keyboard Shortcuts

- Save: Command + S
- Zoom In/Out: via toolbar buttons (add your own shortcuts if desired)
- Selection tips:
  - Right-click a layer row for context actions (Rename, Delete Layer)
  - Use the rotation handle (above selection box) to rotate shapes and images
  - Use the eraser tool for true erasing within the active layer

## Layer Ordering

- The layers array is rendered from bottom (index 0) to top (last index)
- Hit-testing checks from the topmost layer downward
- Moving rows:
  - Up arrow: move toward index 0 (row moves higher in the list)
  - Down arrow: move toward the last index (row moves lower in the list)
- After adding a layer, it is auto-selected and movement arrows reflect what’s currently possible

## Recent Enhancements (Layers)

- Context Menu: “Delete Layer”
  - Disabled when there is only one layer or when the row is the last/topmost layer
  - Maintains sensible selection after deletion

- Move Controls: Up/Down arrows per layer row
  - Arrows always visible
  - Up arrow enabled when the row can move up (index > 0)
  - Down arrow enabled when the row can move down (index < last index)
  - Selection index updates to follow the moved layer

- Post-Add Behavior
  - After adding a layer, it is auto-selected and its movement arrows reflect what’s currently possible

## Project Structure

- macPaintApp.swift
  - App entry point; hosts ContentView

- ContentView.swift
  - Owns high-level state (layers, selection, tools, canvas)
  - Assembles toolbar, tools panel, canvas, and layers panel
  - Actions: clear, save, import image, canvas sizing

- CanvasView.swift
  - Draws all layers/items using SwiftUI Canvas
  - Handles gestures for tools (draw, shape, select/move/resize/rotate)
  - Translates between scroll-space and logical canvas coordinates

- LayersPanelView.swift
  - Renders the layers list with rename, visibility, opacity, move, delete
  - Keeps selection consistent across edits

- ToolbarView.swift
  - Brush size, color palette, system color panel
  - Canvas size controls
  - Background color, zoom, clear/save

- ToolsPanelView.swift
  - Tool selection
  - Import Image… button

- DrawingModels.swift
  - Tool enum; item models (StrokeItem, RectItem, EllipseItem, LineItem, ImageItem)
  - Drawable enum (unified interface)
  - Drawing to both SwiftUI GraphicsContext and NSGraphicsContext
  - Hit-testing and bounding boxes

- LayerModels.swift
  - Layer model (name, visibility, opacity, items)
  - BrushSize and CanvasSize models
  - SelectionHandle enum

- MacColorBridge.swift
  - Color bridging between SwiftUI Color and NSColor

- ColorPanelTarget.swift
  - AppKit target/action trampoline for NSColorPanel changes

## Building & Running

- Open the project in Xcode (macOS target)
- Build and run (⌘R)
- Requires macOS 12+ for best color bridging; earlier versions gracefully fall back
