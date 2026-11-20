# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **ĐANG THỰC HIỆN CỔNG 5 (`CP5` / Gates `P3–P5`)** — Hoàn thành `C5-T2` (Gói Chiến dịch Thời Trần 6 màn, Tutorial ngữ cảnh, Codex lịch sử & Asset IP Gate sạch 100%).
- **Nhiệm vụ vừa xong:** `C5-T2` (`stage_settings.json` 6 màn + `battle_10101..10106.json` gồm Vân Đồn `enable_economy: true`, 12 binh chủng sạch thế kỷ XIII, 9 danh tướng `general_settings.json`, `codex_entries.json` phân tách `938/981/1288`, `CampaignMenuController`, `TutorialOverlay`, `CodexPanel`, và `AssetIpAuditor`).
- **Tiến độ Cổng 5:** `2 / 3` nhiệm vụ hoàn thành (Cổng 1: `6 / 6`, Cổng 2: `4 / 4`, Cổng 3: `3 / 3`, Cổng 4: `3 / 3`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `79/79 passed | 0 failed | 6456 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C5-T2`: Hoàn thiện gói dữ liệu & giao diện Chiến dịch thời Trần 6 màn (`data/settings/stage_settings.json`, `data/battles/battle_10102..10106.json`, `data/settings/general_settings.json`, `data/settings/codex_entries.json`, mở rộng `data/settings/troop_settings.json` lên 12 binh chủng sạch không thuốc súng — toàn bộ đăng ký trong `ASSETS.md`), triển khai `CampaignMenuController` (`scenes/main_menu.tscn`), `TutorialOverlay`, `CodexPanel` (`scenes/ui/codex_panel.tscn`), và `AssetIpAuditor` (`scripts/core/asset_ip_auditor.gd`), kiểm chứng qua 5 bài test TDD tại `tests/test_tran_campaign_and_ip_gate.gd` (`79/79` pass).
- `C5-T1`: Triển khai `BattleEconomy` (`scripts/core/battle_economy.gd`) và `data/settings/facility_settings.json` (đã đăng ký trong `ASSETS.md`), tích hợp 7 lệnh kinh tế (`RobAreaIncomeCommand`, `TradeCommand`, `UpgradeFacilityCommand`, `FortifyHexCommand`, `UnlockBattleTechCommand`, `RecruitCommand`, `ApplyTacticCommand`) vào `BattleCommands`, `BattleContext`, `BattleGameController`, `ScenarioLoader`, `BattleInputFSM` và `BattleHudController`, kiểm chứng qua 5 bài test TDD tại `tests/test_battlefield_economy.gd` (`74/74` pass).
- `C4-T3`: Hoàn thiện gói Game Feel / Juice sạch 100% (`assets_clean/shaders/hit_flash.gdshader`, `assets_clean/shaders/water_flow.gdshader`, 7 tệp âm thanh PCM `.wav` tổng hợp sạch tại `assets_clean/audio/` đã đăng ký trong `ASSETS.md`), `CombatJuiceHelper` (`scripts/presentation/combat_juice_helper.gd`), `BattleAudioManager` (`scripts/presentation/battle_audio_manager.gd`), và `BattleSaveManager` (`scripts/core/battle_save_manager.gd`), tích hợp vào `BattleMapView` và `BattleSandboxCP1`, kiểm chứng qua 6 bài test TDD tại `tests/test_juice_and_save_load.gd` (`69/69` pass).
- `C4-T2`: Triển khai `BattleHudController` (`scripts/presentation/battle_hud_controller.gd`), nâng cấp `BattleMapView` (vẽ thanh HP chia vạch `100 HP`, nhấp nháy lượng HP dự kiến mất khi ngắm đánh, huy hiệu hình học sĩ khí/CC phi màu sắc, màn sương Fog of War 2 mức trên `FogOfWarLayer z=50`), tích hợp đầy đủ vào `BattleSandboxCP1` kèm chặn click xuyên HUD (`_is_screen_point_on_hud`), và bổ sung 7 bài test TDD tại `tests/test_battle_hud_and_flow.gd` (`63/63` pass).
- `C3-T3`: Hoàn thành bộ JSON Slice-01 (`data/settings/stage_settings.json`, `data/settings/tactic_settings.json`, `data/battles/battle_10101.json`, mở rộng `data/settings/troop_settings.json` thêm `40202`/`40902`), `ScenarioLoader` + `StaticDataLoader.load_stage_settings`, tách RNG quyết định AI (`DEC-011`), màu phe đối địch động trong `BattleMapView`, tích hợp Slice-01 + AI + Replay vào `BattleSandboxCP1`, xác minh 100 trận AI-vs-AI liên tiếp 0 treo lượt & `< 1.5s/lượt`, cùng 3 ảnh chụp `gl_compatibility` (`47/47` tests pass).
- `C3-T2`: Hoàn thành `ScenarioEventManager` (`Trigger – Condition AND/OR – Action`, `AlterTerrain`, `ApplyAreaEffect`, `SpawnReinforcements` BFS `find_nearest_free_hex`, `once` & restore), `ScenarioVictoryEvaluator` (2 nhánh Thắng, 4 nhánh Thua, chấm 3 Sao) và nối vào vòng lặp 7 pha `BattleGameController` (`44/44` tests pass).
- `C3-T1`: Hoàn thành hệ thống AI 3 pha (`ScenarioDirector`, `AIVisibleMapView`, `AIDifficultyProfile`, `AIActionCandidate`, `AIDecisionMatrix`).

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
