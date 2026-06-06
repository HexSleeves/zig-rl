# zig-rl UI Revamp — Design Spec

Date: 2026-06-06
Status: Approved (design phase)
Stack: Zig 0.16.0, zig-gamedev (zgui/zglfw/zopengl), branch `main`
Related: `docs/roguelite-campaign-plan.md` (M9 Production UI), `docs/agent-handoff.md`

---

## 1. Goal

Replace all floating `zgui.begin()` windows (HUD, Messages, Inventory, Debug) with an in-screen, diegetic "facility OS" UI drawn entirely on zgui **draw-lists**. The UI becomes part of the screen like modern roguelikes (Cogmind / Shattered Pixel Dungeon / Jupiter Hell), not a dev toolkit overlay.

zgui remains ONLY as the rendering primitive layer: draw-lists (`getBackgroundDrawList` / `getForegroundDrawList`) for rects/text/gradients, plus font loading. No `zgui.begin()` gameplay windows remain (exception: the dev-only Debug overlay, see §9).

This is a **render-only** change. No simulation, RNG, turn, or content behavior changes. All existing tests (33 integration + 79 inline) must stay green.

### Decisions locked during brainstorming
- **Layout:** Hybrid Facility OS (top alert header, left vitals/loadout column, center framed map, right hover-inspect panel, bottom log + command hints).
- **Palette:** Cyan-on-Dark facility OS.
- **Camera:** Follow camera (player-centered, scrolls, clamps to map bounds).
- **Inspect source:** Auto (nearest visible hostile) + mouse-hover override.
- **FX:** Medium (hairline frames, corner brackets, bars, alert recolor, vignette, scanlines, approximated glyph glow, sync-glitch on alert spikes).
- **Scope:** In-game HUD + inventory + menus (main menu, game-over). Pause optional.

---

## 2. Visual System

### 2.1 Palette (Cyan-on-Dark)
Single source of truth in `src/ui/theme.zig`. ARGB `0xAABBGGRR` to match existing zgui usage in `window.zig`.

| Role | Hex (RGB) | Use |
|---|---|---|
| Background | `#060A12` | window clear / map void |
| Panel fill | `#0C1422` | panel surfaces |
| Map void (unexplored) | `#0A1018` | unseen tiles |
| Primary text | `#9FD4E8` | body readouts |
| Bright / highlight | `#73FFFE` | selection, player, active data, accents |
| Link/info accent | `#5FA8FF` | interactable highlights, hit% |
| Dim / secondary | `#3A5066` | explored-but-unseen, inactive, labels |
| Hairline border | `#2C5A78` | panel rules, frames |
| Structure slate | `#383E65` | wall tiles |

### 2.2 Hazard ramp (alert state)
Shared severity ramp, layered on the base palette. `alert_level` is 0–100 (`run_state.alert_level`, lockdown at ≥80).

| State | Threshold | Hex |
|---|---|---|
| Nominal | 0 | `#33FF66` |
| Caution | 1–39 | `#FFCC00` |
| Elevated | 40–69 | `#FF8A1E` |
| Alert | 70–79 | `#FF3B30` |
| Lockdown | ≥80 | `#C81020` (pulsing) |

`theme.alertTint(level: u8) -> u32` returns the interpolated ramp color for the current level (piecewise lerp between the anchors above). `theme.alertState(level) -> enum { nominal, caution, elevated, alert, lockdown }` for labels/banners.

### 2.3 Entity & tile colors
- **Player** `@`: bright `#73FFFE`, glyph glow + subtle pulse.
- **Enemies:** colored by threat using the hazard ramp (security/low → `#FF8A1E`, aware/hostile → `#FF3B30`). Faction stays the underlying signal; color = threat readout.
- **Items on ground:** `#33FF66`.
- **Interactables** (terminals/doors/cameras/lockers): info accent `#5FA8FF`; powered camera cones tinted by current alert state.
- **FOV tri-state:** visible = full color; explored-not-visible = dimmed ~35% (toward dim/secondary); unexplored = map-void color. Enemies/items render ONLY when currently visible (no memory ghosts) — preserves stealth.

---

## 3. Module Structure (`src/ui/`)

Existing `src/render.zig` is superseded by `src/ui/layout.zig` (kept temporarily if other code imports it; migrate callers). Existing `src/ui/hud.zig` (text-writer stub) and the draw fns in `window.zig` are replaced.

