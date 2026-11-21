# Sổ Tay Tài Nguyên & Thư Viện Sạch (`ASSETS.md`)

Mọi tệp đồ họa, âm thanh, shader hoặc thư viện dùng trong dự án **bắt buộc** phải ghi nhận tại đây trước khi nạp vào mã nguồn. Tuyệt đối không nạp bất kỳ tệp nào trong thư mục `Assets/` cũ (đã chặn bằng `.gitignore` và `Assets/.gdignore`).

---

## 1. Thư viện ngoài (External Libraries / Addons)

| Tên thư viện | Phiên bản | Nguồn / Giấy phép | Trạng thái | Mục đích |
|---|---|---|---|---|
| *(Không dùng thư viện ngoài)* | — | Thuần Godot 4.7 Standard API + GDScript 2.0 | Đang áp dụng | Toàn bộ mô phỏng, hiển thị, camera và bộ chạy test `tests/run_tests.gd` tự viết 100% không phụ thuộc addon. |

---

## 2. Tài nguyên Đồ họa, Shader & Dữ liệu Sạch (`res://`)

| Đường dẫn `res://` | Loại | Nguồn gốc / Phương thức tạo | Bản quyền | Mục đích sử dụng |
|---|---|---|---|---|
| `res://icon.svg` | Vector SVG | Khởi tạo mặc định từ Godot Engine 4.7 | MIT / Public Domain | Biểu tượng ứng dụng mặc định trong `project.godot`. |
| `res://assets_clean/icons/token_infantry.svg` | Vector SVG | Tự biên soạn mã SVG hình học sạch 100% | Độc quyền dự án (100% sạch) | Biểu tượng nhánh Bộ binh cho `UnitModelLayer` & `StrategicTokenLayer`. |
| `res://assets_clean/icons/token_archer.svg` | Vector SVG | Tự biên soạn mã SVG hình học sạch 100% | Độc quyền dự án (100% sạch) | Biểu tượng nhánh Cung/Nỏ cho `UnitModelLayer` & `StrategicTokenLayer`. |
| `res://assets_clean/icons/token_cavalry.svg` | Vector SVG | Tự biên soạn mã SVG hình học sạch 100% | Độc quyền dự án (100% sạch) | Biểu tượng nhánh Kỵ/Tượng binh cho `UnitModelLayer` & `StrategicTokenLayer`. |
| `res://assets_clean/icons/token_naval.svg` | Vector SVG | Tự biên soạn mã SVG hình học sạch 100% | Độc quyền dự án (100% sạch) | Biểu tượng nhánh Thủy quân chiến thuyền cho `UnitModelLayer` & `StrategicTokenLayer`. |
| `res://assets_clean/emblems/dai_viet_emblem.png` | Raster PNG `128×128` | Sinh mới bằng AI (`image-generator`) — họa tiết trống đồng Đông Sơn & rồng mây thời Trần trên nền sơn son | Độc quyền dự án (100% sạch) | Huy hiệu phe Đại Việt trên HUD & cờ chỉ huy. |
| `res://assets_clean/emblems/dai_nguyen_emblem.png` | Raster PNG `128×128` | Sinh mới bằng AI (`image-generator`) — khiên sắt & mũ trụ sừng thảo nguyên kết hợp sóng nước | Độc quyền dự án (100% sạch) | Huy hiệu phe Đại Nguyên trên HUD & cờ chỉ huy. |
| `res://data/battles/battle_10101.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Dữ liệu tham chiếu bản đồ, quân số & sự kiện kịch bản Slice-01 Đại Chiến Bạch Đằng 1288 (thay thế hẳn ở R3). |
| `res://assets_clean/shaders/hit_flash.gdshader` | Godot Shader (`canvas_item`) | Tự biên soạn mới 100% (`gl_compatibility` safe) | Độc quyền dự án (100% sạch) | Hiệu ứng chớp trắng 50ms khi trúng đòn (tự gỡ material về `null` bảo toàn 2D batching). |
| `res://assets_clean/shaders/water_flow.gdshader` | Godot Shader (`canvas_item`) | Tự biên soạn mới 100% (`gl_compatibility` safe) | Độc quyền dự án (100% sạch) | Hiệu ứng gợn sóng dòng chảy trên lớp `WaterAndTideLayer` (`z=4`). |
| `res://assets_clean/audio/sfx_sword_hit.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh va chạm binh khí cận chiến (`sword_hit`). |
| `res://assets_clean/audio/sfx_arrow_shot.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh bật dây cung/nỏ tầm xa (`arrow_shot`). |
| `res://assets_clean/audio/sfx_horn_charge.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Tiếng tù và / cồng chiêng phát lệnh xung phong & Mưu lược (`horn_charge`). |
| `res://assets_clean/audio/sfx_water_splash.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh sóng vỗ / chiến thuyền va cọc ngầm (`water_splash`). |
| `res://assets_clean/audio/sfx_fire_ignite.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh hỏa công bùng cháy trên sông (`fire_ignite`). |
| `res://assets_clean/audio/sfx_ui_click.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh chạm nút giao diện (`ui_click`). |
| `res://assets_clean/audio/bgm_bach_dang_ambient.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp âm giai ngũ cung sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Nhạc nền hào khí sông Bạch Đằng (`bgm_bach_dang`). |
| `res://data/battles/battle_10102.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Kịch bản màn 2 Chiến dịch thời Trần: Hội Thề Bình Than & Phòng Tuyến Vạn Kiếp 1282. |
| `res://data/battles/battle_10103.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Kịch bản màn 3 Chiến dịch thời Trần: Phá Trận Bến Hàm Tử 1285. |
| `res://data/battles/battle_10104.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Kịch bản màn 4 Chiến dịch thời Trần: Đoạt Giáo Chương Dương Độ 1285. |
| `res://data/battles/battle_10105.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Kịch bản màn 5 Chiến dịch thời Trần (`enable_economy: true`): Phục Kích Đoàn Lương Vân Đồn 1288. |
| `res://data/battles/battle_10106.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Kịch bản màn 6 Chiến dịch thời Trần: Truy Kích Nội Bàng – Vạn Kiếp 1288. |
| `res://data/defs/troop_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T1`) | Độc quyền dự án (100% sạch) | Định nghĩa Custom `Resource` binh chủng (`TroopDef`) chỉnh trong Godot Inspector. |
| `res://data/defs/general_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T1`) | Độc quyền dự án (100% sạch) | Định nghĩa Custom `Resource` danh tướng (`GeneralDef`) chỉnh trong Godot Inspector. |
| `res://data/defs/tactic_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T1`) | Độc quyền dự án (100% sạch) | Định nghĩa Custom `Resource` mưu lược / kỹ năng (`TacticDef`) chỉnh trong Godot Inspector. |
| `res://data/defs/facility_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T1`) | Độc quyền dự án (100% sạch) | Định nghĩa Custom `Resource` công trình kinh tế (`FacilityDef`) chỉnh trong Godot Inspector. |
| `res://data/defs/codex_entry_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T1`) | Độc quyền dự án (100% sạch) | Định nghĩa Custom `Resource` mục sử ký (`CodexEntryDef`) chỉnh trong Godot Inspector. |
| `res://data/defs/data_registry.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T1`) | Độc quyền dự án (100% sạch) | Định nghĩa Custom `Resource` danh mục tổng hợp (`DataRegistry`) cho tầng `Sim`. |
| `res://data/defs/named_area_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource vùng bản đồ có tên (`NamedAreaDef`) cho `StageDef`. |
| `res://data/defs/unit_placement_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource đặt quân & tướng (`UnitPlacementDef`) cho `StageDef`. |
| `res://data/defs/victory_condition_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource điều kiện thắng (`VictoryConditionDef`) cho `StageDef`. |
| `res://data/defs/defeat_condition_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource điều kiện thua (`DefeatConditionDef`) cho `StageDef`. |
| `res://data/defs/star_condition_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource điều kiện 1–3 sao (`StarConditionDef`) cho `StageDef`. |
| `res://data/defs/dialogue_line_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource lời thoại kịch bản (`DialogueLineDef`) cho `StageDef`. |
| `res://data/defs/scenario_event_condition_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource điều kiện sự kiện (`ScenarioEventConditionDef`) cho `ScenarioEventDef`. |
| `res://data/defs/scenario_event_action_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource hành động sự kiện (`ScenarioEventActionDef`) cho `ScenarioEventDef`. |
| `res://data/defs/scenario_event_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource sự kiện kịch bản (`ScenarioEventDef`) cho `StageDef`. |
| `res://data/defs/stage_faction_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource phe tham chiến & kinh tế khởi đầu (`StageFactionDef`) cho `StageDef`. |
| `res://data/defs/terrain_override_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource ghi đè địa hình từng ô (`TerrainOverrideDef`) cho `StageDef`. |
| `res://data/defs/stage_facility_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Sub-Resource công trình kinh tế đặt sẵn (`StageFacilityDef`) cho `StageDef`. |
| `res://data/defs/stage_def.gd` | GDScript `Resource` | Tự biên soạn mới 100% theo GDD v3.5 (`R2-T2`) | Độc quyền dự án (100% sạch) | Định nghĩa Custom `Resource` cấu hình màn chơi hoàn chỉnh (`StageDef`) chỉnh trong Godot Inspector. |
| `res://data/registry.tres` | Godot Resource `.tres` | Chuyển đổi chuẩn từ dữ liệu GDD v3.5 (`R2-T3`) | Độc quyền dự án (100% sạch) | Danh mục `DataRegistry` tổng hợp 12 binh chủng, 9 tướng, 1 mưu lược, 7 công trình, 7 mục sử ký & 6 màn thời Trần. |
| `res://data/defs/troops/40101_dai_viet_spear_infantry.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40101: Bộ Binh Trường Giáo. |
| `res://data/defs/troops/40102_dai_viet_crossbow.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40102: Cung Nỏ Thủy Lục. |
| `res://data/defs/troops/40103_dai_viet_scout_cavalry.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40103: Khinh Kỵ Trinh Sát. |
| `res://data/defs/troops/40104_dai_viet_war_elephant.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40104: Tượng Binh Xung Kích. |
| `res://data/defs/troops/40105_dai_viet_royal_guard.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40105: Thánh Dực Cấm Quân. |
| `res://data/defs/troops/40106_dai_viet_militia_pikemen.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40106: Hương Binh Câu Liêm. |
| `res://data/defs/troops/40201_dai_viet_light_warboat.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40201: Mông Đồng Khinh Chu. |
| `res://data/defs/troops/40202_dai_viet_fire_boat.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40202: Thuyền Hỏa Công Đại Việt. |
| `res://data/defs/troops/40901_dai_nguyen_heavy_warship.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40901: Chiến Thuyền Đại Nguyên. |
| `res://data/defs/troops/40902_dai_nguyen_flagship.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40902: Soái Hạm Lâu Thuyền Đại Nguyên. |
| `res://data/defs/troops/40903_dai_nguyen_heavy_cavalry.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40903: Thiết Kỵ Đại Nguyên. |
| `res://data/defs/troops/40904_dai_nguyen_horse_archer.tres` | `TroopDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Binh chủng 40904: Cung Kỵ Thảo Nguyên. |
| `res://data/defs/generals/1001_tran_quoc_tuan.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Danh tướng 1001: Hưng Đạo Vương Trần Quốc Tuấn. |
| `res://data/defs/generals/1002_tran_quang_khai.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Danh tướng 1002: Chiêu Minh Vương Trần Quang Khải. |
| `res://data/defs/generals/1003_tran_nhat_duat.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Danh tướng 1003: Chiêu Văn Vương Trần Nhật Duật. |
| `res://data/defs/generals/1004_tran_khanh_du.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Danh tướng 1004: Nhân Huệ Vương Trần Khánh Dư. |
| `res://data/defs/generals/1005_pham_ngu_lao.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Danh tướng 1005: Điện Súy Phạm Ngũ Lão. |
| `res://data/defs/generals/1006_nguyen_khoai.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Danh tướng 1006: Liệt Hầu Nguyễn Khoái. |
| `res://data/defs/generals/1007_tran_quoc_toan.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Danh tướng 1007: Hoài Văn Hầu Trần Quốc Toản. |
| `res://data/defs/generals/9001_o_ma_nhi.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Tướng địch 9001: Đô Nguyên Soái Ô Mã Nhi. |
| `res://data/defs/generals/9002_thoat_hoan.tres` | `GeneralDef` `.tres` | Chuyển đổi từ dữ liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Tướng địch 9002: Trấn Nam Vương Thoát Hoan. |
| `res://data/defs/tactics/10001_hich_tuong_si.tres` | `TacticDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Mưu lược 10001: Hịch Tướng Sĩ. |
| `res://data/defs/facilities/farm.tres` | `FacilityDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Công trình kinh tế: Ruộng Quân Điền (`Farm`). |
| `res://data/defs/facilities/market.tres` | `FacilityDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Công trình kinh tế: Chợ Bến Giang Khẩu (`Market`). |
| `res://data/defs/facilities/mine.tres` | `FacilityDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Công trình kinh tế: Xưởng Rèn Vũ Khí (`Mine`). |
| `res://data/defs/facilities/temple.tres` | `FacilityDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Công trình kinh tế: Đền Quân Kỳ (`Temple`). |
| `res://data/defs/facilities/granary.tres` | `FacilityDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Công trình kinh tế: Kho Lương Chiến Trường (`Granary`). |
| `res://data/defs/facilities/academy.tres` | `FacilityDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Công trình kinh tế: Giảng Võ Đường (`Academy`). |
| `res://data/defs/facilities/fort.tres` | `FacilityDef` `.tres` | Chuyển đổi từ dữ liệu GDD (`R2-T3`) | Độc quyền dự án (100% sạch) | Công trình kinh tế: Thành Lũy / Doanh Trại (`Fort`). |
| `res://data/defs/codex/bach_dang_938.tres` | `CodexEntryDef` `.tres` | Chuyển đổi từ tư liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Mục sử ký Bạch Đằng 938 (Ngô Quyền). |
| `res://data/defs/codex/bach_dang_981.tres` | `CodexEntryDef` `.tres` | Chuyển đổi từ tư liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Mục sử ký Bạch Đằng 981 (Lê Hoàn). |
| `res://data/defs/codex/bach_dang_1288.tres` | `CodexEntryDef` `.tres` | Chuyển đổi từ tư liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Mục sử ký Đại chiến Bạch Đằng 1288 (Trần Quốc Tuấn). |
| `res://data/defs/codex/van_don_1288.tres` | `CodexEntryDef` `.tres` | Chuyển đổi từ tư liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Mục sử ký Trận Vân Đồn – Cửa Lục 1288 (Trần Khánh Dư). |
| `res://data/defs/codex/ham_tu_chuong_duong_1285.tres` | `CodexEntryDef` `.tres` | Chuyển đổi từ tư liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Mục sử ký Song chiến Hàm Tử – Chương Dương 1285. |
| `res://data/defs/codex/oral_legend_what_if.tres` | `CodexEntryDef` `.tres` | Chuyển đổi từ tư liệu sử ký (`R2-T3`) | Độc quyền dự án (100% sạch) | Mục sử ký Giai thoại dân gian & giả định chiến thuật (`Grade D`). |
| `res://data/defs/codex/wargame_hex_abstraction.tres` | `CodexEntryDef` `.tres` | Chuyển đổi từ tư liệu thiết kế (`R2-T3`) | Độc quyền dự án (100% sạch) | Mục cơ chế mô hình hóa lưới Hex, ZoC & Thủy triều rút Vòng 4. |
| `res://data/stages/10101_bach_dang/stage_10101.tres` | `StageDef` `.tres` | Chuyển đổi từ kịch bản Bạch Đằng (`R2-T3`) | Độc quyền dự án (100% sạch) | Cấu hình `StageDef` màn 10101: Đại Chiến Bạch Đằng 1288. |
| `res://data/stages/10101_bach_dang/stage_10101_map.tscn` | Godot Scene `TileMapLayer` | Dựng bằng `StageMapTool` `@tool` từ `stage_10101.tres` (`R3-T3`) | Độc quyền dự án (bố cục Bạch Đằng) | Scene bản đồ lục giác 2 chiều + `UnitPlacementMarker` cho màn 10101. |
| `res://data/stages/10102_binh_than/stage_10102.tres` | `StageDef` `.tres` | Chuyển đổi từ kịch bản Bình Than (`R2-T3`) | Độc quyền dự án (100% sạch) | Cấu hình `StageDef` màn 10102: Hội Thề Bình Than & Vạn Kiếp 1282. |
| `res://data/stages/10103_ham_tu/stage_10103.tres` | `StageDef` `.tres` | Chuyển đổi từ kịch bản Hàm Tử (`R2-T3`) | Độc quyền dự án (100% sạch) | Cấu hình `StageDef` màn 10103: Phá Trận Bến Hàm Tử 1285. |
| `res://data/stages/10104_chuong_duong/stage_10104.tres` | `StageDef` `.tres` | Chuyển đổi từ kịch bản Chương Dương (`R2-T3`) | Độc quyền dự án (100% sạch) | Cấu hình `StageDef` màn 10104: Đoạt Giáo Chương Dương Độ 1285. |
| `res://data/stages/10105_van_don/stage_10105.tres` | `StageDef` `.tres` | Chuyển đổi từ kịch bản Vân Đồn (`R2-T3`) | Độc quyền dự án (100% sạch) | Cấu hình `StageDef` màn 10105: Phục Kích Đoàn Lương Vân Đồn 1288 (có kinh tế). |
| `res://data/stages/10106_noi_bang/stage_10106.tres` | `StageDef` `.tres` | Chuyển đổi từ kịch bản Nội Bàng (`R2-T3`) | Độc quyền dự án (100% sạch) | Cấu hình `StageDef` màn 10106: Truy Kích Nội Bàng – Vạn Kiếp 1288. |

