# Caption control bar design QA

## Evidence

- Source visual truth: `/var/folders/rm/99g7pxgn6d72plzypdcy18j40000gn/T/TemporaryItems/NSIRD_screencaptureui_bjEBbV/Screenshot 2026-08-22 at 2.53.28 PM.png` (2222 × 160 px).
- Additional source visual truth: `/Users/redbars/Desktop/Screenshot 2026-08-22 at 7.46.55 PM.png` (900 × 389 px), showing the unwanted rectangular material/shadow regions around both rounded surfaces.
- Current native implementation captures: `/private/tmp/said-unified-scale-medium.png` and `/private/tmp/said-unified-scale-xl.png`.
- Final Block font capture: [`docs/assets/caption-block-font.jpeg`](docs/assets/caption-block-font.jpeg).
- Latest same-input visual comparison: [`docs/assets/caption-unified-scale-comparison.png`](docs/assets/caption-unified-scale-comparison.png). The prior separate controls are above and the unified native Said control is below.
- Verified states: all five caption-size presets, including Medium at 34 pt / 760 pt wide and Extra Large at 56 pt / 1,280 pt wide.

The screenshot is the visual reference for a compact, neutral, single-row dark
formatting bar. Said adapts its density and direct-value controls to captions
without copying unrelated document actions.

## Comparison

| Surface | Result |
| --- | --- |
| Typography | One compact value such as `M 34px` communicates the active caption scale. Font remains a separate typographic choice because it does not alter geometry. Rounded, Sans, Serif, condensed Mono, and heavy Block offer five distinct native treatments. |
| Spacing | Move, caption scale, font, color, and Done form one shorter left-aligned cluster with consistent separators. The redundant second size control is gone. |
| Color | The neutral charcoal surface follows the reference. White, warm yellow, and cyan remain direct choices with a clear selected ring. |
| Icons/assets | The only icon is the native move affordance. Sizing uses readable values instead of approximate resize imagery. |
| Geometry | The caption card and toolbar remain separate surfaces. At the top of the display the toolbar renders below the captions; lower placement renders it above. Showing, hiding, or flipping the toolbar now preserves the caption card as the fixed global anchor. |
| Surface rendering | The square material/shadow compositing regions visible in the supplied screenshots are gone. Both surfaces retain their rounded charcoal fill and subtle highlight border without a rectangular haze. |
| Accessibility | The native tree exposes one Caption Size control, font, each color, and Done. The scale control announces its named size, point size, and complete five-step cycle. |

## Interaction evidence

- The single control was exercised through `XS → S → M → L → XL` in the running native app.
- Presets pair text and requested window width as `14/360`, `22/520`, `34/760`, `44/1000`, and `56/1280` points.
- Every preset retains approximately six or seven words per line, avoiding a tiny typeface in a huge strip or giant type in a cramped box.
- Requested widths still clamp safely to the current display.
- Moving the panel is still available from the panel background while controls are visible.
- A deterministic placement policy puts the toolbar below captions in the upper display half and above them in the lower half.
- Core Graphics reported the caption-only window at `X 639, Y 195, 360 × 72` and the hover window at `X 639, Y 195, 360 × 128`; the caption card's top-left screen coordinate is unchanged while the toolbar is added below it.
- The saved normalized position is calculated from the caption card rather than the temporarily expanded toolbar window.
- Caption scale, font, and color persist as ordinary local settings. Existing independent text/width preferences migrate to the nearest unified preset.
- Mono and Block were exercised in the running native panel. Mono remains compact enough for the fixed two-line surface; Block uses the system sans face at black weight for a strong display treatment without clipping the XS preview.
- Normal caption mode remains click-through after the hover grace period.
- Forty-four deterministic tests and the privacy smoke pass.

## Iteration history

1. The original horizontal drag handle was hard to acquire and did not give the user a predictable resulting width.
2. A first width stepper still used small left/right arrows and kept the width range too narrow.
3. Replaced it with one clickable current-value label and expanded XS–XL to a much wider 360–1280 point requested range.
4. Replaced font-size arrows with the same current-value interaction and expanded the range down to 14 points and up to 56 points.
5. Removed trailing alignment, kept the control cluster left-facing, and added automatic above/below toolbar placement based on display position.
6. The final comparison found no actionable P0, P1, or P2 visual defects. The cursor highlight on the size value is an intentional hovered state.
7. Anchored toolbar expansion to the caption card so hover no longer moves the user's dragged subtitle position.
8. Removed the translucent material and broad SwiftUI shadows that produced rectangular compositing blocks behind the rounded surfaces.
9. The latest source/implementation comparison found no remaining P0, P1, or P2 defect in the requested anchor and surface treatment.
10. Replaced independent text-size and window-width controls with one five-step Caption Size preset.
11. Tuned each preset to retain a consistent readable word count while preserving the existing XS–XL physical range and Medium default.
12. The final native click-through and combined source/implementation comparison found no actionable P0, P1, or P2 defects.
13. Added Mono and Block to the font cycle, then tightened their treatments after native review exposed clipping in the first expanded Block draft.
14. The final Block preview preserves the complete caption at XS while remaining visibly heavier than Sans.

## Final result

passed
