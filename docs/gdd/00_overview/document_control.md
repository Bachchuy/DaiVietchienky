# Quản lý tài liệu (Document Control)

[← Quay lại Mục lục GDD](../README.md)

---

## Thông tin tài liệu

| Trường | Giá trị |
|---|---|
| Tên sản phẩm | Đại Việt Chiến Kỳ (Dai Viet Chronicles) |
| Tài liệu | Game Design Document (GDD) — Kiến trúc Module hóa |
| Phiên bản | **3.5** (Cập nhật đồng bộ Tái kiến trúc Editor-First ngày 21/11/2026 — `DEC-021..DEC-026`) |
| Trạng thái | **GDD v3.5 Active — Chuyển sang Lộ trình Tái kiến trúc `R1–R5` (`CP6–CP10`)** |
| Engine & Công nghệ | **Godot 4.7**; ngôn ngữ **Thuần GDScript 2.0 (Typed GDScript `<= 400 dòng/script`)**; Renderer **`gl_compatibility`**; mục tiêu **60 FPS** |
| Kiến trúc mã nguồn | **Kiến trúc 4 Tầng Editor-First:** `res://data/` (`.tres` + `@tool` Map `.tscn`) $\to$ `res://sim/` (`RefCounted` độc lập `SceneTree`) $\to$ `BattleSession` (`Node`) $\to$ `res://game/battle/` & `res://ui/` (`.tscn` + `theme.tres`) |
| Nền tảng mục tiêu | **Web (HTML5/Wasm) + Android** (`D-06`, `D-09`, `D-10`); phát triển và kiểm thử nguyên mẫu trên **Windows Desktop** (Single-player) |
| Vertical slice đầu tiên | **Slice-01: Đại Chiến Bạch Đằng 1288 (`stage_id: 10101`)**; dữ liệu kịch bản hiện tại gắn nhãn `fixture / gameplay abstraction`, chờ hội đồng thẩm định lịch sử |
| Phạm vi lịch sử dài hạn | Từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (Triều Tây Sơn), triển khai cuốn chiếu theo từng *Era Pack* |
| Đối tượng sử dụng | Thiết kế gameplay, lập trình hệ thống, mỹ thuật/UI, biên tập kịch bản và cố vấn lịch sử |

---

## Trạng thái Baseline (LOCKED vs OPEN)

Baseline Candidate 3.4.1 khóa toàn bộ khung công nghệ, luật cốt lõi của chiến trường và đặc tả mục tiêu Slice-01 để đội ngũ lập trình triển khai các mốc kỹ thuật `CP1–CP4` mà không bị xung đột tài liệu. Tuy nhiên, tài liệu chưa chuyển sang trạng thái *Frozen*: các con số cân bằng (`fixture`), trọng số AI và hồ sơ lịch sử (`Dossier`) Bạch Đằng 1288 cần được kiểm chứng thực tế qua vòng Playtest ngoài đội phát triển (`[D-17]`) trước khi duyệt Gate `P2`.

