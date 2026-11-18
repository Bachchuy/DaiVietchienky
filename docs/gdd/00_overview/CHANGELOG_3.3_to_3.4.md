# Lịch sử Tiến hóa Phiên bản & Bảng Ánh xạ Cấu trúc (Changelog 0.1 → 3.4.1)

[← Quay lại Mục lục GDD](../README.md)

---

Tài liệu này ghi lại toàn bộ quá trình tiến hóa thiết kế và kỹ thuật của dự án **Đại Việt Chiến Kỳ** (*Dai Viet Chronicles*) từ bản phác thảo đầu tiên (`v0.1`) đến bản đồng bộ chuẩn hóa sau kiểm toán (`v3.4.1`), đồng thời giải trình đầy đủ các quyết định nền tảng đã khóa từ đầu (`D-01..D-03`, `D-06`, `D-09`, `D-10`) và bảng ánh xạ từ các tài liệu tham chiếu cũ sang cấu trúc module thực tế hiện hành.

---

## 1. Dòng thời gian tiến hóa các phiên bản (`v0.1` → `v3.4.1`)

| Phiên bản | Mốc thời gian | Trọng tâm thay đổi & Bước ngoặt thiết kế |
|---|---|---|
| **v0.1 – v1.0** | Giai đoạn Khởi thảo | Hình thành ý tưởng trò chơi chiến thuật lịch sử Việt Nam; chốt **3 quyết định nền tảng đầu tiên (`D-01`, `D-02`, `D-03`)**: chọn thể loại Hex Wargame theo lượt thay vì RTS, tách biệt chế độ Lịch sử khóa hồ sơ tướng với chế độ Tự do, và chọn trận Bạch Đằng 1288 làm Vertical Slice mở màn. |
| **v2.0 – v3.2** | Giai đoạn Định hình Hệ thống | Xây dựng khung 4 chế độ chơi (*Scenario, Conquest, Legion, Domination*) tham chiếu dòng game EasyTech và *Panzer Corps 2*; thiết lập bộ tiêu chuẩn thẩm định lịch sử (`Evidence grade` A–D) và danh sách ứng viên chiến dịch đa triều đại. |
| **v3.3** | 13/11/2026 | Gom đặc tả Slice-01 Bạch Đằng 1288, công thức sát thương, sĩ khí, thủy chiến và giả định kỹ thuật Godot .NET (C#) vào một tệp GDD đơn khối lớn. Phát sinh xung đột nội bộ giữa ghi chú "No-RNG" và công thức dao động sát thương, đồng thời gắn nhãn "Freeze" sớm khi dữ liệu `fixture` chưa qua playtest. |
| **v3.4** | 13–15/11/2026 | **Tách module hóa toàn bộ GDD** thành cây thư mục dưới `docs/gdd/` để tối ưu ngữ cảnh làm việc cho đội ngũ & AI Agent; bổ sung 7 cụm micro-modules chuyên sâu (`mechanics/`, `progression/`, `ai/`, `architecture/`, `ui_ux/`, `vfx_sfx/`, `level_design/`) cùng [ASSET_CATALOG.md](../../assets/ASSET_CATALOG.md) và công cụ hợp nhất `docs/build_master_gdd.py`. Tuy nhiên, quá trình tách tệp để sót một số tham chiếu tới các tệp dự kiến chưa tạo (`TDD`, `Content Spec`, `Content Schema`, `Production_Roadmap_3_4.md`) và chưa cập nhật kịp quyết định chuyển đổi ngôn ngữ engine. |
| **v3.4.1** | **18/11/2026** | **Kiểm toán & Chuẩn hóa Đồng bộ Toàn diện:**<br/>1. Chốt lại `D-06`, `D-09`, `D-10`: Chuyển từ C# .NET sang **Thuần GDScript 2.0 trên Godot 4.7** (`gl_compatibility`, **60 FPS**) để xuất bản liền mạch **Web (HTML5/Wasm) + Android**.<br/>2. Thống nhất cơ chế **Controlled RNG có Seed tất định (`Seeded RNG`: `80%–100%` + Bạo kích, 100% Deterministic Replay)**, công thức giáp chuẩn `100 / (100 + EffectiveDef)` và **4 bậc Enum Sĩ khí rời rạc** (`HIGH`, `NORMAL`, `LOW`, `CHAOS`).<br/>3. Chuẩn hóa kịch bản **Slice-01 Bạch Đằng 1288 (`stage_id: 10101`)**: `12 × 10` hex, 10 lượt, phe địch **Đại Nguyên**, triều rút đầu **Vòng 4**, điều kiện thắng tức thì tương thích mốc 2 Sao (`<= 8` lượt), ẩn kinh tế (`enable_economy = false`).<br/>4. Mở rộng phạm vi lịch sử thành **"Từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (Triều Tây Sơn)"** theo *Era Pack* và chốt chính sách **F2P thân thiện (`D-07`)** không khóa danh tướng lịch sử sau paywall nạp tiền.<br/>5. Khử sạch 100% tham chiếu "bóng ma", tạo mới tệp Changelog này, khử trùng lặp Glossary và bổ sung nguồn sử liệu gốc `[S11]–[S16]`. |

---

## 2. Giải trình các Quyết định Kiến trúc & Thiết kế Đã Khóa Nền Tảng

Trong các bản nháp trước, bảng quyết định mở tại Mục 15 bắt đầu từ `D-04` vì ba quyết định gốc `D-01`, `D-02`, `D-03` đã được khóa ngay từ giai đoạn định hình dự án. Dưới đây là hồ sơ lưu trữ chính thức của các quyết định nền tảng này cùng quyết định chuyển đổi công nghệ `D-09`:

### `D-01` — Chọn Turn-Based Hex Wargame thay vì Chiến thuật Thời gian thực (RTS) *(LOCKED từ v0.1)*
- **Bối cảnh lựa chọn:** Chiến tranh lịch sử Việt Nam (như bẫy cọc thủy triều Bạch Đằng, vây thành Chi Lăng, hành quân thần tốc Tây Sơn) có sức hấp dẫn cốt lõi nằm ở **mưu lược chọn thế đất, nắm bắt thời điểm và phối hợp binh chủng**, không phải tốc độ bấm phím vi mô (APM).
- **Quyết định:** Khóa thể loại **Chiến thuật theo lượt trên lưới lục giác cạnh nhọn (`Pointy-topped Axial Hex`)**.
- **Lý do cốt lõi:** Lưới 6 hướng loại bỏ sai lệch đường chéo của lưới vuông, làm nổi bật hình học bao vây (`TrappedLevel`) và bọc sườn (`Flank`), đồng thời tương thích tự nhiên với thao tác chạm `<= 2 bước` trên màn hình cảm ứng Android và trình duyệt Web.

### `D-02` — Tách biệt Chế độ Lịch sử (`Preset Loadout`) và Chế độ Tự do (`Meta Progression`) *(LOCKED từ v1.0)*
- **Bối cảnh lựa chọn:** Trong nhiều game chiến thuật di động, người chơi có thể nạp tiền hoặc cày cấp tướng quá cao khiến các trận đánh lịch sử mất sạch tính thử thách và làm sai lệch bối cảnh.
- **Quyết định:** Trong **Historical Scenario**, toàn bộ danh tướng và đạo quân cốt lõi sử dụng **hồ sơ khóa theo kịch bản (`Preset Loadout`)** đúng với thiết kế màn chơi. Các trục nâng cấp tự do, trang bị và chiêu mộ danh tướng đa thời kỳ được tách riêng sang các chế độ mở rộng (*Conquest / Domination / Legion* từ mốc `P3/P4+`).
- **Lý do cốt lõi:** Bảo vệ tuyệt đối trụ cột *"Dễ đọc, khó làm chủ"* và *"Lịch sử có căn cứ"*, đảm bảo mọi người chơi vượt ải Bạch Đằng bằng tư duy chiến thuật thực chất.

### `D-03` — Chiến lược Sản xuất Cuốn chiếu từ Vertical Slice Bạch Đằng 1288 *(LOCKED từ v1.0)*
- **Bối cảnh lựa chọn:** Lịch sử quân sự Việt Nam kéo dài hàng thiên niên kỷ từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII; nếu sản xuất dàn trải nhiều thời kỳ ngay từ đầu sẽ dẫn tới vỡ tiến độ và loãng bản sắc.
- **Quyết định:** Dồn toàn bộ nguồn lực giai đoạn đầu (`P0 → P2`) để hoàn thiện duy nhất **Slice-01: Đại Chiến Bạch Đằng 1288 (`stage_id: 10101`)** đạt chuẩn chơi được trọn vẹn và kiểm chứng qua Playtest độc lập (`[D-17]`), sau đó mở rộng thành **Gói Chiến dịch Thời Trần** cho Release MVP (`P5`), rồi mới phát hành cuốn chiếu các *Era Pack* tiếp theo.

### `D-09` (Cập nhật v3.4.1) — Chuyển từ C# .NET sang Thuần GDScript 2.0 trên Godot 4.7 *(LOCKED ngày 18/11/2026)*
- **Thay đổi so với v3.3:** Hủy bỏ định hướng sử dụng Godot .NET (C#) và cấu trúc assembly `DaiViet.Core / DaiViet.Godot` cũ; chuyển hoàn toàn sang **Godot 4.7** sử dụng **100% Thuần GDScript 2.0 (Static Typing)** kết hợp **`gl_compatibility` Renderer** (đồng bộ với `D-06` ưu tiên **Web + Android** và `D-10` mục tiêu **60 FPS**).
- **Lý do kỹ thuật quyết định:**
  1. **Xuất bản Web (HTML5/Wasm) liền mạch:** GDScript biên dịch/đóng gói trực tiếp trên template chuẩn của Godot 4.7 với dung lượng tải nhỏ, khởi động nhanh và tương thích ổn định trên cả trình duyệt PC lẫn trình duyệt di động, tránh được rào cản kích thước runtime .NET Wasm và giới hạn bộ nhớ trình duyệt.
  2. **Đồng nhất đa nền tảng Web + Android + Windows Desktop:** Một codebase GDScript duy nhất chạy đồng nhất không cần cầu nối interop C#–GDScript, hỗ trợ kiểm thử tự động `--headless` cực nhanh.
  3. **Bảo toàn kiến trúc tách tầng sạch sẽ:** Thay thế mô hình tách project C# cũ bằng kiến trúc hai phân lớp thư mục nghiêm ngặt trong GDScript:
     - `res://scripts/core/`: Chứa toàn bộ logic mô phỏng chiến thuật, lưới Hex, định tuyến A*, `CombatResolver` dùng `RandomNumberGenerator` lưu `seed/state`, `MoraleEngine` và `CommandQueue` — kế thừa `RefCounted`/`Resource`, **tuyệt đối không phụ thuộc `SceneTree` hay Node đồ họa** để chạy unit test headless và đảm bảo 100% Deterministic Replay.
     - `res://scripts/presentation/`: Chứa Scene, Node2D, 15 Render Layers, Camera `StrategicZoom`, UI Controls, VFX và Audio Pooling.

---

## 3. Bảng Ánh xạ Tách Module & Khử Tham chiếu Cũ (Migration Crosswalk)

Khi chuyển từ bản đơn khối `v3.3` sang kiến trúc module `v3.4 / v3.4.1`, toàn bộ nội dung từng được dự kiến tách ra các tệp ngoài (`TDD`, `Content Spec`, `Content Schema`, `Production_Roadmap_3_4.md`) đã được **tích hợp trực tiếp vào các module chuyên sâu ngay trong `docs/gdd/`**. Bảng dưới đây ánh xạ chính xác vị trí tra cứu mới:

| Tham chiếu cũ (đã bãi bỏ ở v3.4.1) | Tệp thực tế hiện hành trong dự án | Nội dung đảm nhiệm |
|---|---|---|
| `[TDD §6.1]`, `[TDD §6.3]` (Hex, MP, LOS, ZoC) | [hex_grid_pathfinding.md](../mechanics/hex_grid_pathfinding.md) | Hệ tọa độ Axial `(q, r)`, chi phí địa hình, `FondTerrain`, `ZoC`/`CoC`, `IgnoreZoc`, `DevoidZoc` và định tuyến A*. |
| `[TDD §6.4]`, `[TDD §6.5]` (Combat, Rounding, Flank) | [combat_formulas.md](../mechanics/combat_formulas.md) | Công thức sát thương `Seeded RNG` (`80%–100%` + Crit), giáp `100/(100+EffectiveDef)`, `RoundHalfUp`, `TroopStack` (1x–3x), ma trận khắc chế & Flank. |
| `[TDD §6.6]` (Morale, Status, Bao vây) | [morale_and_status.md](../mechanics/morale_and_status.md) | 4 bậc Enum Sĩ khí (`HIGH/NORMAL/LOW/CHAOS`), 7 hiệu ứng khống chế CC, `TrappedLevel` và lan truyền tâm lý. |
| `[TDD §7.2]`, `[TDD §7.3]`, `[Content Schema §General/Unit/Skill]` | [data_and_save_system.md](../architecture/data_and_save_system.md) & [generals_and_meta_economy.md](../progression/generals_and_meta_economy.md) | Cấu trúc JSON tĩnh cho Binh chủng, Tướng, Kỹ năng, Duyên phận (`Fetters`) và Trang bị. |
| `[TDD §11]` (Render Layers, Input FSM, Camera) | [battle_ui_and_rendering.md](../ui_ux/battle_ui_and_rendering.md) | 15 Render Layers, FSM tương tác 5 trạng thái, xác nhận đòn đánh 2 bước và `StrategicZoom` 60 FPS. |
| `[TDD §12]` (AI Scoring & Architecture) | [ai_decision_matrix.md](../ai/ai_decision_matrix.md) | Kiến trúc AI 3 pha (Generators, Evaluators, Utility Scoring) trên GDScript Godot 4.7. |
| `[TDD §18.4]` & `Dai_Viet_Chronicles_Production_Roadmap_3_4.md` | [implementation_plan.md](../04_production_roadmap/implementation_plan.md) | Bảng Checkpoints kỹ thuật `CP1–CP5` ánh xạ `P0–P5`, lộ trình 12 tuần `W1–W12`, Gates `P1–P5` và quy trình kiểm thử headless + screenshot. |
| `Dai_Viet_Chronicles_Slice01_Content_Spec_3_4.md` | [scenario_scripting_and_events.md](../level_design/scenario_scripting_and_events.md) & [production_scope_mvp.md](../04_production_roadmap/production_scope_mvp.md) | Schema kịch bản `stage_id: 10101` (Bạch Đằng 1288), sự kiện `MapPhase_TideFall` Vòng 4, điều kiện thắng & 3 Sao. |
| Nguồn tham chiếu kỹ thuật & lịch sử rải rác bản 3.3 | [appendix_b_sources.md](../appendices/appendix_b_sources.md) & [ASSET_CATALOG.md](../../assets/ASSET_CATALOG.md) | Danh mục chuẩn hóa `[S1]–[S16]` (chính sử, khảo cổ học Bạch Đằng & benchmark) và sổ tay `2,464` tệp tài nguyên tham chiếu. |
