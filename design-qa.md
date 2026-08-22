# Caption control bar design QA

## Evidence

- Source visual truth: `/var/folders/rm/99g7pxgn6d72plzypdcy18j40000gn/T/TemporaryItems/NSIRD_screencaptureui_bjEBbV/Screenshot 2026-08-22 at 2.53.28 PM.png` (2222 × 160 px).
- Implementation capture: `/private/tmp/said-caption-controls-v2.png` (3024 × 1964 px).
- Focused same-input comparison: [`docs/assets/caption-toolbar-comparison.png`](docs/assets/caption-toolbar-comparison.png) (1220 × 258 px). The reference is above; Said is below.
- State: Move & Resize mode, dark appearance, 26 pt Rounded font, Warm Yellow selected.

The supplied screenshot is a visual reference for a compact, single-row dark
formatting bar. Said intentionally adapts that pattern to caption-specific
actions instead of copying unrelated document controls.

## Comparison

| Surface | Result |
| --- | --- |
| Typography | Current point size and font family are directly readable. Button labels and weights remain legible at the compact height. |
| Spacing | Controls form clear size, font, color, and layout groups with separators. Flexible space keeps resize and Done anchored to the trailing edge. |
| Color | The surface is neutral charcoal like the reference. White, warm yellow, and cyan are direct one-click caption choices; the selected swatch has a high-contrast ring. |
| Icons/assets | Native SF Symbols are used for move, size, and horizontal resize. No approximate or decorative assets were introduced. |
| Copy | The bar exposes only the current font, point size, direct appearance controls, and Done. Help and accessibility labels explain icons without adding visible clutter. |
| Geometry | The bar floats above the caption card as one compact row, while the caption panel retains its independent two-line reading surface. |

## Interaction evidence

- Size changes are one click and bounded to the three V1 sizes.
- Font is one click and cycles Rounded, Sans, and Serif while showing the current choice.
- Text color changes immediately from direct swatches.
- Dragging the panel background moves the captions; dragging the horizontal handle resizes them.
- Layout and appearance persist through typed preferences.
- Normal caption mode restores click-through behavior and removes the controls.
- Deterministic tests cover size/font/color progression, width clamping, normalized placement, and width-aware caption capacity.

## Iteration history

1. First capture exposed two P2 issues: the native material borrowed a strong green tint from the content behind it, and the font control did not reliably expose its current label at compact widths.
2. Added a neutral charcoal layer over native material and replaced the compact menu with a fixed-size one-click font cycle control.
3. Second focused comparison found no actionable P0, P1, or P2 visual defects. The remaining P3 difference is intentional: the source bar is wider and includes document controls that do not belong in Said.

## Final result

passed
