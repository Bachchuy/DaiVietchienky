# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **ĐANG THỰC HIỆN CỔNG 4 (`CP4` / Gate `P2`)** — Hoàn thành `C4-T2` (HUD Map-First `>= 80%`, `CombatPreviewBox`, Top Bar, Briefing/Dialogue & Tổng kết 3 Sao).
- **Nhiệm vụ vừa xong:** `C4-T2` (`BattleHudController`, `TopStatusBar` ẩn tài nguyên khi `enable_economy = false`, `BottomCommandDock` 6 nút, `CombatPreviewBox` 2 bước kẹp biên viewport, `BriefingModal`, `DialogueModal` khóa camera, `ResultSummaryModal` 3 Sao + 4 nguyên nhân thua + `CombatLogPanel`, `PauseSettingsModal`, thanh HP chia vạch `100 HP`, biểu tượng sĩ khí phi màu sắc & màn sương Fog of War).
- **Tiến độ Cổng 4:** `2 / 3` nhiệm vụ hoàn thành (Cổng 1: `6 / 6`, Cổng 2: `4 / 4`, Cổng 3: `3 / 3`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `63/63 passed | 0 failed | 6250 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C4-T2`: Triển khai `BattleHudController` (`scripts/presentation/battle_hud_controller.gd`), nâng cấp `BattleMapView` (vẽ thanh HP chia vạch `100 HP`, nhấp nháy lượng HP dự kiến mất khi ngắm đánh, huy hiệu hình học sĩ khí/CC phi màu sắc, màn sương Fog of War 2 mức trên `FogOfWarLayer z=50`), tích hợp đầy đủ vào `BattleSandboxCP1` kèm chặn click xuyên HUD (`_is_screen_point_on_hud`), và bổ sung 7 bài test TDD tại `tests/test_battle_hud_and_flow.gd` (`63/63` pass).
- `C3-T3`: Hoàn thành bộ JSON Slice-01 (`data/settings/stage_settings.json`, `data/settings/tactic_settings.json`, `data/battles/battle_10101.json`, mở rộng `data/settings/troop_settings.json` thêm `40202`/`40902`), `ScenarioLoader` + `StaticDataLoader.load_stage_settings`, tách RNG quyết định AI (`DEC-011`), màu phe đối địch động trong `BattleMapView`, tích hợp Slice-01 + AI + Replay vào `BattleSandboxCP1`, xác minh 100 trận AI-vs-AI liên tiếp 0 treo lượt & `< 1.5s/lượt`, cùng 3 ảnh chụp `gl_compatibility` (`47/47` tests pass).
- `C3-T2`: Hoàn thành `ScenarioEventManager` (`Trigger – Condition AND/OR – Action`, `AlterTerrain`, `ApplyAreaEffect`, `SpawnReinforcements` BFS `find_nearest_free_hex`, `once` & restore), `ScenarioVictoryEvaluator` (2 nhánh Thắng, 4 nhánh Thua, chấm 3 Sao) và nối vào vòng lặp 7 pha `BattleGameController` (`44/44` tests pass).
- `C3-T1`: Hoàn thành hệ thống AI 3 pha (`ScenarioDirector`, `AIVisibleMapView`, `AIDifficultyProfile`, `AIActionCandidate`, `AIDecisionMatrix`).

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
