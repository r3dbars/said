# Caption control bar design QA

## Evidence

- Source visual truth: `/var/folders/rm/99g7pxgn6d72plzypdcy18j40000gn/T/TemporaryItems/NSIRD_screencaptureui_bjEBbV/Screenshot 2026-08-22 at 2.53.28 PM.png` (2222 × 160 px).
- Current native implementation capture: `/private/tmp/said-toolbar-14pt-xs.png`.
- Same-input visual comparison: [`docs/assets/caption-toolbar-comparison-v3.png`](docs/assets/caption-toolbar-comparison-v3.png). The supplied reference is above and Said is below.
- Verified state: 14 pt Sans, Warm Yellow, XS width selected, placement mode, panel in the upper half of the display with the toolbar below the captions.

The screenshot is the visual reference for a compact, neutral, single-row dark
formatting bar. Said adapts its density and direct-value controls to captions
without copying unrelated document actions.

## Comparison

| Surface | Result |
| --- | --- |
| Typography | Current values are directly readable as `14px`, `Aa Sans`, and `XS`; the controls no longer depend on unlabeled arrow targets. |
| Spacing | Move, text size, font, color, width, and Done form one compact left-aligned cluster with consistent separators. XS still fits without a second row. |
| Color | The neutral charcoal surface follows the reference. White, warm yellow, and cyan remain direct choices with a clear selected ring. |
| Icons/assets | The only icon is the native move affordance. Sizing uses readable values instead of approximate resize imagery. |
| Geometry | The caption card and toolbar remain separate surfaces. At the top of the display the toolbar renders below the captions; lower placement renders it above. |
| Accessibility | The native tree exposes point size, font, each color, width value, and Done. Size and width buttons announce their full cycling ranges. |

## Interaction evidence

- Clicking the point-size value was exercised through `26 → 34 → 44 → 56 → 14`; the card height followed the selection.
- The complete text-size cycle is 14, 18, 22, 26, 34, 44, and 56 points.
- Clicking the width value was exercised through `S → M → L → XL → XS`; no drag target remains.
- Width choices map to substantially different requested widths and clamp safely to the current display.
- Moving the panel is still available from the panel background while controls are visible.
- A deterministic placement policy puts the toolbar below captions in the upper display half and above them in the lower half.
- Font, color, width, and point-size selections persist as ordinary local settings.
- Normal caption mode remains click-through after the hover grace period.
- Forty-one deterministic tests and the privacy smoke pass.

## Iteration history

1. The original horizontal drag handle was hard to acquire and did not give the user a predictable resulting width.
2. A first width stepper still used small left/right arrows and kept the width range too narrow.
3. Replaced it with one clickable current-value label and expanded XS–XL to a much wider 360–1280 point requested range.
4. Replaced font-size arrows with the same current-value interaction and expanded the range down to 14 points and up to 56 points.
5. Removed trailing alignment, kept the control cluster left-facing, and added automatic above/below toolbar placement based on display position.
6. The final comparison found no actionable P0, P1, or P2 visual defects. The cursor highlight on the width value is an intentional hovered state.

## Final result

passed