| **LOCKED** — Đã chốt chuẩn, thay đổi phải qua Design & Tech Lead duyệt | **OPEN** — Sẽ tinh chỉnh và khóa theo từng Milestone Gate |
|---|---|
| **Tech Stack & Kiến trúc 4 Tầng (`D-01`, `D-06`, `D-09`, `D-10`, `DEC-023`, `DEC-024`):** Hex Wargame theo lượt trên **Godot 4.7**, **Thuần GDScript 2.0 (`<= 400 dòng/script`)** theo 4 tầng (`data/.tres` $\to$ `sim/` $\to$ `BattleSession` $\to$ `.tscn` + `theme.tres`), renderer `gl_compatibility`, ưu tiên **Web + Android** ở **60 FPS** (xem [data_and_save_system.md](../architecture/data_and_save_system.md) & [implementation_plan.md](../04_production_roadmap/implementation_plan.md)). | **Thông số cân bằng `fixture`:** Toàn bộ chỉ số cụ thể `HP/ATK/DEF/MP`, hệ số địa hình và chi phí đơn vị được lưu dạng `.tres` chỉnh trong Inspector và tinh chỉnh qua playtest (xem [combat_formulas.md](../mechanics/combat_formulas.md) & [hex_grid_pathfinding.md](../mechanics/hex_grid_pathfinding.md)). |
| **Combat `Seeded RNG`, Giáp & Bỏ Biết Trước (`DEC-026`):** Mô hình **Controlled RNG có Seed tất định** (`80%–100%` + Bạo kích, không có `miss`), toán học số nguyên `RoundHalfUp`, công thức giáp chuẩn `100 / (100 + EffectiveDef)` đảm bảo **100% Deterministic Replay**; bỏ `CombatPreviewBox` & `AimingTarget`, người chơi xem thông số qua `UnitInspector` tự tính và chạm 1 lần vào địch trong tầm Đỏ để đánh ngay (xem [combat_formulas.md](../mechanics/combat_formulas.md)). | **Thẩm định Dossier Lịch sử (`D-08`):** Đối chiếu chi tiết biên chế, địa danh và lời thoại kịch bản Bạch Đằng 1288 với nguồn chính sử/khảo cổ `[S12]–[S16]` trước khi gỡ nhãn `fixture` (xem [historical_framework.md](../03_content_presentation/historical_framework.md) & [appendix_b_sources.md](../appendices/appendix_b_sources.md)). |
| **Sĩ khí 4 Bậc & Tương tác Chiến thuật (`D-11..D-13`):** **4 bậc Enum rời rạc** (`HIGH` Hưng Phấn, `NORMAL` Ổn Định, `LOW` Dao Động, `CHAOS` Hỗn Loạn — khóa hành động tạm thời theo lượt rồi tự hồi về `LOW`, không dùng thang điểm liên tục hay trạng thái xóa đơn vị vĩnh viễn); phản kích tối đa 1 lần/lượt; ZoC dừng bước ngay (`MP = 0`) (xem [morale_and_status.md](../mechanics/morale_and_status.md) & [battlefield_rules.md](../02_gameplay_systems/battlefield_rules.md)). | **Trọng số AI & Cân bằng Chống Co cụm (`D-15`, `D-16`):** Tinh chỉnh điểm Utility AI, phạm vi phạt sĩ khí khi tướng rời trận (`D-15`) và nhịp áp lực lên `SignalDock (2, 8)` (`D-16`) (xem [ai_decision_matrix.md](../ai/ai_decision_matrix.md)). |
| **Đặc tả Slice-01 Bạch Đằng 1288 (`D-03`, `D-14`):** `stage_id: 10101`, bản đồ `12 × 10` hex (`Pointy-topped Axial`), tối đa **10 lượt**, phe địch **Đại Nguyên (Quân Nguyên)**; đầu **Vòng 4** kích hoạt `MapPhase_TideFall` lộ bãi cọc (`-35% MaxHP`, `MarchDisabled` 2 lượt, `CHAOS` 1 lượt) + phục binh; thắng ngay khi hạ Ô Mã Nhi lúc giữ `SignalDock (2, 8)` hoặc giữ hết lượt 10 & diệt `>= 75%` địch; **ẩn kinh tế (`enable_economy = false`, thuộc P3)** (xem [production_scope_mvp.md](../04_production_roadmap/production_scope_mvp.md)). | **Kiến trúc Mở rộng Chiến lược (`D-04`, `D-05`, `D-07`, `D-18`):** Cấu trúc bản đồ Conquest, độ sâu ngoại giao ở mốc P3, ngưỡng Pity ở P4+, Playtest `>= 4/5` (`D-17`) và **Cổng Dừng `R4` So sánh Mỹ thuật (`D-18` / `DEC-022`: Pixel Art vs 2D Cách điệu EasyTech)** (xem [risks_open_decisions.md](../04_production_roadmap/risks_open_decisions.md)). |
| **Phân tách Chế độ & Thương mại hóa F2P Thân thiện (`D-02`, `D-07`):** Khóa hồ sơ tướng `Preset Loadout` trong Historical Scenario; không có Gacha ở Slice-01/MVP; giai đoạn P4+ áp dụng F2P thân thiện tích lũy Ngọc Bích chiêu mộ được mọi phẩm tướng kể cả bậc Đỏ, không khóa danh tướng lịch sử sau paywall nạp tiền (xem [generals_and_meta_economy.md](../progression/generals_and_meta_economy.md)). | **Hoàn thiện UI `.tscn`, `TileMapLayer` & Thay thế Asset (`R1–R5`):** Tái cấu trúc UI/Data/Scene theo chuẩn Editor-First (`R1–R3` với asset kế thừa sạch từ `HexCrown`), sau đó so sánh 2 mẫu và thay thế toàn bộ asset ở `R4–R5` (xem [battle_ui_and_rendering.md](../ui_ux/battle_ui_and_rendering.md) & [ASSET_CATALOG.md](../../assets/ASSET_CATALOG.md)). |

