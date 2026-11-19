# Handoff Report — Cổng 3 (`CP3`): AI 3 Pha & Kịch Bản Bạch Đằng 1288

- **Status:** `READY_FOR_CODEX_REVIEW`
- **Scope Completed:** `C3-T1` (`2ddeda9`), `C3-T2` (`116efa3`), `C3-T3` (Slice-01 JSON data, `ScenarioLoader`, sandbox AI/Event wiring & 100 AI-vs-AI match verification).

## 1. Changed & Added Files (Cổng 3 / `C3-T3`)
- `scripts/core/scenario_loader.gd` — `ScenarioLoader` (`load_stage`, `load_battle_file`, `load_stage_dialogues`), pure `RefCounted`.
- `scripts/core/static_data_loader.gd` — Added `_load_json_variant`, `_index_array_by_id`, `load_json_dict`, `load_stage_settings`.
- `scripts/core/scenario_event_manager.gd` — `ScenarioEventManager` (`AND`/`OR`, `AlterTerrain`, `ApplyAreaEffect`, BFS `find_nearest_free_hex`, `once` restore; typed array fix at line 318).
- `scripts/core/scenario_victory_evaluator.gd` — `ScenarioVictoryEvaluator` (2 victory branches, 4 defeat branches, 3-star scoring).
- `scripts/core/scenario_director.gd`, `scripts/core/ai_visible_map_view.gd`, `scripts/core/battle_map_state.gd`, `scripts/core/battle_context.gd`, `scripts/core/battle_game_controller.gd`.
- `scripts/ai/ai_difficulty_profile.gd`, `scripts/ai/ai_action_candidate.gd`, `scripts/ai/ai_decision_matrix.gd` — 3-phase Utility AI (`Generators -> 5 Evaluators -> Weighted Sum + Additive RNG`) with isolated `decision_rng` (`DEC-011`).
- `scripts/presentation/battle_map_view.gd` — Dynamic hostile color palette (`is_hostile(1, faction_id)`) and `clear_key_areas()`.
- `scripts/presentation/battle_sandbox_cp1.gd` — Loads `stage_id 10101` via `ScenarioLoader`, runs Faction 2 AI on turn end / `[A]`, handles events/victory stars banner, preserves `[R]` live replay and `[F2]` 30×30 stress benchmark.
- `data/settings/troop_settings.json` — Appended clean naval troops `40202` and `40902`.
- `data/settings/stage_settings.json`, `data/settings/tactic_settings.json`, `data/battles/battle_10101.json` — Clean Slice-01 Bach Dang 1288 scenario (`12×10`, `odd_r`, `max_rounds: 10`, `enable_economy: false`).
- `tests/test_ai_decision_matrix.gd`, `tests/test_scenario_events_and_victory.gd`, `tests/test_slice01_bach_dang_and_ai_100_matches.gd`, `tests/capture_cp3_screenshots.gd`.
- `DECISIONS.md` (`DEC-008`..`DEC-011`), `ASSETS.md`, `TASKS.md`, `STATE.md`.

## 2. Verification & Test Results
- Headless runner: `$env:PATH = "$PWD;$env:PATH"; godot --headless --script tests/run_tests.gd` -> **`47/47 tests passed | 0 failed | 5959 assertions`**, exit code `0`, zero script errors.
- Includes **100 consecutive AI-vs-AI matches** on `stage_id: 10101` (first 20 with `enable_fog_of_war = true`): 0 soft-locks, `< 1500ms` max turn, Round 4 `evt_10101_tide_fall` verified, 100% deterministic `replay_from_dict` parity on HP, coordinates, outcome, round, and `BattleContext.rng.get_state()`.
- Visual capture (`gl_compatibility`, `1280×720`): `godot --disable-vsync --script tests/capture_cp3_screenshots.gd` -> verified `cp3_bach_dang_round1_water_hidden.png`, `cp3_bach_dang_round4_tide_fall_stakes.png`, and `cp3_bach_dang_victory_stars.png` (`CHIẾN THẮNG (2/3 SAO)`, `[REPLAY VERIFIED 100%]`).

## 3. Known Limitations (Scoped to Later Gates)
- `enable_economy = false` per Slice-01 (`CP5` implements Coin/Food/Tech/Mana economy).
- Interactive polish (8-state `BattleInputFSM` with 2-step attack confirmation, `CombatPreviewBox` floating panel, Briefing/3-Star modal dialogs, shaders & synthesized audio, 2-tier Save/Load) is scoped to `CP4`.
- In `battle_10101.json`, pure Normal-vs-Normal AI auto-play slightly favors Dai Nguyen (`40902` 720 HP flagship), whereas manual tactical play / casting `Hịch Tướng Sĩ` wins cleanly in 4 rounds.

## 4. How to Verify
1. Run headless suite: `$env:PATH = "$PWD;$env:PATH"; godot --headless --script tests/run_tests.gd`
2. Launch interactive scene (`scenes/battle/battle_sandbox_cp1.tscn`) with Godot 4.7.2: use `[A]` to trigger AI turn, `[Space]` to end turn (auto-runs Dai Nguyen AI), `[R]` to verify deterministic replay, `[F1/F2]` to switch 12×10 Bach Dang and 30×30 stress benchmark.
