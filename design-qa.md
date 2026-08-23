# Caption control bar design QA

## Evidence

- Source visual truth: `/var/folders/rm/99g7pxgn6d72plzypdcy18j40000gn/T/TemporaryItems/NSIRD_screencaptureui_bjEBbV/Screenshot 2026-08-22 at 2.53.28 PM.png` (2222 × 160 px).
- Additional source visual truth: `/Users/redbars/Desktop/Screenshot 2026-08-22 at 7.46.55 PM.png` (900 × 389 px), showing the unwanted rectangular material/shadow regions around both rounded surfaces.
- Current native implementation capture: `/private/tmp/said-caption-anchor-fixed.png`.
- Latest same-input visual comparison: [`docs/assets/caption-anchor-comparison.png`](docs/assets/caption-anchor-comparison.png). The supplied artifact state is above and the fixed native Said preview is below.
- Verified state: 14 pt Sans, Warm Yellow, XS width selected, hover controls below the captions.

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
| Geometry | The caption card and toolbar remain separate surfaces. At the top of the display the toolbar renders below the captions; lower placement renders it above. Showing, hiding, or flipping the toolbar now preserves the caption card as the fixed global anchor. |
| Surface rendering | The square material/shadow compositing regions visible in the supplied screenshots are gone. Both surfaces retain their rounded charcoal fill and subtle highlight border without a rectangular haze. |
| Accessibility | The native tree exposes point size, font, each color, width value, and Done. Size and width buttons announce their full cycling ranges. |

## Interaction evidence

- Clicking the point-size value was exercised through `26 → 34 → 44 → 56 → 14`; the card height followed the selection.
- The complete text-size cycle is 14, 18, 22, 26, 34, 44, and 56 points.
- Clicking the width value was exercised through `S → M → L → XL → XS`; no drag target remains.
- Width choices map to substantially different requested widths and clamp safely to the current display.
- Moving the panel is still available from the panel background while controls are visible.
- A deterministic placement policy puts the toolbar below captions in the upper display half and above them in the lower half.
- Core Graphics reported the caption-only window at `X 639, Y 195, 360 × 72` and the hover window at `X 639, Y 195, 360 × 128`; the caption card's top-left screen coordinate is unchanged while the toolbar is added below it.
- The saved normalized position is calculated from the caption card rather than the temporarily expanded toolbar window.
- Font, color, width, and point-size selections persist as ordinary local settings.
- Normal caption mode remains click-through after the hover grace period.
- Forty-two deterministic tests and the privacy smoke pass.

## Iteration history

1. The original horizontal drag handle was hard to acquire and did not give the user a predictable resulting width.
2. A first width stepper still used small left/right arrows and kept the width range too narrow.
3. Replaced it with one clickable current-value label and expanded XS–XL to a much wider 360–1280 point requested range.
4. Replaced font-size arrows with the same current-value interaction and expanded the range down to 14 points and up to 56 points.
5. Removed trailing alignment, kept the control cluster left-facing, and added automatic above/below toolbar placement based on display position.
6. The final comparison found no actionable P0, P1, or P2 visual defects. The cursor highlight on the width value is an intentional hovered state.
7. Anchored toolbar expansion to the caption card so hover no longer moves the user's dragged subtitle position.
8. Removed the translucent material and broad SwiftUI shadows that produced rectangular compositing blocks behind the rounded surfaces.
9. The latest source/implementation comparison found no remaining P0, P1, or P2 defect in the requested anchor and surface treatment.

## Final result

passed