| Module | Purpose | Pure/Testable |
|---|---|---|
| `ui/theme.zig` | Palette, hazard ramp, `alertTint`, `alertState`, color ops (`lerp`, `dim`, `withAlpha`). | pure ✅ |
| `ui/camera.zig` | `Camera{ center_x, center_y }`; `follow(player, map_bounds, viewport)`, `tileToScreen`, `screenToTile`, bounds clamp, small-floor centering. | pure ✅ |
| `ui/layout.zig` | `Layout` of region rects: header, left sidebar, map viewport, right inspect, bottom log/cmd. Scales with framebuffer scale. Window size derivation. | pure ✅ |
| `ui/draw.zig` | Draw-list helpers on `zgui.DrawList`: `panel(rect, opts)` (hairline border, corner brackets, optional angular cut, fill), `bar(rect, frac, color)`, `labeled(pos, label, value)`, `glyph(pos, ch, color, size)`, `glyphGlow(...)`, `scanlines(rect, intensity)`, `vignette(rect, color, intensity)`, `textColored`. | render |
| `ui/panels/header.zig` | Sector name · turn · alert meter + state label; drives frame recolor. | render |
| `ui/panels/vitals.zig` | HP bar (color by fraction), armor, evasion. | render |
| `ui/panels/loadout.zig` | Equipped slots + carried item count summary. | render |
| `ui/panels/inspect.zig` | Target details: name, HP bar, faction/zone, hit% vs player; source = hovered tile or nearest visible hostile. | render |
| `ui/panels/log_panel.zig` | Message log, severity-colored (combat=red, gain=green, warn=amber, ambient=dim). | render |
| `ui/panels/map_view.zig` | Tiles (FOV tri-state) + objects + items + actors + enemy/camera FOV cones + player glow, transformed by camera. | render |
| `ui/screens/inventory.zig` | Full in-screen inventory panel: item list, equip slots, selection cursor, keyboard nav. | render |
| `ui/screens/main_menu.zig` | Title, New Run, Quit. | render |
| `ui/screens/game_over.zig` | Death/extraction summary (floor, turns, cause), Retry/Menu. | render |

`window.zig` reduces to: GLFW + GL + zgui init, font load, input polling (keyboard + mouse cursor → `screenToTile`), per-mode draw/input dispatch, FPS, smoke-frame limit.

---

## 4. Game-Mode State Machine

Uses existing `state.current_mode` (enum already has `main_menu, running, inventory, targeting, game_over, campaign_summary, debug`).

```
boot → main_menu
main_menu --[Enter/Space]--> running        (start/generate run)
main_menu --[Q/Esc]--------> quit
running   --[I]------------> inventory       (overlay; sim paused)
inventory --[I/Esc]--------> running
running   --[player hp<=0]-> game_over
game_over --[Enter]--------> main_menu       (or Retry → running)
game_over --[Q/Esc]--------> quit
```

- Currently the app boots straight into `running`; add `main_menu` as the initial mode and a run-start path (generate floor, init RunState). RunState init currently happens before the loop — move generation behind "New Run".
- Each mode: one draw function + one input handler. Only `running` forwards movement/hack/pickup commands to `game.handle`.
- `inventory` is an overlay drawn over a dimmed running frame; it pauses the sim (no `game.handle`).
- Pause screen: optional, not required for v1.

---

## 5. Camera & Mouse

- Map viewport is a fixed pixel rect (`layout.map_viewport`). Camera centers on the player tile; clamps so the viewport never shows past map edges; if a floor is smaller than the viewport in an axis, it centers that axis.
- `tileToScreen(tile, camera, viewport) -> px` and `screenToTile(px, camera, viewport) -> ?tile` (null if outside viewport / off-map).
- Each frame: read GLFW cursor pos (`window.getCursorPos`), map to tile via `screenToTile`. If it resolves to a visible tile, that's the inspect target; else fall back to nearest visible hostile (by Chebyshev distance to player).
- Round-trip property: `screenToTile(tileToScreen(t)) == t` for in-viewport tiles (unit test).

---

## 6. Window Sizing

`resizable = false` stays. `layout.zig` derives window size:
```
window_width  = padding + sidebar_w + gap + map_viewport_w + gap + inspect_w + padding
window_height = padding + header_h + gap + map_viewport_h + gap + log_h + padding
```
Map viewport sized in tiles (e.g. ~32×22 @ 24px) so it's generous but leaves room for side panels on a 1080p screen. Existing `framebufferScale` logic for high-DPI is preserved and applied to all regions.

---

## 7. Medium FX