---

### 2.1. Bộ Tài nguyên Tạm Kế Thừa từ HexCrown (Cổng R3 — Thay thế tại R4/P4 theo DEC-022)

> [!WARNING] **Nguồn gốc & Quy tắc Thay thế (`DEC-022` & `D:\code\HexCrown\ASSET_LICENSE.md`):** Toàn bộ `56` tệp dưới đây chỉ dùng **tạm thời cho phát triển/chạy thử nội bộ ở Cổng `R3`** để dựng khung `TileMapLayer` và `unit_view.tscn`; **bắt buộc thay thế 100%** ở `R4/P4` (sau khi người dùng chốt mỹ thuật) trước bất kỳ bản phát hành thương mại/công khai nào.

| Đường dẫn `res://` | Loại | Nguồn gốc / Phương thức tạo | Bản quyền | Mục đích sử dụng |
|---|---|---|---|---|
| `res://assets_clean/hexcrown/tiles/hexcrown_hex_tileset.tres` | Godot `TileSet` | Cấu hình lục giác `32×24` (`terrain_id` layer) bọc `hex_tiles_sheet.png` (`R3-T1`) | Kế thừa tạm `D:\code\HexCrown` (thay thế `R4/P4`) | `TileSet` chuẩn cho `battle_map.tscn` & `stage_10101_map.tscn`. |
| `res://assets_clean/hexcrown/tiles/hex_tiles_sheet.png` | Raster PNG `160×240` | Sao chép từ `D:\code\HexCrown\assets\Free\Tile\spritesheet (1).png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Lưới địa hình lục giác cơ sở `32×48` cho `hexcrown_hex_tileset.tres`. |
| `res://assets_clean/hexcrown/tiles/tileset_atlas.png` | Raster PNG `384×384` | Sao chép từ `D:\code\HexCrown\assets\Free\Tile\Tileset1.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Atlas địa hình phụ trợ từ `HexCrown`. |
| `res://assets_clean/hexcrown/tiles/map_elements.png` | Raster PNG `128×160` | Sao chép từ `D:\code\HexCrown\assets\Free\Elements\Elements.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Vật thể trang trí bản đồ (`R3`). |
| `res://assets_clean/hexcrown/buildings/blue/archery.png` | Raster PNG `192×256` | Sao chép từ `D:\code\HexCrown\assets\Blue Buildings\Archery.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Xanh: Trại cung. |
| `res://assets_clean/hexcrown/buildings/blue/barracks.png` | Raster PNG `192×256` | Sao chép từ `D:\code\HexCrown\assets\Blue Buildings\Barracks.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Xanh: Doanh trại. |
| `res://assets_clean/hexcrown/buildings/blue/castle.png` | Raster PNG `320×256` | Sao chép từ `D:\code\HexCrown\assets\Blue Buildings\Castle.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Xanh: Thành lũy chính. |
| `res://assets_clean/hexcrown/buildings/blue/house_1.png` | Raster PNG `128×192` | Sao chép từ `D:\code\HexCrown\assets\Blue Buildings\House1.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Xanh: Nhà dân / bến 1. |
| `res://assets_clean/hexcrown/buildings/blue/house_2.png` | Raster PNG `128×192` | Sao chép từ `D:\code\HexCrown\assets\Blue Buildings\House2.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Xanh: Nhà dân / bến 2. |
| `res://assets_clean/hexcrown/buildings/blue/house_3.png` | Raster PNG `128×192` | Sao chép từ `D:\code\HexCrown\assets\Blue Buildings\House3.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Xanh: Nhà dân / bến 3. |
| `res://assets_clean/hexcrown/buildings/blue/monastery.png` | Raster PNG `192×320` | Sao chép từ `D:\code\HexCrown\assets\Blue Buildings\Monastery.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Xanh: Đền quân kỳ. |
| `res://assets_clean/hexcrown/buildings/blue/tower.png` | Raster PNG `128×256` | Sao chép từ `D:\code\HexCrown\assets\Blue Buildings\Tower.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Xanh: Tháp canh. |
| `res://assets_clean/hexcrown/buildings/red/archery.png` | Raster PNG `192×256` | Sao chép từ `D:\code\HexCrown\assets\Red Buildings\Archery.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Đỏ: Trại cung. |
| `res://assets_clean/hexcrown/buildings/red/barracks.png` | Raster PNG `192×256` | Sao chép từ `D:\code\HexCrown\assets\Red Buildings\Barracks.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Đỏ: Doanh trại. |
| `res://assets_clean/hexcrown/buildings/red/castle.png` | Raster PNG `320×256` | Sao chép từ `D:\code\HexCrown\assets\Red Buildings\Castle.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Đỏ: Thành lũy chính. |
| `res://assets_clean/hexcrown/buildings/red/house_1.png` | Raster PNG `128×192` | Sao chép từ `D:\code\HexCrown\assets\Red Buildings\House1.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Đỏ: Nhà dân / bến 1. |
| `res://assets_clean/hexcrown/buildings/red/house_2.png` | Raster PNG `128×192` | Sao chép từ `D:\code\HexCrown\assets\Red Buildings\House2.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Đỏ: Nhà dân / bến 2. |
| `res://assets_clean/hexcrown/buildings/red/house_3.png` | Raster PNG `128×192` | Sao chép từ `D:\code\HexCrown\assets\Red Buildings\House3.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Đỏ: Nhà dân / bến 3. |
| `res://assets_clean/hexcrown/buildings/red/monastery.png` | Raster PNG `192×320` | Sao chép từ `D:\code\HexCrown\assets\Red Buildings\Monastery.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Đỏ: Đền quân kỳ. |
| `res://assets_clean/hexcrown/buildings/red/tower.png` | Raster PNG `128×256` | Sao chép từ `D:\code\HexCrown\assets\Red Buildings\Tower.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Công trình phe Đỏ: Tháp canh. |
| `res://assets_clean/hexcrown/units/mini_archer_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniArcherMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet lính cung (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_arch_mage.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniArchMage.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet hỏa công/pháp sư (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_cavalier_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniCavalierMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet trọng kỵ (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_crossbow_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniCrossBowMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet cung nỏ (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_halberd_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniHalberdMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet câu liêm / đại kích (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_horse_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniHorseMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet khinh kỵ / cung kỵ (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_king_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniKingMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet chủ tướng / soái hạm tạm (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_mage.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniMage.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet mưu sĩ / hỏa thuyền tạm (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_prince_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniPrinceMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet cấm quân (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_shield_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniShieldMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet khiên binh / tượng binh tạm (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_spear_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniSpearMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet bộ binh trường giáo (`R3-T2`). |
| `res://assets_clean/hexcrown/units/mini_sword_man.png` | Sprite sheet `32×32` | Sao chép từ `D:\code\HexCrown\assets\Outline\MiniSwordMan.png` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | Sprite sheet bộ binh / dân binh (`R3-T2`). |
| `res://assets_clean/hexcrown/shaders/faction_tint.gdshader` | Godot Shader (`canvas_item`) | Kế thừa từ `D:\code\HexCrown\src\Shaders\FactionTint.gdshader` (GPLv3 code / `R3`) | Mã shader mở từ `HexCrown` | Đổi màu áo phe & viền sáng chọn/mục tiêu cho `unit_view.tscn`. |
| `res://assets_clean/hexcrown/shaders/pulse_highlight.gdshader` | Godot Shader (`canvas_item`) | Kế thừa từ `D:\code\HexCrown\src\Shaders\pulse_highlight.gdshader` (GPLv3 code / `R3`) | Mã shader mở từ `HexCrown` | Hiệu ứng nhịp sáng mục tiêu ô lục giác. |
| `res://assets_clean/hexcrown/shaders/territory_border.gdshader` | Godot Shader (`canvas_item`) | Kế thừa từ `D:\code\HexCrown\src\Shaders\territory_border.gdshader` (GPLv3 code / `R3`) | Mã shader mở từ `HexCrown` | Viền lãnh thổ quanh ô căn cứ. |
| `res://assets_clean/hexcrown/audio/ui/click_1.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\click1.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX bấm nút UI 1. |
| `res://assets_clean/hexcrown/audio/ui/click_2.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\click2.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX bấm nút UI 2. |
| `res://assets_clean/hexcrown/audio/ui/mouse_click.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\mouseclick1.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX chọn đơn vị trên bản đồ. |
| `res://assets_clean/hexcrown/audio/ui/mouse_release.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\mouserelease1.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX bỏ chọn đơn vị. |
| `res://assets_clean/hexcrown/audio/ui/switch_tab_1.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\switch12.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX chuyển thẻ/hộp thoại 1. |
| `res://assets_clean/hexcrown/audio/ui/switch_tab_2.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\switch13.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX chuyển thẻ/hộp thoại 2. |
| `res://assets_clean/hexcrown/audio/ui/switch_turn.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\switch31.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX chuyển lượt. |
| `res://assets_clean/hexcrown/audio/ui/switch_spawn.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\switch18.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX chiêu mộ / phục binh xuất kích. |
| `res://assets_clean/hexcrown/audio/ui/switch_error.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\UI_Audio\switch4.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX thao tác bị từ chối. |
| `res://assets_clean/hexcrown/audio/combat/sword_slice_1.mp3` | Audio MP3 | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Hit audio\Swordslice.mp3` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX chém cận chiến 1. |
| `res://assets_clean/hexcrown/audio/combat/sword_slice_2.mp3` | Audio MP3 | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Hit audio\Swordslice2.mp3` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX chém cận chiến 2. |
| `res://assets_clean/hexcrown/audio/combat/bow_hit.mp3` | Audio MP3 | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Hit audio\Bowhit.mp3` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX mũi tên trúng mục tiêu. |
| `res://assets_clean/hexcrown/audio/combat/bow_stretch.mp3` | Audio MP3 | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Hit audio\Bowlstretchtofire.mp3` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX kéo dây cung. |
| `res://assets_clean/hexcrown/audio/combat/impact_heavy_0.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Impact_Audio\impactSoft_heavy_000.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX va chạm nặng 1. |
| `res://assets_clean/hexcrown/audio/combat/impact_heavy_1.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Impact_Audio\impactSoft_heavy_001.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX va chạm nặng 2. |
| `res://assets_clean/hexcrown/audio/combat/impact_medium_0.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Impact_Audio\impactSoft_medium_000.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX va chạm vừa 1. |
| `res://assets_clean/hexcrown/audio/combat/impact_medium_1.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Impact_Audio\impactSoft_medium_001.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX va chạm vừa 2. |
| `res://assets_clean/hexcrown/audio/footstep/footstep_grass_0.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Impact_Audio\footstep_grass_000.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX hành quân trên đất/cỏ 1. |
| `res://assets_clean/hexcrown/audio/footstep/footstep_grass_1.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Impact_Audio\footstep_grass_001.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX hành quân trên đất/cỏ 2. |
| `res://assets_clean/hexcrown/audio/footstep/footstep_wood_0.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Impact_Audio\footstep_wood_000.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX hành quân trên cầu gỗ / sàn thuyền 1. |
| `res://assets_clean/hexcrown/audio/footstep/footstep_wood_1.ogg` | Audio OGG | Sao chép từ `D:\code\HexCrown\assets\audio_effects\Impact_Audio\footstep_wood_001.ogg` | Kế thừa tạm `HexCrown` (`ASSET_LICENSE.md` — thay `R4/P4`) | SFX hành quân trên cầu gỗ / sàn thuyền 2. |
