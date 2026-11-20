# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **ĐÃ HOÀN THÀNH CỔNG 4 (`CP4` / Gate `P2`) & CỔNG 5 (`CP5` / Gates `P3–P5`)** — Hoàn tất 100% lộ trình 18/18 nhiệm vụ (`CP1..CP5`), sẵn sàng duyệt Cổng 4 + Cổng 5.
- **Nhiệm vụ vừa xong:** `C5-T3` (Cấu hình `export_presets.cfg` cho Web HTML5/Wasm `variant/thread_support=false` & Android `arm64-v8a` `com.daiviet.chienky` loại trừ `Assets/*`, kiểm thử hiệu năng 60 FPS `<= 16.67 ms/frame` trên sa bàn `12×10` & Stress `30×30` 44 đơn vị, cùng hồi quy toàn diện 82 unit/integration tests + 256 E2E tests).
- **Tiến độ toàn dự án:** `18 / 18` nhiệm vụ hoàn thành (Cổng 1: `6 / 6`, Cổng 2: `4 / 4`, Cổng 3: `3 / 3`, Cổng 4: `3 / 3`, Cổng 5: `3 / 3`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `82/82 passed | 0 failed | 6585 assertions`.
- **Trạng thái bộ E2E (`tests/e2e/run_e2e.gd`):** `256/256 passed | 0 failed` (Tier 1..4).

---

## Lịch sử hoàn thành gần nhất
- `C5-T3`: Thiết lập `export_presets.cfg` chuẩn Godot 4.7 cho Web (`HTML5/Wasm`, `gl_compatibility`, `variant/thread_support=false`, `exclude_filter="Assets/*,tests/*,.ai/*,docs/*"`) và Android (`com.daiviet.chienky`, `arm64-v8a`, `gl_compatibility`, `exclude_filter="Assets/*,tests/*,.ai/*,docs/*"`), xác minh hiệu năng 60 FPS (`<= 16.67 ms/frame` trên cả `12×10` Bạch Đằng lẫn `30×30` 44 đơn vị và tốc độ AI `< 1.5s` chiến thuật / `< 3.0s` kinh tế), kiểm tra kỷ luật chỉ ghi `user://`, và vượt qua 100% bộ kiểm thử hồi quy (`82/82` trong `tests/run_tests.gd` + `256/256` trong `tests/e2e/run_e2e.gd`).
- `C5-T2`: Hoàn thiện gói dữ liệu & giao diện Chiến dịch thời Trần 6 màn (`data/settings/stage_settings.json`, `data/battles/battle_10102..10106.json`, `data/settings/general_settings.json`, `data/settings/codex_entries.json`, mở rộng `data/settings/troop_settings.json` lên 12 binh chủng sạch không thuốc súng — toàn bộ đăng ký trong `ASSETS.md`), triển khai `CampaignMenuController` (`scenes/main_menu.tscn`), `TutorialOverlay`, `CodexPanel` (`scenes/ui/codex_panel.tscn`), và `AssetIpAuditor` (`scripts/core/asset_ip_auditor.gd`), kiểm chứng qua 5 bài test TDD tại `tests/test_tran_campaign_and_ip_gate.gd` (`79/79` pass).
- `C5-T1`: Triển khai `BattleEconomy` (`scripts/core/battle_economy.gd`) và `data/settings/facility_settings.json` (đã đăng ký trong `ASSETS.md`), tích hợp 7 lệnh kinh tế (`RobAreaIncomeCommand`, `TradeCommand`, `UpgradeFacilityCommand`, `FortifyHexCommand`, `UnlockBattleTechCommand`, `RecruitCommand`, `ApplyTacticCommand`) vào `BattleCommands`, `BattleContext`, `BattleGameController`, `ScenarioLoader`, `BattleInputFSM` và `BattleHudController`, kiểm chứng qua 5 bài test TDD tại `tests/test_battlefield_economy.gd` (`74/74` pass).
- `C4-T3`: Hoàn thiện gói Game Feel / Juice sạch 100% (`assets_clean/shaders/hit_flash.gdshader`, `assets_clean/shaders/water_flow.gdshader`, 7 tệp âm thanh PCM `.wav` tổng hợp sạch tại `assets_clean/audio/` đã đăng ký trong `ASSETS.md`), `CombatJuiceHelper` (`scripts/presentation/combat_juice_helper.gd`), `BattleAudioManager` (`scripts/presentation/battle_audio_manager.gd`), và `BattleSaveManager` (`scripts/core/battle_save_manager.gd`), tích hợp vào `BattleMapView` và `BattleSandboxCP1`, kiểm chứng qua 6 bài test TDD tại `tests/test_juice_and_save_load.gd` (`69/69` pass).
- `C4-T2`: Triển khai `BattleHudController` (`scripts/presentation/battle_hud_controller.gd`), nâng cấp `BattleMapView` (vẽ thanh HP chia vạch `100 HP`, nhấp nháy lượng HP dự kiến mất khi ngắm đánh, huy hiệu hình học sĩ khí/CC phi màu sắc, màn sương Fog of War 2 mức trên `FogOfWarLayer z=50`), tích hợp đầy đủ vào `BattleSandboxCP1` kèm chặn click xuyên HUD (`_is_screen_point_on_hud`), và bổ sung 7 bài test TDD tại `tests/test_battle_hud_and_flow.gd` (`63/63` pass).
- `C4-T1`: Triển khai `BattleInputFSM` 8 trạng thái khép kín (`scripts/presentation/battle_input_fsm.gd`), nâng cấp `BattleCameraController` (`DRAG_THRESHOLD_PX = 6.0`, `clean_right_clicked`, `camera_locked`) và `BattleMapView` (`SkillAreaLayer`), tích hợp vào `BattleSandboxCP1` (`56/56` pass).

---

## Bị kẹt / Giới hạn môi trường máy chủ cục bộ (`C5-T3` CLI Binary Export)
- **Không có nhiệm vụ mã nguồn nào bị kẹt** (`18/18` nhiệm vụ trong `TASKS.md` đã hoàn thành 100% và qua toàn bộ bài test).
- **Ghi chú giới hạn công cụ hệ thống cho bước đóng gói binary CLI (`--export-release`):**
  1. Thư mục mẫu xuất bản Godot cục bộ (`%APPDATA%\Godot\export_templates\4.7.2.stable\`) trên máy Windows hiện tại đang trống (chưa cài gói `.tpz` Export Templates của Godot 4.7.2).
  2. Biến môi trường `ANDROID_HOME` / `ANDROID_SDK_ROOT` cùng bộ công cụ Android SDK/NDK & Release Keystore chưa được cài đặt trên máy chủ cục bộ.
  3. **Biện pháp đã thực thi:** Đã cấu hình đầy đủ `export_presets.cfg` chuẩn cho cả `Web` và `Android`, xác minh `godot --headless --import` sạch `0` lỗi, xác minh đóng gói gói dữ liệu `.pck` (`--export-pack "Web"`), kiểm chứng hiệu năng 60 FPS (`<= 16.67 ms/frame`) trên cả desktop/headless và vượt qua trọn vẹn `82/82` bài test `tests/run_tests.gd` cùng `256/256` bài test E2E `tests/e2e/run_e2e.gd`. Khi máy cài đặt Godot 4.7.2 Export Templates (`.tpz`) và Android SDK, có thể chạy ngay lệnh `godot --headless --export-release "Web" build/web/index.html` và `godot --headless --export-debug "Android" build/android/dai_viet_chien_ky.apk`.
