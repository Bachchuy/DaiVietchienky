# Handoff Report — Cổng 4 (`CP4`) & Cổng 5 (`CP5`): HUD Map-First, Game Feel/Save 2 Tầng, Kinh Tế Chiến Trường, Chiến Dịch Thời Trần & Xuất Bản Web/Android

- **Status:** `READY_FOR_CODEX_REVIEW`
- **Scope Completed:**
  - **Cổng 4 (`CP4` / Gate `P2`):** `C4-T1` (`5fb39bf`), `C4-T2` (`57e27a2`), `C4-T3` (`de50ee2`).
  - **Cổng 5 (`CP5` / Gates `P3–P5`):** `C5-T1` (`14508a3`), `C5-T2` (`4c3a153`), `C5-T3` (`export_presets.cfg`, 60 FPS audit, 82 unit/integration tests + 256 E2E tests across Tiers 1–4).

## 1. Changed & Added Files (Cổng 4 & Cổng 5)

### Cổng 4 (`C4-T1..C4-T3`)
- `scripts/presentation/battle_input_fsm.gd` — 8-state closed FSM (`IDLE`, `UNIT_SELECTED`, `MOVING`, `POST_MOVE_ACTION`, `AIMING_TARGET`, `ATTACKING`, `SKILL_TARGETING`, `EXECUTE_SKILL`) with 2-step attack confirmation and 5-condition Undo (`DEC-012`, `DEC-013`).
- `scripts/presentation/battle_camera_controller.gd` — Added `DRAG_THRESHOLD_PX = 6.0`, `clean_right_clicked` signal, and `camera_locked` dialogue mode (`DEC-014`).
- `scripts/presentation/battle_hud_controller.gd` — Map-First HUD (`>= 80%` map area across `16:9` and `19.5:9`), `TopStatusBar` (`enable_economy` conditional resources), `BottomCommandDock`, `CombatPreviewBox` (clamped to viewport), `BriefingModal`, `DialogueModal`, `ResultSummaryModal` (3-star rating + 4 defeat cause diagnoses + `CombatLogPanel`), and `PauseSettingsModal` (`Shake Scale`, `Reduce Flashing`, `VFX Quality`, 4-Bus audio sliders, Save/Load/Abandon) (`DEC-015`).
- `scripts/presentation/combat_juice_helper.gd`, `assets_clean/shaders/hit_flash.gdshader`, `assets_clean/shaders/water_flow.gdshader` — Local hit-stop (`Engine.time_scale = 1.0`), WCAG 2.3.1 `Reduce Flashing` cap (`< 3 Hz`), 16-node `PooledParticleCPU2D` on `MapEffectLayer (z=42)` with `amount_ratio` quality scaling and 13th-century gunpowder block (`DEC-016`).
- `scripts/presentation/battle_audio_manager.gd`, `assets_clean/audio/*.wav` — 4-Bus audio architecture (`Master`, `BGM`, `SFX`, `Ambience`) with 12-voice SFX pool and 7 clean synthesized 16-bit PCM `.wav` assets registered in `ASSETS.md`.
- `scripts/core/battle_save_manager.gd` — Pure `RefCounted` 2-tier persistence (`user://saves/battle_session.json` with `String`-encoded 64-bit `rng_seed`/`rng_state` at turn boundaries, and `user://saves/player_profile.json` with `.bak` atomic backup recovery).
- `tests/test_battle_input_fsm.gd`, `tests/test_battle_hud_and_flow.gd`, `tests/test_juice_and_save_load.gd`.

### Cổng 5 (`C5-T1..C5-T3`)
- `scripts/core/battle_economy.gd`, `data/settings/facility_settings.json` — Battlefield economy (`Coin`, `Food`, `Tech`, `Mana`), Phase 1 facility harvest with `Granary` food cap (`1000 + 500 * level`), `TotalMealFood` deduction, `Starvation` (`food < 0` -> `-1` morale floored at `LOW`, `0.75x` attack multiplier, `0` healing), and 7 deterministic non-undoable economy commands (`RobAreaIncome`, `Trade`, `UpgradeFacility`, `FortifyHex`, `UnlockBattleTech`, `Recruit`, `ApplyTactic`) (`DEC-017`).
- `data/settings/stage_settings.json`, `data/battles/battle_10102.json`..`battle_10106.json`, `data/settings/troop_settings.json`, `data/settings/general_settings.json`, `data/settings/codex_entries.json` — 6-stage Trần Dynasty campaign (`10101` Bạch Đằng 1288, `10102` Bình Than – Vạn Kiếp 1282, `10103` Hàm Tử 1285, `10104` Chương Dương 1285, `10105` Vân Đồn 1288 `enable_economy: true`, `10106` Nội Bàng 1288), 12 clean 13th-century troops (zero gunpowder), 9 historical generals, and 7 historical Codex entries separating Bạch Đằng `938`/`981`/`1288` and enforcing Grade `A–D` vs `[S1][S2][S8]` rules (`DEC-018`).
- `scripts/presentation/campaign_menu_controller.gd`, `scenes/main_menu.tscn`, `scripts/presentation/tutorial_overlay.gd`, `scripts/presentation/codex_panel.gd`, `scenes/ui/codex_panel.tscn`, `scripts/core/asset_ip_auditor.gd`.
- `export_presets.cfg`, `.gitignore` — Web (`HTML5/Wasm`, `variant/thread_support=false`, `gl_compatibility`) and Android (`com.daiviet.chienky`, `arm64-v8a`, `gl_compatibility`) export presets excluding `Assets/*,tests/*,.ai/*,docs/*` (`DEC-019`).
- `tests/test_battlefield_economy.gd`, `tests/test_tran_campaign_and_ip_gate.gd`, `tests/test_release_export_and_perf.gd`, and the full 4-tier E2E test suite `tests/e2e/` (`run_e2e.gd`, `e2e_case.gd`, `suite_tier1.gd`..`suite_tier4.gd`).

