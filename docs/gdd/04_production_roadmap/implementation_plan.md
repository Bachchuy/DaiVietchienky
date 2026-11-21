# 16. Kế hoạch triển khai kỹ thuật, lộ trình thực thi và cổng kiểm duyệt

[← Quay lại Mục lục GDD](../README.md)

---

Tài liệu này quy định lộ trình triển khai thực chất kết nối trực tiếp giữa các mốc thiết kế **`P0–P5`** ([production_scope_mvp.md](production_scope_mvp.md#142-milestone-thiết-kế--sản-xuất-p0p5)), năm **Checkpoints kỹ thuật (`CP1–CP5`)**, kế hoạch thực thi **12 tuần (`W1–W12`)**, hệ thống **Design & Tech Gates (`P1–P5`)** và quy trình kiểm thử tự động bắt buộc trên nền tảng **Godot 4.7**.

---

## 16.1. Kiến trúc Triển khai Mã nguồn 4 Tầng (`<= 400 dòng/script` — Editor-First)

Theo quyết định công nghệ đã khóa (`D-06`, `D-09`, `D-10`, `DEC-023`, `DEC-024`), toàn bộ dự án được phát triển bằng **100% Thuần GDScript 2.0 (Static Typing)** trên **Godot 4.7** sử dụng **`gl_compatibility` Renderer** cho **Web (HTML5/Wasm) + Android** (phát triển và kiểm thử trên **Windows Desktop**) với mục tiêu **60 FPS**.

Để kết hợp sức mạnh **Editor-First** của Godot (scene `.tscn` chỉnh được trong View 2D, dữ liệu `.tres` chỉnh trong Inspector) với **lõi mô phỏng tất định có unit test**, mã nguồn được tổ chức theo **Kiến trúc 4 Tầng ("Lõi thuần + Vỏ dựng trong Editor")** với giới hạn cứng **`<= 400` dòng mỗi script**:

1. **Tầng Dữ liệu Tĩnh (`res://data/` — Custom `Resource` `.tres` + `@tool` Map Scenes `.tscn`):**
   - Chứa `TroopDef`, `GeneralDef`, `TacticDef`, `FacilityDef`, `CodexEntryDef`, `StageDef` và `res://data/registry.tres` (`DataRegistry`), cùng bản đồ từng màn (`res://data/stages/<id>_<slug>/stage_<id>_map.tscn` dùng `TileMapLayer`).
2. **Tầng Lõi Mô phỏng (`res://sim/` — `RefCounted` Thuần, Độc lập `SceneTree`):**
   - Gồm `sim/state/`, `sim/commands/`, `sim/rules/`, `sim/ai/`. **Tuyệt đối không `extends Node`, không gọi trực tiếp `SceneTree`, `Tween` hay `RenderingServer`.**
   - Đảm nhiệm: Toán học lưới Hex, A* + `ZOC`/`CoC`, `CombatResolver` (`Seeded RNG` và giáp `100/(100+EffectiveDef)`), `MoraleEngine` 4 bậc Enum, `BattleEconomy`, `CommandHistory` (Undo 1 bước & 100% Deterministic Replay), `ScenarioEventManager` và `AIDecisionMatrix`.
3. **Tầng Phiên Trận Đánh (`res://game/battle/battle_session.gd`):**
   - `BattleSession` là Node duy nhất giữ `BattleGameController` / `BattleState`, tiếp nhận `Command` từ UI/AI (`submit(cmd)`) và phát các `signal` có kiểu ra tầng trình diễn.
4. **Tầng Trình diễn & Giao diện (`res://game/battle/`, `res://ui/` — Scene `.tscn` + `theme.tres`):**
   - Các Scene mở được trong View 2D: `battle.tscn`, `battle_map.tscn` (`TileMapLayer`), `unit_view.tscn` (ghép Component `Sprite2D` + `AnimationPlayer` + `UnitAnimatorComponent` + `HealthBarComponent` + `StatusBadgeComponent`), `BattleCameraController`, `BattleInputFSM` (**7 trạng thái, đánh ngay 1 chạm**, bỏ `AimingTarget`), cùng các scene HUD/Modal tách rời trong `ui/battle_hud/*.tscn` (`top_bar.tscn`, `unit_inspector.tscn`, `command_dock.tscn`, `briefing_modal.tscn`, `pause_modal.tscn`,...) dùng chung `ui/common/theme.tres`.
   - `res://autoload/` chỉ dành cho dịch vụ toàn cục không chứa state trận (`Settings`, `SaveService`, `Audio`, `SceneRouter`). Phụ thuộc truyền có kiểu qua `@export var session: BattleSession`.

---

## 16.2. Checkpoints Nền tảng (`CP1–CP5`) & Lộ trình Tái Kiến Trúc Editor-First (`R1–R5` / `CP6–CP10`)

> [!IMPORTANT] **Trạng thái Kiểm toán `CP1–CP5` (21/11/2026 — `DEC-025`):**  
> - Kết quả chạy thực tế cho thấy **`CP1–CP5` cũ chỉ đạt phần Lõi Mô phỏng (`Sim` + `82/82` unit tests)**, còn **lớp vỏ trình diễn (UI sinh bằng code bị cắt nút `clip_contents`, Scene `1-node` trống View 2D, dữ liệu JSON không chỉnh được trong Inspector, và `CombatPreviewBox`) đã bị BÁC BỎ (`DEC-021..DEC-026`)**.  
> - Do đó dự án triển khai **Bộ Cổng Tái Kiến Trúc & Nâng cấp Đồ họa `R1–R5` (`CP6–CP10`)**, làm chuẩn chỉnh **Vertical Slice `10101` Bạch Đằng 1288** trước (`R1–R4`) rồi mới nhân rộng ra 5 màn còn lại (`R5`).

| Cổng Mới (`R1–R5`) | Hạng mục Bàn giao Trọng tâm | Tiêu chí Vượt cổng Bắt buộc (Tech & Player DoD) |
|---|---|---|
| **`R1` (`CP6`): Cấu trúc 4 Tầng, FSM 7 Trạng Thái & UI `.tscn`** | Di chuyển lõi sang `res://sim/`, tạo `BattleSession`, rút gọn `BattleInputFSM` xuống **7 trạng thái (đánh ngay 1 chạm)**; dựng `theme.tres`, `modal_frame.tscn` & bộ `ui/battle_hud/*.tscn` (gồm **`unit_inspector.tscn`**, xóa bỏ `CombatPreviewBox` và `battle_hud_controller.gd` 1.556 dòng). | Mọi script `<= 400` dòng; `82/82` unit tests xanh; bộ E2E chạy `assert_button_reachable()` qua `Viewport.push_input` thật; ảnh chụp mọi modal không bị cắt nút/chữ ở `16:9` & `19.5:9`. |
| **`R2` (`CP7`): Dữ liệu Custom `Resource` (`.tres`) trong Inspector** | Định nghĩa `TroopDef`, `GeneralDef`, `TacticDef`, `FacilityDef`, `CodexEntryDef`, `StageDef` + Sub-Resources (`@export`) và `DataRegistry` (`res://data/registry.tres`); chuyển dữ liệu từ JSON sang `.tres` và đọc trực tiếp vào `Sim`. | Chỉnh được toàn bộ thông số binh chủng, tướng, sự kiện Bạch Đằng ngay trong Godot Inspector; test đối chiếu khớp 100% thông số gốc. |
| **`R3` (`CP8`): `TileMapLayer`, `UnitView.tscn` & Asset Sạch `HexCrown` (Màn `10101`)** | Kế thừa bộ `TileSet`, công trình Đỏ/Xanh, 12 sprite sheet `32×32`, shader & SFX sạch từ `HexCrown` vào `res://assets_clean/hexcrown/`; dựng `unit_view.tscn` ghép Component, `stage_10101_map.tscn` (`TileMapLayer` + `@tool`) và `battle.tscn`; xóa `battle_map_view.gd` & `battle_sandbox_cp1.gd`. | Mở Godot Editor thấy ngay bản đồ sông Bạch Đằng & quân trên View 2D; Inspector hiện đầy đủ thuộc tính; chạy `F5` từ `main_menu.tscn` qua trọn vẹn màn `10101` ở **60 FPS**. |
| **`R4` (`CP9` — 🛑 CỔNG DỪNG HỎI NGƯỜI DÙNG): So sánh 2 Mẫu Mỹ thuật** | **Dừng lại hỏi người dùng lên phương án & chọn công cụ** trước khi tạo asset mới. Dựng 2 mẫu nhỏ trên cùng cảnh Bạch Đằng: **Pixel Art** (đồng bộ `HexCrown` kèm Chiến thuyền + Bãi cọc) vs **2D Cách điệu lịch sử kiểu EasyTech** thiết kế riêng. | Người dùng xem trực quan 2 mẫu, chốt phong cách mỹ thuật chính thức và lộ trình thay thế dần asset `HexCrown`. |
| **`R5` (`CP10`): Nhân rộng 5 Màn Thời Trần (`10102–10106`) & Release QA** | Dựng `stage_<id>_map.tscn` (`TileMapLayer`) và `stage_<id>.tres` cho 5 màn `10102–10106` (gồm Vân Đồn bật kinh tế); nâng cấp `main_menu.tscn` & `codex_panel.tscn` theo `theme.tres`; tối ưu xuất bản Web & Android. | Toàn bộ 6 màn mở được trong View 2D Editor; `0` lỗi P0/P1; vượt qua trọn vẹn Unit + E2E (`assert_button_reachable`) + đạt 60 FPS Web/Android. |

### Bảng Checkpoints Giai đoạn 1 (`CP1–CP5` cũ — Giữ tham chiếu lịch sử phần Lõi Sim):

> **Nguyên tắc quản trị:** Hoàn thành một Checkpoint kỹ thuật (`CP`) chứng minh hệ thống chạy đúng và đủ hiệu năng, nhưng **không tự động thay thế** cổng duyệt thiết kế (`Design Gate P1–P5`). Đặc biệt, bản dựng `CP4` phải vượt qua vòng Playtest độc lập `[D-17]` và rà soát nhãn lịch sử mới được công nhận hoàn tất mốc `P2`.

| Checkpoint Kỹ thuật | Ánh xạ Milestone | Hạng mục bàn giao kỹ thuật cốt lõi (Deliverables) | Tiêu chí nghiệm thu kỹ thuật (Tech DoD) |
|---|---|---|---|
| **`CP1: Hex Grid & Camera 60FPS`** | `P0` $\to$ Khởi đầu `P1` | Hệ tọa độ Hex `Pointy-topped Axial` (`12 × 10` cho Slice-01, stress-test tới `30 × 30`); định tuyến A* có chi phí địa hình, `FondTerrain`, `ZOC`/`CoC`, `IgnoreZoc`/`DevoidZoc`; Camera kéo/phóng mượt + chuyển đổi tự động `StrategicZoom` trên 15 Render Layers (`gl_compatibility`). | Đạt cứng **60 FPS** (`<= 16.67ms/frame`) khi hiển thị đồng thời 40+ đơn vị thử nghiệm; chọn ô, hiển thị vùng đi xanh / vùng bắn đỏ chính xác 100% trong headless test. |
| **`CP2: Turn Loop & Combat/Morale Core`** | **`P1` (Core Prototype)** | Vòng lặp 7 pha Turn/Phase; kiến trúc `Command` + Undo 1 bước/lượt + lưu/phát lại Replay; `CombatResolver` với `Seeded RNG` (`80%–100%` + Crit), giáp `100/(100+EffectiveDef)`, `TroopStack` (1x–3x), Phản kích tối đa 1 lần/lượt; `MoraleEngine` 4 bậc Enum (`HIGH/NORMAL/LOW/CHAOS`), bao vây `TrappedLevel` & lan truyền tâm lý. | 100% unit test `scripts/core/` vượt qua ở chế độ `--headless`; chạy lại cùng file replay `seed` qua 50 lượt không lệch 1 điểm HP hay trạng thái nào. |
| **`CP3: AI & Scenario Event Scripting`** | Nền tảng chức năng của **`P2`** | Bộ não AI 3 pha bằng GDScript (Generators $\to$ Evaluators $\to$ Utility Scoring); trình đọc kịch bản JSON (`stage_id: 10101`); hệ thống Trigger-Condition-Action chạy trọn vẹn sự kiện **`MapPhase_TideFall` đầu Vòng 4** (`StakedWater`: `-35% MaxHP`, `MarchDisabled` 2 lượt, `CHAOS` 1 lượt + Spawn phục binh Đại Việt); kiểm tra thắng tức thì khi hạ Ô Mã Nhi lúc giữ `SignalDock (2, 8)`. | Mô phỏng tự động AI-vs-AI 100 trận liên tiếp không crash, không treo lượt (soft-lock); thời gian tính toán mỗi lượt AI `< 1.5s`; kiểm chứng đủ cả 2 nhánh Thắng và 3 mốc Sao. |
| **`CP4: Playable Slice-01 Complete + UI/Audio Polish`** | **`P2` (Vertical Slice)** | Hoàn thiện HUD Map-First (`>= 80%` diện tích bản đồ), `UnitInspector` (chỉ thông số đạo quân, đánh ngay 1 chạm), Briefing, Hội thoại kịch bản, Tổng kết 3 Sao, Combat Log; tích hợp Trauma Shake, Hit-Stop, hiệu ứng sóng nước/cọc ngầm & Audio Pooling; khóa ẩn kinh tế (`enable_economy = false`). | Trọn vẹn Slice-01 chơi mượt từ màn hình tiêu đề đến kết thúc trận ở **60 FPS** trên Windows Desktop & bản xuất thử Web/Android; sẵn sàng bàn giao cho vòng Playtest độc lập `[D-17]`. |
| **`CP5: Web & Android Export Optimization + Release QA`** | `P3` $\to$ `P4` $\to$ **`P5` (Release MVP)** | Bổ sung module Kinh tế chiến trường (`P3`); nạp trọn vẹn Gói Chiến dịch Thời Trần (6–8 màn, 10–12 binh chủng, 8–10 tướng), Tutorial ngữ cảnh & Codex lịch sử; thay thế sạch 100% tài nguyên qua **Asset IP Gate** (`P4`); tối ưu đóng gói WebAssembly (nén Wasm/PCK, chống khựng shader) và APK/AAB Android cảm ứng đa điểm (`P5`). | Bản Web tải nhanh, không tràn bộ nhớ trình duyệt; bản Android và Web duy trì ổn định **60 FPS**; 0 lỗi P0/P1 tồn đọng; vượt qua toàn bộ bộ test hồi quy tự động và kiểm duyệt phát hành. |

---

## 16.3. Lộ trình Thực thi 12 Tuần (`W1–W12`) cho Giai đoạn Nền tảng & Vertical Slice-01

Lộ trình 12 tuần đầu tập trung đưa dự án từ khởi tạo kiến trúc Godot 4.7 GDScript sạch đến hoàn thành nghiệm thu **Gate `P2` (Vertical Slice Bạch Đằng 1288)**, tạo bàn đạp vững chắc để nhân rộng nội dung ở `P3–P5`:

| Tuần | Chặng công việc trọng tâm | Đầu ra kiểm chứng cụ thể | Cột mốc |
| :---: |---|---| :---: |
| **W1** | Khởi tạo cấu trúc dự án Godot 4.7 (`gl_compatibility`), thiết lập 4 tầng `data/` / `sim/` / `game/` / `ui/`, hệ tọa độ Hex Axial `(q, r)` và Custom `Resource` (`.tres`) cơ sở. | Chạy được bộ test toán học khoảng cách Hex, lân cận 6 hướng và nạp `DataRegistry` `.tres` ở chế độ `--headless`. | — |
| **W2** | Triển khai định tuyến A* tích hợp địa hình, `FondTerrain`, `ZOC`/`CoC`, `IgnoreZoc`/`DevoidZoc`; dựng `TileMapLayer` + 16 lớp kết xuất, điều khiển Camera 2D và `StrategicZoom`. | Bản đồ `12 × 10` hiển thị mượt ở **60 FPS**, chọn đơn vị vẽ đúng vùng xanh/đỏ, thu phóng chuyển sang Military Token mượt mà. | **Đạt `CP1`** |
| **W3** | Xây dựng vòng lặp trận đánh 7 pha, kiến trúc `Command Pattern`, cơ chế Undo 1 lần/lượt và bộ lưu trạng thái `Seeded RNG` (`RandomNumberGenerator`). | Thực thi được lệnh Di chuyển, Đứng thủ, Kết thúc lượt và hoàn tác hợp lệ không rò rỉ trạng thái. | — |
| **W4** | Cài đặt đầy đủ `CombatResolver` (`80%–100%` + Crit, giáp `100/(100+EffectiveDef)`, `TroopStack` 1x–3x, `Flank`, Phản kích 1 lần) và `MoraleEngine` 4 bậc Enum (`HIGH/NORMAL/LOW/CHAOS`, `TrappedLevel`). | Đánh thắng/thua được một trận giao tranh cơ bản; phát lại Replay khớp 100% từng con số sát thương. | **Đạt `CP2` & Gate `P1`** |
| **W5** | Phát triển hệ thống AI 3 pha bằng GDScript (sinh nước đi hợp lệ, chấm điểm vị trí/mục tiêu/bảo vệ cứ điểm, thực thi tuần tự có nhịp dừng camera). | Phe AI Đại Nguyên tự hành quân tiến công và phối hợp đánh mục tiêu hợp lý không gây đơ khung hình. | — |
| **W6** | Xây dựng Scripting Engine hướng dữ liệu (`Trigger – Condition – Action`): theo dõi số lượt, vùng tọa độ, máu tướng; thực thi đổi địa hình, gọi viện binh, bật hội thoại. | Hệ thống sự kiện đọc trực tiếp từ `StageDef` (`.tres`) mà không cần sửa cứng mã nguồn theo từng màn. | — |
| **W7** | Biên tập trọn vẹn **Slice-01 Bạch Đằng 1288 (`stage_10101_map.tscn` + `stage_10101.tres`)**: bố trí hai phe, sự kiện `MapPhase_TideFall` đầu Vòng 4 lộ bãi cọc `StakedWater`, phục binh xuất kích và 2 nhánh điều kiện Thắng + 3 Sao. | Chơi thông suốt kịch bản 10 lượt từ Hồi 1 đến Hồi 3; hạ Ô Mã Nhi khi giữ `SignalDock (2, 8)` kích hoạt thắng ngay lập tức. | **Đạt `CP3`** |
| **W8** | Hoàn thiện giao diện chiến trường Map-First bằng scene `.tscn`: Input FSM **7 trạng thái (đánh ngay 1 chạm)**, `UnitInspector` (thông số thô của từng đạo quân), thanh Top Bar, màn Briefing & Battle Result 3 Sao. | Mọi nút UI đều bấm được (`assert_button_reachable`); ẩn sạch các nút/chỉ số kinh tế (`enable_economy = false`). | — |
| **W9** | Đánh bóng cảm giác va chạm (Game Feel / Juice): Hit-flash trắng, Trauma Camera Shake, Hit-stop khi nổ Crit/vỡ cọc, hiệu ứng dòng chảy sông Bạch Đằng và Audio SFX Pooling. | Phản hồi thị giác – thính giác đầm tay khi thuyền giặc đâm phải bãi cọc nhọn Vòng 4 và khi Sĩ khí rớt xuống `CHAOS`. | — |
| **W10** | Đóng băng tính năng Slice-01; chạy kiểm thử xuất bản sớm ra **HTML5/Wasm (Web)** và **APK (Android)** để đo đạc FPS, tốc độ tải và độ nhạy cảm ứng. | Bản dựng Slice-01 chạy ổn định **60 FPS** trên cả Windows Desktop, trình duyệt Web và thiết bị Android thử nghiệm. | **Đạt `CP4`** |
| **W11** | Tổ chức vòng **Playtest độc lập `[D-17]`** (tối thiểu 5 người chơi ngoài dev); song song rà soát hồ sơ `Dossier` lịch sử Bạch Đằng 1288 (`[S12]–[S16]`) và kiểm tra nhãn `fixture / gameplay abstraction`. | Biên bản thu thập đầy đủ thời lượng trận, tỷ lệ hiểu luật (`>= 4/5`), điểm nghẽn UI và chiến thuật co cụm (nếu có). | — |
| **W12** | Hiệu chỉnh cân bằng chỉ số `fixture`, tinh chỉnh `D-15` & `D-16` dựa trên dữ liệu Playtest; đóng băng Baseline GDD và chốt kế hoạch sản xuất chi tiết cho `P3–P5` (Gói Thời Trần). | Vượt qua kỳ nghiệm thu tổng thể Vertical Slice; sẵn sàng mở khóa phát triển Kinh tế chiến trường (`P3`) và sản xuất hàng loạt màn chơi Thời Trần (`P4–P5`). | **Đạt Gate `P2` (Freeze Baseline)** |

> **Khung mở rộng sau Tuần 12 (`P3 → P5` / Tiến tới `CP5`):**
> - **Giai đoạn P3 Alpha (4–6 tuần):** Kích hoạt module Kinh tế chiến trường (`battlefield_economy.md`), `CommandProfile`, sản xuất 3 màn tiếp theo của Thời Trần và chốt `D-04, D-05`.
> - **Giai đoạn P4 Beta (6–8 tuần):** Hoàn thiện đủ 6–8 màn Gói Thời Trần, 10–12 binh chủng, 8–10 danh tướng, Tutorial & Codex; thực thi **Asset IP Gate** thay thế 100% tài nguyên gốc Đại Việt; chốt `D-07, D-08`.
> - **Giai đoạn P5 Release MVP (3–4 tuần):** Hoàn tất `CP5` tối ưu hóa sâu WebAssembly & Android, kiểm thử tương thích thiết bị diện rộng, khóa cân bằng cuối và phát hành chính thức bản 1.0.

---

## 16.4. Hệ thống Cổng Kiểm duyệt Thiết kế & Kỹ thuật (`Design & Tech Gates P1–P5`)

Không được phép chuyển giai đoạn sản xuất nếu chưa vượt qua đồng thời cả **Tiêu chí Thiết kế (Design Gate)** và **Tiêu chí Kỹ thuật (Tech Gate)** tại mỗi cổng dưới đây:

| Cổng duyệt | Tiêu chí Design Gate (Do Design & Content Lead ký duyệt) | Tiêu chí Tech & QA Gate (Do Tech Lead ký duyệt) |
| :---: |---|---|
| **Gate `P1`** *(Trước khi làm Slice-01)* | Luật cốt lõi (`D-11, D-12, D-13`, `DEC-026`) cho cảm giác đánh đổi vị trí rõ ràng; thông số đạo quân trên `UnitInspector` minh bạch và hệ số `Seeded RNG` (`80%–100%` + Crit) cân bằng. | Đạt `CP1` + `CP2` / `R1` + `R2`; `res://sim/` tách biệt 100% khỏi `SceneTree`; bộ headless unit tests cho Combat, Morale, ZoC và Deterministic Replay đạt 100% pass. |
| **Gate `P2`** *(Trước khi nhân rộng nội dung)* | Hoàn thành Playtest `[D-17]` đạt **`>= 4/5` người chơi ngoài dev** hiểu đúng điều kiện thắng/thua & bước ngoặt Vòng 4; chốt xong `D-15, D-16`; mọi chi tiết lịch sử có `sourceRef` hoặc gắn nhãn `fixture / gameplay abstraction` chuẩn. | Đạt `CP3` + `CP4`; chơi trọn vẹn `stage_id: 10101` không lỗi soft-lock; xác nhận **60 FPS** kèm ảnh chụp kiểm chứng giao diện trên cả Desktop, bản thử Web và Android. |
| **Gate `P3`** *(Trước khi sản xuất hàng loạt Beta)* | Kinh tế chiến trường (`MealFood`, `Starvation`, cướp lương) hòa quyện tự nhiên với nhịp đánh theo lượt, không biến trận đánh thành quản lý bảng tính; chốt dứt điểm `D-04, D-05`. | Hệ thống Save/Load 2 tầng (`Session` & `Profile`) tương thích ngược ổn định; thời gian lượt AI khi có thêm biến kinh tế vẫn giữ dưới `3.0 giây`. |
| **Gate `P4`** *(Trước khi đóng gói Release Candidate)* | Đủ 6–8 màn Gói Thời Trần có `Dossier` lịch sử được duyệt (`D-08`); Tutorial theo ngữ cảnh và Codex hoàn chỉnh; chốt thông số mô hình F2P thân thiện dài hạn (`D-07`). | **Vượt qua Asset IP Gate:** 0% tệp đồ họa/âm thanh/dữ liệu placeholder thương mại còn sót lại trong gói build; dung lượng tải WebAssembly và RAM sử dụng nằm trong ngưỡng an toàn của trình duyệt di động. |
| **Gate `P5`** *(Release Readiness Sign-off)* | Trải nghiệm tổng thể từ màn đầu tiên đến màn kết thúc Gói Thời Trần liền mạch, cân bằng đủ 4 mức độ khó, đạt toàn bộ chỉ số định lượng UX tại [Phụ lục A](../appendices/appendix_a_benchmark_matrix.md). | Hoàn tất `CP5`; đạt **60 FPS** ổn định trên danh mục trình duyệt Web (Chrome/Edge/Safari/Firefox) và các dòng máy Android mục tiêu; 0 lỗi Crash/Blocker. |

---

## 16.5. Quy chuẩn Kiểm thử 3 Lớp (`Headless Sim` + `E2E Reachability` + `Editor & Player Visual Check`)

Tuân thủ quy tắc kỹ thuật cốt lõi tại [AGENTS.md](../../../AGENTS.md), mọi tính năng gameplay hoặc giao diện khi bổ sung/chỉnh sửa **bắt buộc phải đi kèm đầy đủ 3 lớp bằng chứng thực tế** trước khi báo cáo hoàn thành:

1. **Kiểm thử Lõi Mô phỏng (`Headless Unit Verification`):**
   - Thực thi trực tiếp bằng dòng lệnh Godot (`godot --headless --script tests/run_tests.gd`) trên tầng `res://sim/`.
   - Phạm vi kiểm tra bắt buộc: Toán học `CombatResolver` (`100 / (100 + EffectiveDef)` & `RoundHalfUp`), tính tất định 100% của `Seeded RNG` khi phát lại Replay 50 lượt, Sĩ khí 4 bậc (`CHAOS -> LOW`), `MapPhase_TideFall` ở đầu Vòng 4, AI tự đấu không treo lượt, và đối chiếu toàn bộ chỉ số `Resource` (`.tres`) trong `DataRegistry`.
2. **Kiểm thử E2E Tương tác & UI Bấm được (`assert_button_reachable`):**
   - Thực thi `godot --headless --script res://tests/e2e/run_e2e.gd`: mọi nút UI trọng yếu (`StartButton`, `SkipButton`, `ResumeButton`, nút Command Dock) phải khẳng định khung `get_global_rect()` nằm trọn trong mọi tổ tiên `clip_contents` lẫn viewport, và thao tác click phải đi qua `Viewport.push_input()` thật (cấm đánh lừa test bằng `_input()` hit-test giả hoặc gọi trực tiếp `pressed.emit()`).
   - Kiểm chứng luồng `UnitInspector` (chạm đơn vị chỉ hiện thông số thô, không hiện sát thương dự kiến) và **đánh ngay 1 chạm** khi bấm vào địch sáng Đỏ trong tầm.
3. **Kiểm chứng Thị giác như Người chơi & Mở Godot Editor:**
   - Mở xem trực tiếp từng ảnh chụp màn hình (`16:9` `1280×720` và `19.5:9` `1560×720`) với câu hỏi: *"Người chơi có thấy rõ nút đi tiếp không? Chữ hay thanh trượt có bị cắt/tràn không?"*. Thấy lỗi phải sửa hoặc báo CHƯA XONG.
   - Trước khi báo xong một cổng: mở project trong Godot Editor, xác nhận View 2D (`battle.tscn`, `stage_10101_map.tscn`) và Inspector (`.tres`) có đầy đủ nội dung chỉnh được, và chạy `F5` từ `main_menu.tscn` đi qua hết luồng mở đầu.
