# Handoff Report — Gate R1 Complete (`R1-T4` & `DEC-027` Full Slimming Package)

- **Status:** `READY_FOR_CODEX_REVIEW` (Gate `R1` `4/4` complete; ready for user `F5` check & Codex review before `R2-T1`)

## 1. Summary of Changes
- **Fast & Filterable Test Runner (`DEC-027`):**
  - `res://tests/test_case.gd`: added `stress_mode`, `assert_button_reachable()` (visibility, disabled state, size, viewport bounds, `clip_contents` ancestors), `push_click_control()`, and `_stop_audio_in_subtree()` in `after_each()`.
  - `res://tests/run_tests.gd`: added `--suite=<csv>`, `--stress`, `--fail-fast`, elapsed timer in `SUMMARY`, and `stress_mode` propagation.
  - `res://tests/test_slice01_bach_dang_and_ai_100_matches.gd`: runs `4` AI-vs-AI matches by default (`100` when `--stress` is passed).
- **Lean UI & Gameplay Smoke Suite (`R1-T4`):**
  - Added `res://tests/test_battle_smoke_e2e.gd` (`273` lines, `5` tests covering `BriefingModal`/`DialogueModal`/`PauseSettingsModal`/`ResultSummaryModal` reachability + `Viewport.push_input()` clicks at `1280x720` and `1560x720`, `UnitInspector` + 1-tap attack without `CombatPreviewBox`/`AIMING_TARGET`, move/undo/wait/skill, Round 4 TideFall + 3-star victory, and `main_menu.tscn` + save/resume roundtrip).
- **Deleted Bloat & Obsolete Files:**
  - Deleted `tests/e2e/` (`6,267` lines / `6` scripts + `.uid` files, including nested `OS.execute` runners).
  - Deleted `tests/capture_*.gd*` (`6` scripts) and `tests/artifacts/` (`21` PNGs + `.import` + `.gdignore`).
  - Deleted `.agents/skills/godot-3d-essentials/` (unused 3D skill in 2D project).
- **Streamlined Procedures & Stale Text Cleanup:**
  - Updated `scripts/presentation/tutorial_overlay.gd` (`tip_two_step_attack` updated to reference `UnitInspector` + 1-tap attack).
  - Streamlined `AGENTS.md` (no default screenshot capture/reading, no reading/rebuilding 443 KB `TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md`, targeted `--suite=` iteration, `--stress` only on major Sim/AI changes or Gate sign-off).
  - Updated `DECISIONS.md` (`DEC-027`), `TASKS.md` (`R1-T4` `[x]`), and `STATE.md` (`4/15`, Gate `R1` complete, `C5-T3` export toolchain note preserved).

## 2. Tests Run & Actual Verification Results
- `.\godot.cmd --headless --script res://tests/run_tests.gd -- --suite=smoke`: `5/5` passed | `0` failed | `170` assertions.
- `.\godot.cmd --headless --script res://tests/run_tests.gd` (full fast suite): `94/94` passed | `0` failed | `7048` assertions (down from `43.5s` + 2–3m nested E2E).
- `tests/` reduced from `34` `.gd` files (`11,735` lines) + `21` PNGs down to `23` `.gd` files (`5,357` lines) + `0` PNGs.

## 3. Known Limitations
- Legacy presentation files (`battle_map_view.gd` `880` lines, `battle_sandbox_cp1.gd` `756` lines) remain until `R3-T4` (`battle.tscn` + `TileMapLayer`).
- Static data remains JSON until Gate `R2` (`R2-T1..R2-T3`).
- Local Godot Export Templates (`.tpz`) / `ANDROID_HOME` not installed yet (`C5-T3`).

## 4. How to Verify (`F5` Checklist)
1. Press `F5` (`res://scenes/battle/battle_sandbox_cp1.tscn`) or open `res://scenes/main_menu.tscn`: check `BỎ QUA (ESC)` / `BẮT ĐẦU TRẬN ĐÁNH` buttons at the bottom of `BriefingModal`.
2. Dismiss opening modals (`Esc` or `BỎ QUA`), click a friendly unit (`(2,8)`) to verify `UnitInspector` shows raw stats (no damage preview), move/undo (`Z`), or tap an enemy in red range once for immediate 1-tap attack.
3. Press `Esc` or `⏸ TẠM DỪNG` to check `PauseSettingsModal` sliders and unclipped footer buttons.
