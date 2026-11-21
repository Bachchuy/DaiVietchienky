# Handoff Report — GDD v3.5 & Editor-First Reconstruction Roadmap (`R1–R5`, `DEC-021..DEC-026`)

- **Status:** `READY_FOR_CODEX_REVIEW` (Documentation & Roadmap Synchronization — awaiting user review before starting `R1-T1` coding)
- **Scope Completed:**
  - Updated project governance, skill, decision log, task roadmap, current state, and all relevant GDD modules (`docs/gdd/` + `docs/assets/ASSET_CATALOG.md` + `docs/build_master_gdd.py`), and rebuilt `docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md`.

## 1. Key Decisions & Changes Recorded (`DEC-021..DEC-026`)
- **`DEC-021` (Vertical Slice First):** Complete Vertical Slice `10101` (Bạch Đằng 1288) to match/exceed `D:\code\HexCrown` across `R1–R4` before expanding to the remaining 5 Trần stages (`10102–10106`) in `R5`.
- **`DEC-022` (Graphics Roadmap & Mandatory Stop Gate `R4`):** Inherit clean assets from `D:\code\HexCrown\assets` (`res://assets_clean/hexcrown/`) in `R3` to replace flat `_draw()` polygons; **STOP and ask the user** before creating any new art assets at `R4` (where 2 Bạch Đằng samples — `Pixel Art` vs `2D Stylized EasyTech` — will be built for visual comparison using user-chosen tools).
- **`DEC-023` (`.tres` Custom Resources + Bidirectional `@tool` Stage Maps):** Replace static JSON data (`troop_settings`, `stage_settings`, `tactic_settings`, `facility_settings`, `codex_entries`, `battle_*.json`) with Inspector-editable `Resource` classes (`.tres` + `DataRegistry`) and `TileMapLayer`-based `stage_<id>_map.tscn` scenes. Keep `.json` strictly for runtime saves (`user://saves/`) and replays.
- **`DEC-024` (4-Tier Architecture `<= 400 lines/script`):** Reorganize to `res://data/` → `res://sim/` (pure `RefCounted`) → `BattleSession` (`Node` holding `BattleState` & emitting typed signals) → `res://game/battle/` & `res://ui/` (`.tscn` scenes + `theme.tres`, typed `@export` DI); mark the 3 monolithic procedural presentation files (`battle_hud_controller.gd`, `battle_map_view.gd`, `battle_sandbox_cp1.gd`) for deletion in `R1–R3`.
- **`DEC-025` (`CP1–CP5` Audit & `R1–R5` Gates):** Record in `TASKS.md` and `STATE.md` that `CP1–CP5` only passed the `Sim` core (`82/82` unit tests), while the old procedural UI/JSON/polygon shell is **REJECTED**; establish `R1–R5` (`CP6–CP10`) with mandatory `assert_button_reachable()` (`Viewport.push_input`) and Godot Editor 2D/Inspector verification.
- **`DEC-026` (Remove Combat Preview & 2-Step `AimingTarget`):** Eliminate `CombatPreviewBox` and `AimingTarget`; replace with `UnitInspector` (`res://ui/battle_hud/unit_inspector.tscn`) showing raw unit/terrain stats only and **1-tap direct attack** (`BattleInputFSM` simplified to 7 states) like `HexCrown`.

## 2. Changed Files
- Governance & Plans: `AGENTS.md` (Rule 9), `.agents/skills/project-architecture/SKILL.md`, `DECISIONS.md` (`DEC-021..DEC-026` + superseded markers on `DEC-002/004/010/012/015`), `TASKS.md`, `STATE.md`, `.ai/HANDOFF.md`.
- Primary & Secondary GDD Modules: `docs/gdd/README.md`, `docs/gdd/00_overview/document_control.md`, `docs/gdd/00_overview/conventions_glossary.md`, `docs/gdd/01_vision_player/vision_pillars.md`, `docs/gdd/01_vision_player/player_experience.md`, `docs/gdd/02_gameplay_systems/core_loop.md`, `docs/gdd/02_gameplay_systems/factions_economy.md`, `docs/gdd/02_gameplay_systems/meta_progression.md`, `docs/gdd/03_content_presentation/ui_ux.md`, `docs/gdd/03_content_presentation/audio_visual_narrative.md`, `docs/gdd/03_content_presentation/historical_framework.md`, `docs/gdd/04_production_roadmap/production_scope_mvp.md`, `docs/gdd/04_production_roadmap/implementation_plan.md`, `docs/gdd/04_production_roadmap/risks_open_decisions.md`, `docs/gdd/architecture/data_and_save_system.md`, `docs/gdd/ui_ux/battle_ui_and_rendering.md`, `docs/gdd/mechanics/combat_formulas.md`, `docs/gdd/mechanics/battlefield_economy.md`, `docs/gdd/mechanics/hex_grid_pathfinding.md`, `docs/gdd/mechanics/morale_and_status.md`, `docs/gdd/level_design/scenario_scripting_and_events.md`, `docs/gdd/ai/ai_decision_matrix.md`, `docs/gdd/appendices/appendix_a_benchmark_matrix.md`, `docs/gdd/appendices/appendix_c_extended_glossary.md`, `docs/assets/ASSET_CATALOG.md`, `docs/build_master_gdd.py`, and compiled `docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md`.

## 3. Verification
- Compiled Master GDD via `python docs/build_master_gdd.py` (exit code `0`).
- Cross-checked all modified docs for stale `CombatPreview` / `AimingTarget` / static JSON / `scripts/core` normative requirements (preserving historical `CHANGELOG_3.3_to_3.4.md` untouched).
- **Important Note:** No `R1` GDScript/scene refactoring was started yet, per `DEC-025` ("stop for user inspection of revised GDD & roadmap before coding `R1`"). Existing runtime code/tests remain at the `d9e30ca` codebase state until `R1` begins.

## 4. How to Verify
1. Inspect `TASKS.md`, `DECISIONS.md`, `STATE.md`, `AGENTS.md`, and `docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md`.
2. Re-run Master GDD compiler: `python docs/build_master_gdd.py`.
3. Approve transition to `R1-T1` when ready.