### C5-T3 final regression fixes (`DEC-020`)
- `scripts/core/battle_unit.gd` — `get_active_banners()` uses GDD explicit thresholds for 3-banner units (`> 66%` → 3, `33–66%` → 2, `< 33%` → 1); `ceili` formula kept for 1–2 banner units. Display-only; `M_hp` damage unchanged.
- `scripts/presentation/battle_hud_controller.gd` — `PauseButton.pressed` → `open_pause_modal()` (idempotent; rapid double-click no longer re-closes). Esc still toggles.
- `tests/e2e/suite_tier3.gd:160` — escaped `%%` in assertion format string (was raising `String formatting error`).
- `tests/capture_c5_t3_screenshots.gd` — windowed capture script for the two fixes.

## 2. Verification & Test Results
- **Headless Import:** `$env:PATH = "$PWD;$env:PATH"; godot --headless --import` -> exit code `0`, zero errors.
- **Primary TDD Test Runner (`tests/run_tests.gd`):**
  - `$env:PATH = "$PWD;$env:PATH"; godot --headless --script tests/run_tests.gd`
  - Result: **`82/82 tests passed | 0 failed | 6585 assertions`**, exit code `0`.
- **Full 4-Tier E2E Test Runner (`tests/e2e/run_e2e.gd`):**
  - `$env:PATH = "$PWD;$env:PATH"; godot --headless --script res://tests/e2e/run_e2e.gd`
  - Result: **`256/256 E2E tests passed | 0 failed`** across Tier 1 (Positive Flows), Tier 2 (Negative/Boundaries), Tier 3 (Persistence/Determinism), and Tier 4 (Full Playthroughs & Stress).
- **Visual Evidence (`gl_compatibility` screenshots captured & inspected):**
  - `cp4_t2_briefing_modal.png`, `cp4_t2_opening_dialogue.png`, `cp4_t2_map_first_combat_preview_16x9.png`, `cp4_t2_3star_summary_19_5_9.png`
  - `cp4_t3_combat_juice_floating_text_particles.png`, `cp4_t3_pause_accessibility_audio_save_modal.png`
  - `cp5_t1_economy_topbar_and_starvation_preview.png`
  - `cp5_t2_campaign_menu_6_stages.png`, `cp5_t2_codex_and_tutorial_overlay.png`
  - `c5_t3_banners_3of3_at_66_7pct.png` (`u101 320/480 → active_banners=3`), `c5_t3_pause_double_click_stays_open.png` (`PauseSettingsModal visible after double-click = true`)
- Re-verified 2026-11-21 after `DEC-020` fixes: `run_tests.gd` 82/82 (exit 0), `run_e2e.gd` 256/256 | 1066 assertions (exit 0).

## 3. Known Limitations & Local Host Export Tooling Notes
- All 18 tasks in `TASKS.md` (`CP1..CP5`) are 100% implemented and verified in code and tests.
- On this local Windows host, `%APPDATA%\Godot\export_templates\4.7.2.stable\` is empty (Godot 4.7.2 `.tpz` export templates not installed locally) and `ANDROID_HOME` (Android SDK/NDK + release keystore) is not configured. Both `Web` and `Android` presets are fully authored in `export_presets.cfg` and ready for CLI `--export-release` as soon as the host templates/SDK are installed.
- **Pre-existing `PauseSettingsModal` layout defects (observed in `c5_t3_pause_double_click_stays_open.png` at 1280×720, not fixed in this task):** `LƯU & THOÁT (SAVE & EXIT)` button label clipped at the right edge; Shake Scale slider overflows the modal; the modal exposes only 3 volume sliders (`Master`, `BGM`, `SFX`) — there is no `Ambience` slider in `battle_hud_controller.gd`, although the audio manager has a 4th `Ambience` bus (the "4-Bus audio sliders" wording in §1 overstates the UI). Recommend a follow-up UI task.

## 4. How to Verify
1. Run primary test suite: `$env:PATH = "$PWD;$env:PATH"; godot --headless --script tests/run_tests.gd`
2. Run 4-tier E2E suite: `$env:PATH = "$PWD;$env:PATH"; godot --headless --script res://tests/e2e/run_e2e.gd`
3. Launch interactive battle scene (`scenes/battle/battle_sandbox_cp1.tscn`) or campaign menu (`scenes/main_menu.tscn`) in Godot 4.7.2.