> **Nguyên tắc quản trị dữ liệu `fixture`:** Mọi chỉ số hoặc tình tiết kịch bản gắn nhãn `fixture` chỉ đóng vai trò dữ liệu mồi phục vụ lập trình và kiểm thử lối chơi. Với nội dung lịch sử, `fixture` chỉ được chuyển thành `historical claim` sau khi có hồ sơ `Dossier` kèm `sourceRef` và `Evidence grade` được phê duyệt; với cân bằng gameplay, `fixture` phải trải qua đo đạc playtest định lượng.

---

## Lịch sử phiên bản

| Phiên bản | Ngày | Thay đổi trọng tâm |
|---|---|---|
| **3.3** | 13/11/2026 | Đưa đặc tả sơ khởi cho Slice-01 (combat, địa hình, morale, thủy chiến, dữ liệu kịch bản) vào tài liệu đơn khối; vẫn còn tồn tại xung đột giữa định hướng triệt tiêu ngẫu nhiên cũ và bảng chỉ số chi tiết, cùng giả định C# .NET chưa kiểm chứng xuất bản Web. |
| **3.4** | 13–15/11/2026 | Tái cấu trúc thành hệ thống GDD phân tách theo cây thư mục module dưới `docs/gdd/`; bổ sung các micro-modules kỹ thuật – cơ chế (`mechanics/`, `progression/`, `ai/`, `architecture/`, `ui_ux/`, `vfx_sfx/`, `level_design/`) và danh mục tài nguyên [ASSET_CATALOG.md](../../assets/ASSET_CATALOG.md); làm rõ quy trình thẩm định lịch sử tách `Evidence grade` khỏi `ModelingType`. |
| **3.4.1** | 18/11/2026 | **Đồng bộ chuẩn hóa toàn diện sau Kiểm toán GDD:** (1) Chốt `D-06/D-09/D-10` chuyển hoàn toàn sang **Godot 4.7 + Thuần GDScript 2.0 + `gl_compatibility`** hướng tới **Web + Android 60 FPS** (`scripts/core/` & `scripts/presentation/`); (2) Đồng bộ cơ chế **Seeded RNG** (`80%–100%` + Crit, 100% Deterministic Replay), giáp `100/(100+EffectiveDef)` và **4 bậc Enum Sĩ khí** (`HIGH/NORMAL/LOW/CHAOS`); (3) Chuẩn hóa Slice-01 Bạch Đằng 1288 (`stage_id: 10101`, Vòng 4 triều rút, điều kiện thắng tức thì tương thích 2 Sao, `enable_economy = false`); (4) Mở rộng phạm vi lịch sử từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (Tây Sơn) và chốt chính sách **F2P thân thiện (`D-07`)**; (5) Xóa sạch toàn bộ tham chiếu tới các tệp ngoài không tồn tại và khôi phục [CHANGELOG_3.3_to_3.4.md](CHANGELOG_3.3_to_3.4.md). |
| **3.5** | 21/11/2026 | **Tái kiến trúc Editor-First (`DEC-021..DEC-026`) & Lộ trình `R1–R5`:** (1) Chuyển sang **Kiến trúc 4 Tầng (`<= 400 dòng/script`)**: `res://data/` (Custom `Resource` `.tres` + `@tool` Map `.tscn`) $\to$ `res://sim/` (`RefCounted`) $\to$ `BattleSession` $\to$ `res://game/battle/` & `res://ui/` (`TileMapLayer`, `unit_view.tscn`, HUD/Modal `.tscn` + `theme.tres`); (2) **Bỏ triết lý biết trước (`CombatPreviewBox` & `AimingTarget`)**: dùng `UnitInspector` chỉ hiện thông số thô từng đạo quân + **đánh ngay 1 chạm** như `HexCrown`; (3) Làm chuẩn chỉnh Vertical Slice `10101` trước (`R1–R3` kế thừa asset sạch `HexCrown`) rồi dừng ở **Cổng Mỹ thuật `R4`** hỏi người dùng so sánh 2 mẫu (`Pixel Art` vs `2D Cách điệu EasyTech`) trước khi nhân rộng sang `10102–10106` (`R5`); (4) Nâng cấp kiểm thử lên 3 lớp kèm `assert_button_reachable()` và kiểm tra View 2D/Inspector trong Editor. |

> Xem lịch sử tiến hóa đầy đủ từ `v0.1` đến `v3.4.1`, giải trình các quyết định nền tảng `D-01..D-03`, `D-09` và bảng ánh xạ tệp tại: [CHANGELOG_3.3_to_3.4.md](CHANGELOG_3.3_to_3.4.md).
