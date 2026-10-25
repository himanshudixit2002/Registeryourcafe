# Glass surfaces (performance policy)

The app uses a **two-tier** “liquid glass” look: frosted panels everywhere, **backdrop blur only where it is cheap**.

## Tiers

| Tier | Blur | Use |
|------|------|-----|
| **A (default)** | `surfaceBlurSigma` (usually **0**) | Lists, grids, stat rows, dense screens. Frost = gradient + rim + shadow from theme, no `BackdropFilter` per row. |
| **B (modal)** | `modalBlurSigma` | **One** shell per modal bottom sheet / overlay (`MobileAdaptiveDialog`, `GlassModalSheetChrome`, or a single `GlassPanel(blur: modal)` wrapping draggable sheet content). Not per list item. |

## Theme tokens

Defined on **`LiquidGlassTheme`** in `lib/theme/app_theme.dart` (via `ThemeExtension`):

- **`surfaceBlurSigma`** — scroll-heavy UI; keep at **0** unless profiling justifies a tiny value.
- **`modalBlurSigma`** — dialogs / single sheet chrome (higher sigma).

`ThemeData` also sets **`bottomSheetTheme`** and **`drawerTheme`** with transparent / translucent surfaces so the mesh gradient behind the app shows through.

## Widgets

| Widget | Role |
|--------|------|
| **`GlassPanel`** | Core primitive: gradient fill, border, optional blur from `GlassBlur` / overrides. |
| **`GlassBlur.auto`** | Uses `surfaceBlurSigma`. |
| **`GlassBlur.none`** | Force sigma 0. |
| **`GlassBlur.modal`** | Uses `modalBlurSigma`. |
| **`AppSurface`** | Thin wrapper: same as `GlassPanel` with sensible defaults for cards/tiles (tier A by default). |
| **`AppCard`** | Prefer for new work: uses **`GlassPanel`** by default (including when only **`borderColor`** is set). Falls back to a solid **`Container`** only when **`backgroundColor`** is set or **`elevation` > 0** (tinted / legacy cards). |
| **`GlassModalSheetChrome`** | Standard bottom sheet body: modal blur + top radius + drag handle. Use with **`showModalBottomSheet(..., backgroundColor: Colors.transparent)`**. |
| **`showGlassModalBottomSheet`** | Same as above plus keyboard **`viewInsets`** padding. |

## Do / don’t

- **Do** use **`AppSurface`** or **`AppCard`** instead of raw **`Card`** for visual chrome.
- **Do** keep **at most one** modal blur region per overlay (sheet/dialog).
- **Don’t** wrap every `ListView`/`AnimatedList` row in **`GlassBlur.modal`** or high sigma blur.
- **Don’t** stack many `BackdropFilter`s on one screen without profiling (`flutter run --profile`).

## Related files

- `lib/widgets/glass_panel.dart` — `GlassPanel`, `AppSurface`, `GlassBlur`
- `lib/theme/app_theme.dart` — `LiquidGlassTheme`, `bottomSheetTheme`, `drawerTheme`
- `lib/widgets/mobile_adaptive_dialog.dart` — sheet chrome with `GlassPanel(modal)`
- `lib/widgets/glass_modal_bottom_sheet.dart` — `GlassModalSheetChrome`, `showGlassModalBottomSheet`, `GlassModalSheetDragHandle`
- `lib/widgets/app_card.dart` — `AppCard` → `GlassPanel` path
