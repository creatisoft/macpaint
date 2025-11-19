# UI/UX Enhancement Plan for macPaint

This document outlines a plan to elevate the visual polish and user experience of the macPaint application. The goal is to create a modern, native macOS feel with a touch of creative flair, ensuring the app is not only functional but also delightful to use.

## 1. Design System & Visual Identity

Establish a consistent visual language across the application.

*   **Color Palette**:
    *   **Accent Color**: Standardize the use of the system accent color (currently Blue/Multicolor) for active states, selections, and primary actions.
    *   **Neutrals**: Refine the grays used for backgrounds, borders, and inactive states to ensure good contrast and hierarchy. Use semantic system colors (e.g., `NSColor.controlBackgroundColor`, `NSColor.separatorColor`) for better dark mode support (even if currently light-mode focused).
    *   **Canvas Background**: Ensure the area *outside* the canvas provides enough contrast so the canvas "pops".
*   **Typography**:
    *   Use standard macOS system fonts (San Francisco) but consider weight and size adjustments for hierarchy.
    *   **Headers**: slightly bolder/larger for panel titles.
    *   **Labels**: clear, legible sizes for tool names and layer names.
    *   **Monospaced**: for numerical values (coordinates, dimensions, zoom levels).
*   **Iconography**:
    *   Continue using SF Symbols.
    *   Ensure consistent scale and weight (e.g., `.medium` or `.semibold`) across all icons.
    *   Consider custom symbol variants or "slash" variants for toggled states (like the eye icon).

## 2. Layout & Window Structure

Refine the overall composition of the main window.

*   **Unified Toolbar**:
    *   The top toolbar currently feels like a separate stack. Consider integrating it more seamlessly with the window title bar (using `.toolbar` modifier in SwiftUI if possible, or styling the custom toolbar to look more integrated).
    *   **Spacing**: Increase breathing room between groups of controls (Brush, Color, Canvas, Actions).
    *   **Separators**: Use softer dividers or whitespace instead of hard lines where possible.
*   **Panel Organization**:
    *   **Tools Panel (Left)**: Keep it slim. Ensure it has a distinct background or border to separate it from the canvas area.
    *   **Layers Panel (Right)**: Ensure it has a fixed or resizable width that accommodates layer names and controls without cramping.
    *   **Canvas Area (Center)**: This should be the hero. Center the canvas within the scroll view with a subtle drop shadow to mimic a "sheet of paper" effect.

## 3. Component Polish

### A. Toolbar
*   **Brush Size Selector**:
    *   Instead of a row of buttons, consider a slider or a popover grid for more granular control, or keep the presets but style them as a segmented control or a compact grid.
    *   **Visual Feedback**: The current circle preview is good. Ensure the "selected" state ring is crisp.
*   **Color Palette**:
    *   **Grid Layout**: If the palette grows, a 2-row grid might be more space-efficient than a long horizontal line.
    *   **Active State**: Add a subtle "lift" or shadow to the selected color to make it stand out.
*   **Canvas Controls**:
    *   Group "Width", "Height", and "Apply" into a cohesive "Canvas Size" popover or a more compact inline form.
    *   Replace the text fields with numeric steppers or cleaner input fields.

### B. Tools Panel
*   **Tool Buttons**:
    *   **Active State**: Use a tinted background (Accent Color with low opacity) for the active tool, rather than just gray.
    *   **Hover Effect**: Subtle background change on hover.
    *   **Tooltips**: Ensure all tools have helpful tooltips (already largely present, but review for consistency).
*   **Import Image**:
    *   Make this button distinct from the drawing tools, perhaps at the very bottom with a different icon style or separator.

### C. Layers Panel
*   **List Rows**:
    *   Increase row height slightly for better touch targets.
    *   **Thumbnail**: Add a small live preview thumbnail of the layer content on the left of the row.
    *   **Visibility Toggle**: The eye icon should be easy to click.
    *   **Renaming**: The inline renaming interaction should be smooth (double-click to rename pattern).
*   **Drag & Drop**:
    *   Visual cues (insertion lines) when reordering layers should be clear.
*   **Empty State**:
    *   If all layers are deleted (though currently prevented), or just for visual balance, ensure the list looks good when empty or has few items.

### D. Canvas View
*   **Paper Shadow**: Add a `shadow(radius: 4, y: 2)` to the white canvas rectangle to separate it from the background.
*   **Selection Handles**:
    *   Style the handles (squares) to be white with a blue border (or solid blue) for a standard macOS look.
    *   **Rotation Handle**: Make the rotation handle distinct (e.g., a circle instead of a square).
*   **Grid/Rulers (Optional)**: Consider adding a toggleable pixel grid or rulers for precision work.

## 4. Interactions & Feedback

*   **Hover States**:
    *   Buttons and list items should have immediate, subtle feedback when the mouse hovers over them.
*   **Transitions**:
    *   **Panel Toggles**: If panels can be collapsed, animate the width change.
    *   **Layer Changes**: Animate the addition/removal of layers in the list.
*   **Cursor Handling**:
    *   Change the cursor based on the active tool (e.g., crosshair for precision, hand for panning, arrow for selection).
    *   **Brush Cursor**: Show a circle outline matching the brush size when hovering over the canvas.

## 5. Dark Mode Support

*   Ensure all hardcoded colors (like `.black` text or `.white` backgrounds) are replaced with semantic colors (`.primary`, `.systemBackground`) to support macOS Dark Mode automatically.
*   The canvas itself should likely remain white (or user-selectable), but the UI around it should adapt.

## 6. Implementation Priorities

1.  **Canvas "Paper" Look**: Add shadow and centering to the canvas.
2.  **Toolbar & Panel Styling**: Update backgrounds, borders, and spacing.
3.  **Active/Hover States**: Refine the visual feedback for interactions.
4.  **Cursor Updates**: Implement tool-specific cursors.
5.  **Dark Mode Audit**: Replace hardcoded colors.
