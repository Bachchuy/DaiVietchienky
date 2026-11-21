# Handoff Report — `R2-T1` Custom `Resource` Definitions
- **Status:** `READY_FOR_CODEX_REVIEW` (Gate `R1` committed at `8024d89`; `R2-T1` ready before `R2-T2`)

## 1. Changed Files
- `data/defs/troop_def.gd` (`264` lines), `general_def.gd` (`131`), `tactic_def.gd` (`61`), `facility_def.gd` (`88`), `codex_entry_def.gd` (`57`), `data_registry.gd` (`207`): pure `Resource` schemas with `@export` groups/enums/ranges, `from_dict()`/`to_*dict()` parity, `DataRegistry` typed lookups & `validate()`, zero `sim/`/`Node` imports.
- `ASSETS.md`: registered the 6 `res://data/defs/*.gd` files for `AssetIpAuditor`.
- `tests/test_data_defs.gd` (`250` lines): JSON parity across all 12 troops, 9 generals, 1 tactic, 7 facilities, 7 codex entries; `BattleUnit.from_troop_dict()` equivalence; `DataRegistry` lookups & `validate()`; `.tres` save/reload roundtrip under `user://tmp_test_data_defs/`.
- `TASKS.md`, `STATE.md`: marked `R2-T1` `[x]` (`5/15`).

## 2. Tests Run & Actual Results
- `.\godot.cmd --headless --script res://tests/run_tests.gd -- --suite=data_defs,tran_campaign`: `9/9` passed | `0` failed | `879` assertions (`1.53s`).
- `.\godot.cmd --headless --script res://tests/run_tests.gd`: `98/98` passed | `0` failed | `7853` assertions (`7.67s`).

## 3. Known Limitations
- `StageDef` & Sub-Resources (`R2-T2`) and `.tres` data generation / JSON removal (`R2-T3`) are scheduled next.
- `CodexEntryDef.evidence_grade` uses `@export var evidence_grade: String = ""` (Godot 4.7 `@export_enum` rejects empty `""` arg).

## 4. Verification Checklist (Godot Editor)
1. In FileSystem dock, right-click → **Create New → Resource** and search `TroopDef`, `GeneralDef`, `TacticDef`, `FacilityDef`, `CodexEntryDef`, `DataRegistry`.
2. Inspect `TroopDef` / `DataRegistry` groups and enums in the Inspector.
