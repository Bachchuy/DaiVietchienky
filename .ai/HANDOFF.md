# Handoff: R3-T4 & Gate R3 — Editor-First battle.tscn & Legacy Removal
- **Status:** `READY_FOR_CODEX_REVIEW`
- **Changed Files (R3-T4):**
  - Added: `game/battle/battle.tscn`, `game/battle/battle.gd` (396L), `game/battle/battle_fx_bridge.gd` (194L)
  - Updated: `hex_overlay_layer.gd`, `battle_map.gd`, `stage_map_tool.gd`, `battle_input_fsm.gd`, `battle_input_rules.gd`, `combat_juice_helper.gd`, `battle_hud.gd`, `campaign_menu_controller.gd`, `project.godot`, 8 suites in `tests/`
  - Deleted: `battle_map_view.gd`, `battle_sandbox_cp1.gd`, `battle_sandbox_cp1.tscn`, `hud_sandbox_bridge.gd`
- **Tests Run:**
  - `.\godot.cmd --headless --script res://tests/run_tests.gd -- --suite=smoke,hud,fsm,map_view` -> `32/32 passed | 0 failed | 939 assertions`
  - `.\godot.cmd --headless --script res://tests/run_tests.gd` -> `110/110 passed | 0 failed | 7967 assertions`
  - `.\godot.cmd --headless --script res://tests/run_tests.gd -- --stress` -> `110/110 passed | 0 failed | 8159 assertions` (zero `SCRIPT ERROR`)
- **Known Limitations:** Next task **`R4-T1`** is the **mandatory user-stop gate** (`DEC-022`); no new graphics/assets may be created until user approves style & tools.
- **Manual Check (`F5`):**
  1. Press `F5` -> verify `main_menu.tscn` boots and click **VÀO CHIẾN DỊCH BẠCH ĐẰNG 1288** -> transitions cleanly to `res://game/battle/battle.tscn`.
  2. Dismiss Briefing, select unit (blue reach + red targets appear on `TileMapLayer`), move/undo/wait/cast skill/end turn `[Space]` -> play through Round 4 TideFall & Victory at 60 FPS.
  3. Open `res://game/battle/battle.tscn` in Godot Editor -> verify 2D View & Inspector exports are visible without warnings.
