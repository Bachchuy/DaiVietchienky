# 16. Kế hoạch triển khai kỹ thuật, lộ trình thực thi và cổng kiểm duyệt

[← Quay lại Mục lục GDD](../README.md)

---

Tài liệu này quy định lộ trình triển khai thực chất kết nối trực tiếp giữa các mốc thiết kế **`P0–P5`** ([production_scope_mvp.md](production_scope_mvp.md#142-milestone-thiết-kế--sản-xuất-p0p5)), năm **Checkpoints kỹ thuật (`CP1–CP5`)**, kế hoạch thực thi **12 tuần (`W1–W12`)**, hệ thống **Design & Tech Gates (`P1–P5`)** và quy trình kiểm thử tự động bắt buộc trên nền tảng **Godot 4.7**.

---

## 16.1. Kiến trúc Triển khai Mã nguồn (Godot 4.7 — Pure GDScript 2.0)

Theo quyết định công nghệ đã khóa (`D-06`, `D-09`, `D-10`), toàn bộ dự án được phát triển bằng **100% Thuần GDScript 2.0 (Static Typing)** trên **Godot 4.7** sử dụng **`gl_compatibility` Renderer** để xuất bản liền mạch ra **Web (HTML5/Wasm) + Android** (phát triển và gỡ lỗi hàng ngày trên **Windows Desktop**) với mục tiêu hiệu năng cứng **60 FPS**.

Để bảo đảm tính tất định tuyệt đối và khả năng kiểm thử tự động không cần giao diện đồ họa, mã nguồn được phân tách nghiêm ngặt thành **2 phân lớp độc lập** (chi tiết cấu trúc lưu trữ xem tại [data_and_save_system.md](../architecture/data_and_save_system.md)):

1. **Tầng Lõi Mô phỏng (`res://scripts/core/` — SceneTree-Independent):**
   - Chỉ sử dụng các lớp dữ liệu thuần túy (`RefCounted`, `Resource`), **tuyệt đối không `extends Node`, không gọi trực tiếp `SceneTree`, `Tween` hay `RenderingServer`**.
   - Đảm nhiệm: Toán học lưới Hex `Pointy-topped Axial`, định tuyến A* + `ZOC`/`CoC` ([hex_grid_pathfinding.md](../mechanics/hex_grid_pathfinding.md)), `CombatResolver` tích hợp bộ sinh số `RandomNumberGenerator` riêng có lưu `seed/state` (`Seeded RNG`, giáp `100/(100+EffectiveDef)`, `RoundHalfUp` — [combat_formulas.md](../mechanics/combat_formulas.md)), `MoraleEngine` 4 bậc Enum (`HIGH/NORMAL/LOW/CHAOS` — [morale_and_status.md](../mechanics/morale_and_status.md)), `CommandQueue` hỗ trợ Undo 1 bước & **100% Deterministic Replay**, bộ giải mã sự kiện kịch bản JSON và bộ chấm điểm Utility AI ([ai_decision_matrix.md](../ai/ai_decision_matrix.md)).
2. **Tầng Trình diễn & Tương tác (`res://scripts/presentation/` — SceneTree-Bound):**
   - Quản lý cây cảnh Godot: 15 Render Layers, điều khiển Camera 2D + `StrategicZoom` (`Zoom < 0.7x`), máy trạng thái đầu vào 5 bước (`Two-Step Combat Confirmation`), HUD Map-First, hộp `Combat Preview` ([battle_ui_and_rendering.md](../ui_ux/battle_ui_and_rendering.md)), cùng hiệu ứng rung chấn camera, Hit-stop, `GPUParticles2D` và Audio Pooling ([vfx_sfx_and_polish.md](../vfx_sfx/vfx_sfx_and_polish.md)).

---

## 16.2. Bảng Checkpoints Kỹ thuật (`CP1–CP5`) ánh xạ sang Milestones (`P0–P5`)

> **Nguyên tắc quản trị:** Hoàn thành một Checkpoint kỹ thuật (`CP`) chứng minh hệ thống chạy đúng và đủ hiệu năng, nhưng **không tự động thay thế** cổng duyệt thiết kế (`Design Gate P1–P5`). Đặc biệt, bản dựng `CP4` phải vượt qua vòng Playtest độc lập `[D-17]` và rà soát nhãn lịch sử mới được công nhận hoàn tất mốc `P2`.

| Checkpoint Kỹ thuật | Ánh xạ Milestone | Hạng mục bàn giao kỹ thuật cốt lõi (Deliverables) | Tiêu chí nghiệm thu kỹ thuật (Tech DoD) |
|---|---|---|---|
| **`CP1: Hex Grid & Camera 60FPS`** | `P0` $\to$ Khởi đầu `P1` | Hệ tọa độ Hex `Pointy-topped Axial` (`12 × 10` cho Slice-01, stress-test tới `30 × 30`); định tuyến A* có chi phí địa hình, `FondTerrain`, `ZOC`/`CoC`, `IgnoreZoc`/`DevoidZoc`; Camera kéo/phóng mượt + chuyển đổi tự động `StrategicZoom` trên 15 Render Layers (`gl_compatibility`). | Đạt cứng **60 FPS** (`<= 16.67ms/frame`) khi hiển thị đồng thời 40+ đơn vị thử nghiệm; chọn ô, hiển thị vùng đi xanh / vùng bắn đỏ chính xác 100% trong headless test. |
| **`CP2: Turn Loop & Combat/Morale Core`** | **`P1` (Core Prototype)** | Vòng lặp 7 pha Turn/Phase; kiến trúc `Command` + Undo 1 bước/lượt + lưu/phát lại Replay; `CombatResolver` với `Seeded RNG` (`80%–100%` + Crit), giáp `100/(100+EffectiveDef)`, `TroopStack` (1x–3x), Phản kích tối đa 1 lần/lượt; `MoraleEngine` 4 bậc Enum (`HIGH/NORMAL/LOW/CHAOS`), bao vây `TrappedLevel` & lan truyền tâm lý. | 100% unit test `scripts/core/` vượt qua ở chế độ `--headless`; chạy lại cùng file replay `seed` qua 50 lượt không lệch 1 điểm HP hay trạng thái nào. |
| **`CP3: AI & Scenario Event Scripting`** | Nền tảng chức năng của **`P2`** | Bộ não AI 3 pha bằng GDScript (Generators $\to$ Evaluators $\to$ Utility Scoring); trình đọc kịch bản JSON (`stage_id: 10101`); hệ thống Trigger-Condition-Action chạy trọn vẹn sự kiện **`MapPhase_TideFall` đầu Vòng 4** (`StakedWater`: `-35% MaxHP`, `MarchDisabled` 2 lượt, `CHAOS` 1 lượt + Spawn phục binh Đại Việt); kiểm tra thắng tức thì khi hạ Ô Mã Nhi lúc giữ `SignalDock (2, 8)`. | Mô phỏng tự động AI-vs-AI 100 trận liên tiếp không crash, không treo lượt (soft-lock); thời gian tính toán mỗi lượt AI `< 1.5s`; kiểm chứng đủ cả 2 nhánh Thắng và 3 mốc Sao. |
| **`CP4: Playable Slice-01 Complete + UI/Audio Polish`** | **`P2` (Vertical Slice)** | Hoàn thiện HUD Map-First (`>= 80%` diện tích bản đồ), `Combat Preview` xác nhận 2 bước (hiển thị `[Min, Max]`, `% Crit`, phản kích & các thẻ modifier), Briefing, Hội thoại kịch bản, Tổng kết 3 Sao, Combat Log; tích hợp Trauma Shake, Hit-Stop, hiệu ứng sóng nước/cọc ngầm & Audio Pooling; khóa ẩn kinh tế (`enable_economy = false`). | Trọn vẹn Slice-01 chơi mượt từ màn hình tiêu đề đến kết thúc trận ở **60 FPS** trên Windows Desktop & bản xuất thử Web/Android; sẵn sàng bàn giao cho vòng Playtest độc lập `[D-17]`. |
| **`CP5: Web & Android Export Optimization + Release QA`** | `P3` $\to$ `P4` $\to$ **`P5` (Release MVP)** | Bổ sung module Kinh tế chiến trường (`P3`); nạp trọn vẹn Gói Chiến dịch Thời Trần (6–8 màn, 10–12 binh chủng, 8–10 tướng), Tutorial ngữ cảnh & Codex lịch sử; thay thế sạch 100% tài nguyên qua **Asset IP Gate** (`P4`); tối ưu đóng gói WebAssembly (nén Wasm/PCK, chống khựng shader) và APK/AAB Android cảm ứng đa điểm (`P5`). | Bản Web tải nhanh, không tràn bộ nhớ trình duyệt; bản Android và Web duy trì ổn định **60 FPS**; 0 lỗi P0/P1 tồn đọng; vượt qua toàn bộ bộ test hồi quy tự động và kiểm duyệt phát hành. |

---

## 16.3. Lộ trình Thực thi 12 Tuần (`W1–W12`) cho Giai đoạn Nền tảng & Vertical Slice-01

Lộ trình 12 tuần đầu tập trung đưa dự án từ khởi tạo kiến trúc Godot 4.7 GDScript sạch đến hoàn thành nghiệm thu **Gate `P2` (Vertical Slice Bạch Đằng 1288)**, tạo bàn đạp vững chắc để nhân rộng nội dung ở `P3–P5`:

| Tuần | Chặng công việc trọng tâm | Đầu ra kiểm chứng cụ thể | Cột mốc |
| :---: |---|---| :---: |
| **W1** | Khởi tạo cấu trúc dự án Godot 4.7 (`gl_compatibility`), thiết lập `scripts/core/` & `scripts/presentation/`, hệ tọa độ Hex Axial `(q, r)` và trình nạp JSON tĩnh cơ sở. | Chạy được bộ test toán học khoảng cách Hex, lân cận 6 hướng và nạp dữ liệu mẫu ở chế độ `--headless`. | — |
| **W2** | Triển khai định tuyến A* tích hợp địa hình, `FondTerrain`, `ZOC`/`CoC`, `IgnoreZoc`/`DevoidZoc`; dựng 15 Render Layers, điều khiển Camera 2D và `StrategicZoom`. | Bản đồ `12 × 10` hiển thị mượt ở **60 FPS**, chọn đơn vị vẽ đúng vùng xanh/đỏ, thu phóng chuyển sang Military Token mượt mà. | **Đạt `CP1`** |
| **W3** | Xây dựng vòng lặp trận đánh 7 pha, kiến trúc `Command Pattern`, cơ chế Undo 1 lần/lượt và bộ lưu trạng thái `Seeded RNG` (`RandomNumberGenerator`). | Thực thi được lệnh Di chuyển, Đứng thủ, Kết thúc lượt và hoàn tác hợp lệ không rò rỉ trạng thái. | — |
| **W4** | Cài đặt đầy đủ `CombatResolver` (`80%–100%` + Crit, giáp `100/(100+EffectiveDef)`, `TroopStack` 1x–3x, `Flank`, Phản kích 1 lần) và `MoraleEngine` 4 bậc Enum (`HIGH/NORMAL/LOW/CHAOS`, `TrappedLevel`). | Đánh thắng/thua được một trận giao tranh cơ bản; phát lại Replay khớp 100% từng con số sát thương. | **Đạt `CP2` & Gate `P1`** |
| **W5** | Phát triển hệ thống AI 3 pha bằng GDScript (sinh nước đi hợp lệ, chấm điểm vị trí/mục tiêu/bảo vệ cứ điểm, thực thi tuần tự có nhịp dừng camera). | Phe AI Đại Nguyên tự hành quân tiến công và phối hợp đánh mục tiêu hợp lý không gây đơ khung hình. | — |
| **W6** | Xây dựng Scripting Engine hướng dữ liệu (`Trigger – Condition – Action`): theo dõi số lượt, vùng tọa độ, máu tướng; thực thi đổi địa hình, gọi viện binh, bật hội thoại. | Hệ thống sự kiện đọc trực tiếp từ file kịch bản JSON mà không cần sửa cứng mã nguồn theo từng màn. | — |
| **W7** | Biên tập trọn vẹn dữ liệu **Slice-01 Bạch Đằng 1288 (`stage_id: 10101`)**: bố trí hai phe, sự kiện `MapPhase_TideFall` đầu Vòng 4 lộ bãi cọc `StakedWater`, phục binh xuất kích và 2 nhánh điều kiện Thắng + 3 Sao. | Chơi thông suốt kịch bản 10 lượt từ Hồi 1 đến Hồi 3; hạ Ô Mã Nhi khi giữ `SignalDock (2, 8)` kích hoạt thắng ngay lập tức. | **Đạt `CP3`** |
| **W8** | Hoàn thiện giao diện chiến trường Map-First: Input FSM 5 trạng thái, hộp `Combat Preview` xác nhận 2 bước (Min–Max, `% Crit`, phản kích), thanh Top Bar, màn Briefing & Battle Result 3 Sao. | Mọi thao tác điều quân & tấn công đạt chuẩn `<= 2 chạm`; ẩn sạch các nút/chỉ số kinh tế (`enable_economy = false`). | — |
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
| **Gate `P1`** *(Trước khi làm Slice-01)* | Luật cốt lõi (`D-11, D-12, D-13`) cho cảm giác đánh đổi vị trí rõ ràng; khoảng sát thương `Seeded RNG` (`80%–100%` + Crit) dễ đọc và không gây ức chế. | Đạt `CP1` + `CP2`; `scripts/core/` tách biệt 100% khỏi `SceneTree`; bộ headless unit tests cho Combat, Morale, ZoC và Deterministic Replay đạt 100% pass. |
| **Gate `P2`** *(Trước khi nhân rộng nội dung)* | Hoàn thành Playtest `[D-17]` đạt **`>= 4/5` người chơi ngoài dev** hiểu đúng điều kiện thắng/thua & bước ngoặt Vòng 4; chốt xong `D-15, D-16`; mọi chi tiết lịch sử có `sourceRef` hoặc gắn nhãn `fixture / gameplay abstraction` chuẩn. | Đạt `CP3` + `CP4`; chơi trọn vẹn `stage_id: 10101` không lỗi soft-lock; xác nhận **60 FPS** kèm ảnh chụp kiểm chứng giao diện trên cả Desktop, bản thử Web và Android. |
| **Gate `P3`** *(Trước khi sản xuất hàng loạt Beta)* | Kinh tế chiến trường (`MealFood`, `Starvation`, cướp lương) hòa quyện tự nhiên với nhịp đánh theo lượt, không biến trận đánh thành quản lý bảng tính; chốt dứt điểm `D-04, D-05`. | Hệ thống Save/Load 2 tầng (`Session` & `Profile`) tương thích ngược ổn định; thời gian lượt AI khi có thêm biến kinh tế vẫn giữ dưới `3.0 giây`. |
| **Gate `P4`** *(Trước khi đóng gói Release Candidate)* | Đủ 6–8 màn Gói Thời Trần có `Dossier` lịch sử được duyệt (`D-08`); Tutorial theo ngữ cảnh và Codex hoàn chỉnh; chốt thông số mô hình F2P thân thiện dài hạn (`D-07`). | **Vượt qua Asset IP Gate:** 0% tệp đồ họa/âm thanh/dữ liệu placeholder thương mại còn sót lại trong gói build; dung lượng tải WebAssembly và RAM sử dụng nằm trong ngưỡng an toàn của trình duyệt di động. |
| **Gate `P5`** *(Release Readiness Sign-off)* | Trải nghiệm tổng thể từ màn đầu tiên đến màn kết thúc Gói Thời Trần liền mạch, cân bằng đủ 4 mức độ khó, đạt toàn bộ chỉ số định lượng UX tại [Phụ lục A](../appendices/appendix_a_benchmark_matrix.md). | Hoàn tất `CP5`; đạt **60 FPS** ổn định trên danh mục trình duyệt Web (Chrome/Edge/Safari/Firefox) và các dòng máy Android mục tiêu; 0 lỗi Crash/Blocker. |

---

## 16.5. Quy chuẩn Kiểm thử Tự động (`Headless Test`) & Xác minh Hình ảnh (`Screenshot Verification`)

Tuân thủ quy tắc kỹ thuật cốt lõi của dự án, mọi tính năng gameplay hoặc giao diện khi bổ sung/chỉnh sửa **bắt buộc phải đi kèm hai lớp bằng chứng thực tế** trước khi báo cáo hoàn thành:

1. **Kiểm thử Logic Tự động Không Giao diện (`Headless Verification`):**
   - Thực thi trực tiếp bằng dòng lệnh Godot (`godot --headless --script res://tests/run_all_tests.gd`) trên tầng `scripts/core/`.
   - Phạm vi kiểm tra bắt buộc:
     - Độ chính xác toán học của công thức sát thương, đường cong giáp `100 / (100 + EffectiveDef)` và quy tắc làm tròn `RoundHalfUp`.
     - Tính tất định 100% của `Seeded RNG`: hai phiên mô phỏng độc lập nạp cùng `seed` và chuỗi `Command` phải sinh ra kết quả `CurrentHP`, `TroopStack` và bậc `Morale` giống hệt nhau tuyệt đối.
     - Chu trình chuyển trạng thái Sĩ khí 4 bậc (đặc biệt là cơ chế `CHAOS` khóa hành động đúng số lượt rồi tự hồi về `LOW`) và kích hoạt chính xác sự kiện `MapPhase_TideFall` ở đầu Vòng 4 (`stage_id: 10101`).
     - Chạy mô phỏng hàng loạt trận AI tự đấu để phát hiện sớm lỗi kẹt đường đi, chia cho 0 hoặc treo vòng lặp lượt.
2. **Kiểm chứng Thị giác Thực tế (`Screenshot & Visual Verification`):**
   - Khởi chạy cảnh thực tế trên `gl_compatibility` và trích xuất ảnh chụp màn hình (screenshot) tại các thời điểm trọng yếu:
     - Toàn cảnh bản đồ Hex ở cả mức zoom cận cảnh lẫn mức thu phóng xa kích hoạt `StrategicZoom` (`Zoom < 0.7x`).
     - Trạng thái mở hộp **Combat Preview 2 bước**, kiểm tra rõ sự hiển thị không tràn lề của khoảng sát thương `[Min, Max]`, `% Crit`, phản kích và các huy hiệu địa hình/sĩ khí.
     - Khoảnh khắc đầu Vòng 4 khi bãi cọc ngầm Bạch Đằng nhô lên đâm thủng thuyền địch kèm hiệu ứng `CHAOS` / `MarchDisabled`, và màn hình Tổng kết 3 Sao.
   - Kiểm tra chéo trên cả khung hình ngang tiêu chuẩn Desktop/Web (`16:9`) và tỷ lệ màn hình dài phổ biến trên điện thoại Android (`19.5:9` / `20:9`) để đảm bảo không che khuất vùng thao tác.
