# Caption control bar design QA

## Evidence

- Source visual truth: `/var/folders/rm/99g7pxgn6d72plzypdcy18j40000gn/T/TemporaryItems/NSIRD_screencaptureui_bjEBbV/Screenshot 2026-08-22 at 2.53.28 PM.png` (2222 × 160 px).
- Additional source visual truth: `/Users/redbars/Desktop/Screenshot 2026-08-22 at 7.46.55 PM.png` (900 × 389 px), showing the unwanted rectangular material/shadow regions around both rounded surfaces.
- Current native implementation captures: `/private/tmp/said-unified-scale-medium.png` and `/private/tmp/said-unified-scale-xl.png`.
- Final Block font capture: [`docs/assets/caption-block-font.jpeg`](docs/assets/caption-block-font.jpeg).
- Latest same-input visual comparison: [`docs/assets/caption-unified-scale-comparison.png`](docs/assets/caption-unified-scale-comparison.png). The prior separate controls are above and the unified native Said control is below.
- Menu-bar source visual truth: `/var/folders/rm/99g7pxgn6d72plzypdcy18j40000gn/T/TemporaryItems/NSIRD_screencaptureui_lKDnwc/Screenshot 2026-08-23 at 6.28.47 AM.png` (504 × 806 px).
- Rendered native Said menu header and status: [`docs/assets/said-menu-header.png`](docs/assets/said-menu-header.png).
- Focused source/implementation comparison: [`docs/assets/said-menu-premium-comparison.png`](docs/assets/said-menu-premium-comparison.png). Klack's upper menu hierarchy is on the left; Said's real `NSSwitch`, header, and live-status components are on the right.
- Compact-menu source visual truths: `/var/folders/rm/99g7pxgn6d72plzypdcy18j40000gn/T/TemporaryItems/NSIRD_screencaptureui_dO7qhc/Screenshot 2026-08-23 at 1.13.44 PM.png` (530 × 526 px) for the oversized Said menu and `/var/folders/rm/99g7pxgn6d72plzypdcy18j40000gn/T/TemporaryItems/NSIRD_screencaptureui_Dz2PKY/Screenshot 2026-08-23 at 1.13.52 PM.png` (518 × 826 px) for the compact Klack reference.
- Revised native Said header/status render: [`docs/assets/said-menu-compact-header.png`](docs/assets/said-menu-compact-header.png) (520 × 132 px at 2× density; 260 × 66 pt).
- Revised Off-state render: [`docs/assets/said-menu-compact-off.png`](docs/assets/said-menu-compact-off.png), confirming the switch and status indicator both return to neutral gray.
- Density-normalized 260 × 38 pt header comparison: [`docs/assets/said-menu-compact-comparison.png`](docs/assets/said-menu-compact-comparison.png). Klack is on the left and revised Said is on the right at the same 2× density.
- Caption-centering source visual truths: `/Users/redbars/Desktop/Screenshot 2026-08-23 at 1.22.51 PM.png`, `/Users/redbars/Desktop/Screenshot 2026-08-23 at 1.22.55 PM.png`, `/Users/redbars/Desktop/Screenshot 2026-08-23 at 1.22.58 PM.png`, and `/Users/redbars/Desktop/Screenshot 2026-08-23 at 1.23.04 PM.png`, all showing the prior bottom-aligned caption block.
- Revised running native caption capture: [`docs/assets/caption-optically-centered.jpeg`](docs/assets/caption-optically-centered.jpeg) (520 × 152 px).
- Density-normalized caption-card comparison: [`docs/assets/caption-centering-comparison.png`](docs/assets/caption-centering-comparison.png). The prior card is above and the revised centered card is below, normalized to the same 520 × 95 pt card region.
- Latest native centered-composition capture: [`docs/assets/caption-centered-composition.jpeg`](docs/assets/caption-centered-composition.jpeg) (360 × 72 px at the user's active XS preset). This verifies spatial balance at the narrowest supported card rather than substituting a design mockup.
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
| Menu hierarchy | A compact semibold Said header and small native switch create one immediate on/off decision. A separate, quieter operational row uses a small semantic indicator and short status copy; actions remain ordinary native menu commands below it. |
| Menu restraint | Said borrows the reference's clear product-name/switch header, dark native material, separators, and muted hierarchy without importing Klack's sound, theme, or decorative controls. The only status color is a small system semantic dot. |
| Menu trust | Version, Settings, Privacy, and Quit remain visible and conventionally ordered. The switch changes the existing persisted caption state; it is not a visual-only control. |
| Caption optical balance | Each stable subtitle row is horizontally centered and the complete one- or two-line block is vertically centered inside the fixed caption card. The reducer still advances complete rows; the card does not resize and earlier words are not rebalanced between rows as speech arrives. |

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
- The enabled-session surface was exercised in the running native app. It appears before speech with quiet status copy, remains the same fixed two-line geometry as live captions arrive, and retains hover customization while empty.
- Normal caption mode remains click-through after the hover grace period.
- Forty-five deterministic tests and the privacy smoke pass.
- The native menu preview path rendered the actual header and status view classes. On/off synchronization remains driven by `AppModel`, so menu state, caption visibility, capture state, tooltip, and filled/unfilled status icon cannot drift into separate preference values.
- Both actual component states were rendered: On uses the scoped teal switch tint with green `Listening locally` status; Off uses the system-neutral switch track with gray `Captions are off` status. The tint is confined to the switch and does not change the user's global macOS accent color.
- The two-line native caption preview was captured in the running app. Its card has visually balanced top and bottom breathing room; the accessibility tree still exposes the complete visible caption as one value.
- The narrowest XS card was captured after horizontal centering. Both rows retain symmetric side breathing room, stay inside the fixed two-line surface, and expose the full visible caption as one accessibility value.

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
15. Replaced silence-driven fading with a persistent Captions On surface and a quiet ready state; the latest caption now remains anchored until new speech or an explicit Captions Off action.
16. Replaced the checked command item with a native switch in a bold Said header, following the supplied Klack interaction reference.
17. Added a restrained semantic status row: green while listening, orange while preparing, gray while off, and red only when attention is required.
18. Added a muted version row and retained standard macOS commands and separators, preserving a compact 264-point menu rather than introducing a custom popover or dashboard.
19. The final focused source/implementation comparison found no P0, P1, or P2 defect: hierarchy, native control choice, spacing, contrast, and interaction state are coherent with the reference while staying recognizably Said.
20. A later real-menu comparison exposed a P2 density mismatch: Said's 52-point header, 17-point bold title, and large switch rendered materially taller and louder than Klack's 38-point header rhythm.
21. Reduced the header to 38 points, title to 15-point semibold, and toggle to the small native SwiftUI switch style so it can use a per-control teal tint while `AppModel` remains the only source of truth.
22. Reduced the status row to 28 points, removed one redundant separator, and changed `Settings…` to `Said Settings…` without a shortcut so macOS no longer injects the oversized special Settings icon/alignment treatment.
23. The final density-normalized 260 × 38 point comparison shows matching header height, inset rhythm, title scale, switch scale, and teal On state. No actionable P0, P1, or P2 differences remain in the requested menu-header scope.
24. The supplied live-caption sequence exposed a P2 optical-balance issue: the reading stack used explicit bottom alignment and inserted a spacer above one-line captions, making the primary surface feel low and uneven.
25. Removed the single-line spacer and centered the complete reading stack vertically while retaining the 24-point horizontal inset, two-line cap, four-point interline spacing, leading alignment, and stable rolling-row reducer.
26. The normalized before/after card comparison confirms balanced vertical breathing room without clipping, reflow, or a change to card geometry. No actionable P0, P1, or P2 caption-centering issue remains.
27. Continued live use exposed a second P2 composition issue: stable short rows were visually stranded against the left edge, making the unused right side of the fixed card look accidental.
28. Centered each already-stable row horizontally while keeping the full stack vertically centered. The fixed card geometry, reducer capacities, row boundaries, tentative suffix behavior, and complete-row advancement remain unchanged.
29. The running native XS preview confirms balanced side and vertical breathing room without clipping or card movement. No actionable P0, P1, or P2 issue remains in the caption-composition scope.

## Final result

passed