Drawn after panels, into the foreground draw-list, tinted by `alertTint(alert_level)`:
- **Frames/brackets:** hairline border + 4 corner brackets per major panel; bracket color lerps toward hazard hue with alert.
- **Bars:** filled meters; HP bar color by fraction (green→amber→red); alert meter uses ramp.
- **Alert recolor:** header bar, all panel borders, accents, and the map frame lerp along the hazard ramp by alert level. Body text stays in base palette for legibility.
- **Vignette:** radial/edge dark gradient (layered `addRectFilledMultiColor`), tinted to hazard hue, intensity scales with alert (faint at caution → saturated crimson at lockdown).
- **Scanlines:** 2px-period dark horizontal lines over the map at ~10–12% alpha (cheap filled rects or a precomputed pattern).
- **Glyph glow:** zgui draw-list has no blur; approximate by drawing the player/accent glyph 2–3× at small offsets with low alpha behind the solid glyph. Glow radius/alpha scale slightly with alert.
- **Sync-glitch:** on an alert *increase* event, briefly offset a horizontal band of the map and flash a scanline burst (time-boxed, decays over a few frames).
- **Lockdown banner:** angular-cut `FACILITY LOCKDOWN — SECTOR SEALED` banner in `#C81020`, pulsing, when `alert_level >= 80` (replaces current `[LOCKDOWN]` HUD text).
- **De-escalation:** alert color eases back down the ramp over a few frames rather than snapping (visual smoothing on a displayed alert value that chases the real one).

### Font (optional, skippable task)
Load a bundled permissively-licensed monospace TTF (e.g. JetBrains Mono / a VGA bitmap font) via `zgui` font API for terminal feel. Placed under `assets/fonts/`. If skipped, default font is used; everything else still works.

---

## 8. Data Flow (per frame)

```
poll keyboard + mouse
  → mode input handler (only `running` calls game.handle(cmd) → mutates sim)
  → camera.follow(player, map, viewport)
  → resolve inspect target (mouse tile else nearest visible hostile)
  → mode draw fn (reads RunState read-only):
        map_view → panels (header/vitals/loadout/inspect/log) → screens/overlays
  → FX overlay (scanlines, vignette, glow, banner) tinted by alertTint
  → swap buffers
```

All panel/screen draw fns take `*const RunState` (or narrower views) + `Layout` + `Theme` + `DrawList`; none mutate state.

---

## 9. Debug Overlay

The Debug panel (F1) remains the single `zgui.begin()` window — dev-only, floats on top, not shipped UI. F2 zone overlay stays as a draw-list overlay. Acceptable to keep one dev imgui window.

---

## 10. Testing

- **New pure-fn unit tests:**
  - `theme.alertTint` / `alertState`: ramp anchor + boundary values (0, 39/40, 69/70, 79/80, 100).
  - `camera`: clamp at map edges, small-floor centering, `screenToTile`∘`tileToScreen` round-trip for in-viewport tiles, off-viewport → null.
  - `layout`: region rects non-overlapping, sum to window size, scale correctly.
- **Unchanged:** all 33 integration + 79 inline sim tests stay green (render-only change).
- **Manual/visual gate:** run `zig build run`; verify FOV tri-state contrast, player findable, alert recolor at caution/elevated/lockdown, inspect follows mouse, inventory + menus navigable, no leftover floating windows (except Debug).

---

## 11. Build Order & Orchestration

1. **Foundation (sequential):** `theme` → `camera` → `layout` → `draw`. Each with unit tests. Everything downstream depends on these.
2. **Panels (parallelizable):** header, vitals, loadout, inspect, log_panel, map_view — independent, each reads RunState + foundation only.
3. **Wire `window.zig`:** remove all gameplay zgui windows, add mode dispatch + mouse input, draw running-mode composition.
4. **Screens (parallelizable):** inventory, main_menu, game_over + mode transitions.
5. **FX pass:** scanlines, vignette, glow, alert recolor, sync-glitch, lockdown banner, de-escalation smoothing.
6. **Polish + tests + optional font load.**

Subagents/workflow fan out on the parallelizable steps (2 and 4). Foundation and wiring stay sequential due to shared interfaces.

Branch: `milestone-9-ui-revamp`. Commit per logical step. Merge `--no-ff` after `zig build test` and a manual visual check pass.

---

## 12. Out of Scope (v1)

- Settings screen (tile scale, colorblind palettes, keybindings) — later M9 work.
- Audio (zaudio).
- Mouse click-to-move / click-to-act (hover-inspect only; keyboard remains primary).
- Minimap (follow camera + generous viewport sufficient for current 40×25 floors; revisit when floors grow).
- Save/load UI (M8).
- Campaign map / summary screens beyond game-over (M7).
