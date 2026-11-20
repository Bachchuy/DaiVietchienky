# Nhật Ký Quyết Định Kỹ Thuật & Thiết Kế (`DECISIONS.md`)

Ghi lại toàn bộ các lựa chọn tự chủ khi gặp điểm mơ hồ hoặc cần đồng bộ chi tiết giữa các module GDD v3.4.1.

---

## DEC-001 — Cô lập thư mục `Assets/` cũ và chuẩn hóa nguồn tài nguyên sạch 100%
- **Vấn đề:** Trên ổ đĩa có sẵn thư mục `Assets/` (~2.464 file placeholder R&D) được nhắc trong tài liệu cũ, nhưng quy chế dự án cấm tuyệt đối nội dung thương mại và yêu cầu mọi tài nguyên phải khai báo trong `ASSETS.md`.
- **Lựa chọn:** Đưa `/Assets/` vào `.gitignore` và đặt `Assets/.gdignore` để Godot bỏ qua hoàn toàn thư mục cũ; chỉ dùng vẽ hình học procedural (`CanvasItem._draw()`), shader `.gdshader` tự viết hoặc tài nguyên đồ họa tạo mới sạch 100% đặt tại `res://assets_clean/` (chữ thường 100%, an toàn khi đóng gói `.pck` Web/Android) sau khi ghi vào `ASSETS.md`.
- **Lý do:** Đảm bảo 0% rủi ro dính tài nguyên thương mại ngay từ Cổng 1 và giữ tốc độ khởi động `godot --headless` cực nhanh.
- **Cách đổi:** Nếu sau này có bộ asset thương mại mua bản quyền hoặc tự vẽ mới, đặt vào `res://assets_clean/`, khai báo nguồn gốc trong `ASSETS.md` và cập nhật đường dẫn cấu hình trong `res://data/`.

## DEC-002 — Đồng bộ kiến trúc 16 Lớp Kết Xuất (15 lớp Bản đồ + 1 lớp HUD) và ngưỡng `StrategicZoom = 0.65`
- **Vấn đề:** `implementation_plan.md` tóm tắt ngắn gọn là "15 Render Layers" và `Zoom < 0.7x`, trong khi đặc tả chi tiết `docs/gdd/ui_ux/battle_ui_and_rendering.md` định nghĩa **16 lớp** (gồm **15 lớp `Node2D` không gian bản đồ** `z_index 0..70` cộng **1 lớp `ScreenHudCanvasLayer`** `layer = 10`) và hằng số mã mẫu `STRATEGIC_TOKEN_THRESHOLD = 0.65` (giữa `Default 1.0x` và `Strategic 0.5x`).
- **Lựa chọn:** Triển khai đúng đủ 15 lớp `Node2D` bản đồ + 1 lớp `CanvasLayer` HUD (tổng 16 lớp đúng tên trong `battle_ui_and_rendering.md`) và đặt mặc định `@export var strategic_token_threshold: float = 0.65`.
- **Lý do:** Thống nhất 100% cả số lượng lớp bản đồ (15) lẫn tổng lớp hiển thị (16), đồng thời khớp trực tiếp với mã tham chiếu GDD.
- **Cách đổi:** Chỉnh thuộc tính `@export var strategic_token_threshold` trên `BattleCameraController` sang `0.70` trong Inspector hoặc scene nếu muốn chuyển sang huy hiệu chiến lược sớm hơn.

## DEC-003 — Chuẩn hóa Điểm Di Chuyển (`MP`) số nguyên `int` theo `hex_grid_pathfinding.md`
- **Vấn đề:** Ví dụ mẫu trong `data_and_save_system.md` ghi `mobility: 4` cho Bộ binh, trong khi `hex_grid_pathfinding.md` chuẩn hóa toàn bộ bảng chi phí 9 loại địa hình theo số nguyên `int` (`ROAD_PORT = 1`, `PLAINS = 2`, `FOREST = 3/4`, `HILLS = 4/5`, `SWAMP = 4/6`) kèm biên độ `max_mp`: Bộ binh `6–8 MP`, Cung/Pháo `6 MP`, Kỵ binh `10–12 MP`, Thủy quân `8–10 MP` để thưởng `fond_terrain (-1 MP)` luôn nguyên vẹn mà không sinh số thực.
- **Lựa chọn:** Dùng thang `int` chuẩn của `hex_grid_pathfinding.md` cho toàn bộ `BattleMapState`, `HexGridNavigator` và `res://data/settings/troop_settings.json` (ví dụ Bộ binh Trường Giáo `mobility = 6`, Thủy quân Nhẹ `mobility = 8`, Kỵ binh `mobility = 10`).
- **Lý do:** Bảo toàn tính tất định số nguyên 100% giữa Desktop, WebAssembly và Android, đồng thời giữ đúng tỉ lệ quãng đường đi được mỗi lượt (`3–4 ô đồng bằng`).
- **Cách đổi:** Chỉnh bảng `BASE_TERRAIN_MP` trong `scripts/core/battle_map_state.gd` và giá trị `mobility` trong `data/settings/troop_settings.json`.

## DEC-004 — Quy đổi Tọa độ Màn hình `Pointy-topped Hex` chuẩn với bán kính ngoài `HEX_SIZE = 48.0 px`
- **Vấn đề:** GDD quy định lưới `Pointy-topped Axial (q, r)` và khung nhìn mặc định hiển thị rõ khoảng `10–12 hex` trên độ phân giải gốc `1280×720`, nhưng chưa khóa cứng hằng số pixel `hex_size` (bán kính từ tâm đến đỉnh nhọn).
- **Lựa chọn:** Chọn `DEFAULT_HEX_SIZE = 48.0` pixel (chiều rộng ô `sqrt(3) * 48 ≈ 83.14 px`, bước hàng dọc `1.5 * 48 = 72.0 px` -> bản đồ `12×10` vừa khít `~1040×744 px` ở `Zoom 1.0x`), đồng thời cho phép truyền `hex_size` tùy chỉnh vào các hàm toán học `HexMath`.
- **Lý do:** Khớp hoàn hảo với viewport `1280×720` Map-First (`>= 80%` diện tích màn hình) và công thức lượng giác chuẩn Red Blob Games cho Pointy-topped Axial.
- **Cách đổi:** Thay đổi hằng số `DEFAULT_HEX_SIZE` trong `scripts/core/hex_math.gd` hoặc thuộc tính `@export var hex_size: float` trên `BattleMapView`.

## DEC-005 — Quy tắc Đi Xuyên Đồng Minh và Hiển thị Vùng Tầm Bắn Đỏ (`AttackableAreaLayer`)
- **Vấn đề:** (1) GDD quy định không đi xuyên qua ô địch chiếm đóng nhưng chưa nêu tường minh đơn vị có được đi xuyên qua ô đồng minh hay không; (2) cần chốt công thức tập ô đỏ `AttackableAreaLayer` khi chọn đơn vị ở `CP1`.
- **Lựa chọn:** (1) Đơn vị được đi **xuyên qua** ô đồng minh nếu còn đủ MP bước tiếp sang ô trống hợp lệ, nhưng **không được dừng kết thúc di chuyển** đè lên ô đang có đồng minh khác (trừ chính ô xuất phát của mình). (2) `HexGridNavigator.get_attackable_hexes(map_state, unit, origin_hex)` trả về mọi ô hợp lệ trong `[min_range, max_range]` thỏa `has_line_of_sight(map_state, origin_hex, target_hex)`; đồng thời cung cấp `get_engageable_enemy_hexes(map_state, unit, reachable)` cho các ô địch có thể công kích sau khi di chuyển.
- **Lý do:** Đúng chuẩn wargame lục giác (*Panzer Corps 2* / *EW7*), tránh kẹt đội hình ở hẻm hẹp/cầu bến nhưng vẫn đảm bảo 1 ô chỉ chứa tối đa 1 đạo quân (`TroopStack` đã gộp sẵn trong `BattleUnit`).
- **Cách đổi:** Nếu muốn cấm đi xuyên đồng minh, đổi điều kiện kiểm tra `occupant != null` trong `HexGridNavigator.get_hex_step_cost`.

## DEC-006 — Đồng bộ Schema Chỉ số Chiến đấu trong `troop_settings.json` với `CombatResolver`
- **Vấn đề:** `data_and_save_system.md` dùng các khóa `"min_attack"`, `"max_attack"`, `"defence"` và chuỗi `"attack_mode"` / `"defense_mode"`, trong khi `combat_formulas.md` định nghĩa công thức trên `base_atk`, `damage_roll_min..max` (`80..100`), `base_def` và mã số ma trận `AttackMode (1..6) × DefenseMode (1..5)`.
- **Lựa chọn:** `BattleUnit.from_troop_dict` nạp tương thích cả hai: ưu tiên `base_atk` (fallback sang `max_attack`), mặc định `damage_roll_min = 80`, `damage_roll_max = 100` (trừ khi JSON khai báo tường minh), `base_def` (fallback sang `defence`), và ánh xạ cả tên chuỗi lẫn số nguyên sang `AttackMode (1..6)` và `DefenseMode (1..5)` theo `units_commanders.md` §7.2.
- **Lý do:** Giữ tương thích 100% với tệp `troop_settings.json` của Cổng 1 và khớp chính xác công thức `combat_formulas.md`.
- **Cách đổi:** Ghi trực tiếp các trường số `base_atk`, `damage_roll_min`, `damage_roll_max`, `attack_mode`, `defense_mode` trong `data/settings/troop_settings.json`.

## DEC-007 — Quy ước Đánh số `current_round` trong Vòng lặp Chiến trường 7 Pha
- **Vấn đề:** Biểu đồ `data_and_save_system.md` tăng `current_round (+1)` ở Pha 1 `OnBeginRound`, còn bảng `core_loop.md` ghi tăng ở Pha 7 `OnEndRound`.
- **Lựa chọn:** Khởi tạo `current_round = 0` trước trận; mỗi lần bước vào Pha 1 `OnBeginRound`, tăng `current_round += 1` (Vòng đầu tiên là `1`, đầu Vòng 4 là `4`), và kiểm tra giới hạn `current_round >= max_rounds` tại Pha 7 `OnEndRound`.
- **Lý do:** Đảm bảo suốt Vòng 1 hiển thị `VÒNG 1/10` và sự kiện đầu Vòng 4 (`MapPhase_TideFall`) nhận đúng `current_round == 4`.
- **Cách đổi:** Điều chỉnh hàm `_begin_next_round()` trong `scripts/core/battle_game_controller.gd`.

## DEC-008 — Hệ Tọa Độ Trong JSON Kịch Bản (`coordinate_space: "odd_r"`)
- **Vấn đề:** Snippet `scenario_scripting_and_events.md` dùng khóa `"q", "r"` nhưng giá trị `{2, 8}`, `{5, 4}`, `{9, 2}` trên bản đồ `12×10` tương ứng tọa độ lưới chữ nhật Offset `odd-r (col, row)` (nếu hiểu là axial thô thì `(9, 8)` vượt biên cột `13 >= 12` và lệch với `SignalDock (2, 8)` trong `test_battle_map_state.gd` / `test_cp1_integration_and_perf.gd`).
- **Lựa chọn:** Khai báo `"coordinate_space": "odd_r"` và dùng `{"col": c, "row": r}` trong `data/battles/battle_10101.json`. `ScenarioLoader.parse_hex(dict, coord_space)` hỗ trợ cả hai: nếu có `"col"`/`"row"` hoặc `coord_space == "odd_r"` thì quy đổi qua `HexMath.odd_r_to_axial(Vector2i(col, row))`, còn nếu `coord_space == "axial"` với `"q"`/`"r"` thì dùng trực tiếp `Vector2i(q, r)`.
- **Lý do:** Giữ nhất quán tuyệt đối `SignalDock (2, 8)` = góc Tây Nam và `area_bai_coc (5..7, 4..5)` = giữa lòng sông với Cổng 1 & Cổng 2.
- **Cách đổi:** Đổi `"coordinate_space"` sang `"axial"` trong file JSON kịch bản nếu tác giả màn chơi muốn nhập trực tiếp tọa độ Axial.

## DEC-009 — Đồng Bộ Mã Phe (`faction_id`) & Đội (`team_id`) Theo Dữ Liệu Kịch Bản
- **Vấn đề:** `BattleMapState` mặc định `_faction_teams = {1: 1, 2: 1, 3: 2, 4: 0}` (phe 2 là Đồng minh, phe 3 là Địch), trong khi `battle_10101.json` định nghĩa phe `1 = Đại Việt` và phe `2 = Đại Nguyên (Quân Nguyên)`.
- **Lựa chọn:** Giữ nguyên mặc định `_faction_teams` của `BattleMapState` để bảo toàn 36 test C1/C2; khi `ScenarioLoader` nạp mục `"factions"` từ JSON, gọi `map_state.set_faction_team(id, team_id)` (`team_id = 1` cho `is_player == true`, `team_id = 2` cho phe địch). Cập nhật `BattleMapView._faction_primary_color` và `_faction_trim_color` dựa trên `is_hostile(player_faction_id, faction_id)` thay vì so sánh cứng `faction_id == 3`.
- **Lý do:** Hỗ trợ linh hoạt mọi cấu hình phe trong JSON mà không làm vỡ test cũ.
- **Cách đổi:** Sửa thuộc tính `team_id` trong danh sách `"factions"` của tệp JSON màn chơi.

## DEC-010 — Mở Rộng Roster Binh Chủng Thủy Chiến Sạch Cho Slice-01
- **Vấn đề:** `data/settings/troop_settings.json` hiện có 6 ID (`40101..40104`, `40201`, `40901`), chưa có Thuyền Hỏa Công và Soái Hạm Lâu Thuyền cho Ô Mã Nhi.
- **Lựa chọn:** Giữ nguyên toàn bộ 6 ID cũ và bổ sung `40202` (*Thuyền Hỏa Công Đại Việt*, `NavalLight`, `attack_mode: "Fire" (6)`, tầm `1–2`) và `40902` (*Soái Hạm Lâu Thuyền Đại Nguyên*, `NavalHeavy`, `strength: 240`, `base_atk: 46`, `base_def: 18`, tầm `1–2`) vào `data/settings/troop_settings.json`.
- **Lý do:** Bảo toàn 100% tương thích ngược với test C1/C2 đồng thời tái hiện đúng hỏa công & soái hạm Bạch Đằng 1288.
- **Cách đổi:** Chỉnh thông số hoặc thêm/bớt phần tử trong `data/settings/troop_settings.json`.

## DEC-011 — Tách RNG Nhiễu Quyết Định AI Khỏi RNG Mô Phỏng Chiến Đấu (`BattleContext.rng`)
- **Vấn đề:** Khi `AIDecisionMatrix.execute_faction_turn` dùng trực tiếp `controller.context.rng` cho nhiễu cộng tính ở Pha 3 (`plan_unit_turn`), quá trình phát lại chuỗi lệnh `replay_from_dict` (vốn chỉ chạy lại các lệnh đã xuất ra chứ không chạy lại bộ lập kế hoạch AI) bị lệch trạng thái RNG ngay ở đòn đánh đầu tiên và làm gãy phát lại AI-vs-AI.
- **Lựa chọn:** Giữ `plan_unit_turn(..., rng)` nhận bất kỳ `SeededRng` nào cho unit test, nhưng trong `AIDecisionMatrix.execute_faction_turn`, tạo `decision_rng := SeededRng.new(initial_seed ^ (current_round * 100003) ^ (faction_id * 1009) ^ (uid * 97))` hoàn toàn tách biệt khỏi `controller.context.rng`.
- **Lý do:** Bảo toàn tuyệt đối 100% tính tất định cho cả hai chiều: cùng seed thì AI ra quyết định giống hệt nhau, và khi phát lại JSON Replay chỉ chứa `BattleCommands`, `BattleContext.rng.get_state()`, HP và tọa độ khớp 100%.
- **Cách đổi:** Điều chỉnh công thức băm `turn_seed` hoặc truyền RNG AI chuyên biệt trong `scripts/ai/ai_decision_matrix.gd`.

## DEC-012 — Đồng Bộ Các Trạng Thái Thực Thi (`MOVING`, `ATTACKING`, `EXECUTE_SKILL`) trong `BattleInputFSM`
- **Vấn đề:** `BattleGameController.submit_command()` thực thi đồng bộ trong `scripts/core/`, trong khi `BattleInputFSM` định nghĩa đủ 8 trạng thái khép kín gồm `MOVING`, `ATTACKING` và `EXECUTE_SKILL` (dùng cho tween/hit-stop ở `C4-T3`).
- **Lựa chọn:** `BattleInputFSM` luôn chuyển qua trạng thái thực thi tương ứng (phát `state_changed`) trước khi gọi `submit_command()`, kèm cờ `@export var auto_complete_execution: bool = true` mặc định ở `C4-T1` để chuyển tiếp ngay sang `POST_MOVE_ACTION` hoặc `IDLE` (và hỗ trợ tắt sang `false` ở `C4-T3` để gọi `complete_execution()` sau tween). Nếu bước đi làm đơn vị tử trận (ví dụ `STAKED_WATER`) hoặc kết thúc trận, `MOVING` đi thẳng về `IDLE`.
- **Lý do:** Đảm bảo đồ thị 8 trạng thái quan sát được 100% qua tín hiệu `state_changed` đồng thời giữ kiểm thử headless tất định không phụ thuộc timer.
- **Cách đổi:** Đặt `auto_complete_execution = false` trên `BattleInputFSM` và nối callback hoàn tất hoạt ảnh vào `complete_execution()`.

## DEC-013 — Quy Tắc Khép Kín `PostMoveAction`, Tầm Ngắm 2 Bước & `CastSkillCommand (10001)` Trong `BattleInputFSM`
- **Vấn đề:** (1) `UnitCombatState` chưa có cờ `has_moved` nên cần chốt luật rời `POST_MOVE_ACTION` và thao tác chuột phải; (2) cần phân biệt chọn mục tiêu tại chỗ với sau di chuyển; (3) `CastSkillCommand (10001)` dùng `skill_cooldown` trên tướng (`general_id > 0`) chứ chưa dùng `Mana` ở `C4-T1`.
- **Lựa chọn:** (1) `POST_MOVE_ACTION` từ chối click ô trống khác / chọn quân khác (`action_rejected`), hỗ trợ 4 nhánh khép kín: chạm địch trong tầm mới -> `AIMING_TARGET`, `[MƯU LƯỢC]` -> `SKILL_TARGETING`, `[HOÀN TÁC]` / chuột phải sạch (`<= 6px`) nếu `controller.can_undo()` -> `UNIT_SELECTED`, và `[ĐỢI]` / chạm lại chính ô đang đứng -> `WaitCommand` (`IDLE`, `Dimmed`). (2) Ở `UNIT_SELECTED`, chỉ địch trong `get_attackable_hexes(..., unit.hex_position)` mới vào `AIMING_TARGET`; chạm lần 2 cùng địch hoặc `[ĐÁNH]` mới thực thi `AttackCommand`, còn chạm địch khác trong tầm sẽ đổi mục tiêu ngắm. (3) `enter_skill_targeting()` mở cho đơn vị có `general_id > 0`, `!has_acted`, `can_use_skill()`, tô `SkillAreaLayer (z=16)` tầm `2` (hover hiện AoE `1`) và gọi `CastSkillCommand(..., 10001, target_hex)`.
- **Lý do:** Khớp hoàn toàn sơ đồ 8 trạng thái GDD v3.4.1, tránh rò rỉ hành động kép hoặc lách ZoC, và tách bạch rành mạch `CastSkill` (cooldown tướng) với `ApplyTactic` (Mana phe ở `C5-T1`).
- **Cách đổi:** Mở rộng bảng kỹ năng từ `tactic_settings.json` hoặc gắn kiểm tra `Mana` trong `BattleInputFSM.enter_skill_targeting()` ở `C5-T1`.

## DEC-014 — Ngưỡng Kéo Camera `DRAG_THRESHOLD_PX = 6.0` Tách Pan Khỏi Chuột Phải Hủy / Click Trái
- **Vấn đề:** `BattleCameraController` và `BattleSandboxCP1` trước đây cùng bắt sự kiện `MOUSE_BUTTON_RIGHT` khi nhấn xuống, khiến thao tác giữ chuột phải kéo bản đồ lập tức xóa vùng chọn đơn vị.
- **Lựa chọn:** `BattleCameraController` ghi nhận vị trí nhấn với `MOUSE_BUTTON_LEFT`, `MOUSE_BUTTON_RIGHT` và `MOUSE_BUTTON_MIDDLE`, chỉ kích hoạt `_is_mouse_dragging` và pan khi con trỏ dịch chuyển `> 6.0` pixel. Khi thả chuột, nếu đã kéo `> 6.0` pixel thì tiêu thụ sự kiện (`set_input_as_handled()`); nếu chuột phải thả trong `<= 6.0` pixel thì không pan và phát tín hiệu `clean_right_clicked` cho `BattleInputFSM.cancel_or_deselect()`; chuột trái `<= 6.0` pixel xử lý ở sự kiện thả trong `BattleSandboxCP1`.
- **Lý do:** Đạt đúng hợp đồng UX giữa thao tác kéo bản đồ mượt mà và thao tác hủy/chọn trên cả chuột máy tính lẫn trackpad.
- **Cách đổi:** Chỉnh hằng số `DRAG_THRESHOLD_PX` trong `scripts/presentation/battle_camera_controller.gd`.

## DEC-015 — Kiến Trúc `BattleHudController` Map-First (`>= 80%` Bản Đồ), `CombatPreviewBox` Kẹp Biên & Chẩn Đoán 4 Nguyên Nhân Thất Bại
- **Vấn đề:** (1) `PanelContainer` tự động nới rộng `size` theo tổng `custom_minimum_size` của các nhãn con ở độ phân giải nhỏ (`960×540`), làm thu hẹp tỷ lệ diện tích bản đồ xuống dưới `80%`; (2) cần hiển thị cụ thể nguyên nhân thất bại trong 4 điều kiện (`LoseKeyArea`, `GeneralDefeated`, `AllUnitsEliminated`, `MaxRoundsUnfulfilled`) trên `ResultSummaryModal`.
- **Lựa chọn:** (1) Dùng `Panel` cố định chiều cao `TOP_BAR_HEIGHT = 40.0 px` và `BOTTOM_DOCK_HEIGHT = 56.0 px` với `clip_contents = true` và đặt `custom_minimum_size = Vector2(0.0, height)` trước khi gán `size = Vector2(vp.x, height)`, giữ tỷ lệ bản đồ thông suốt `82.2%–86.7%` (`>= 80%`) trên cả `16:9` (`1280×720`, `960×540`) lẫn `19.5:9` (`1560×720`) và `20:9` (`1600×720`). (2) `CombatPreviewBox` (`396×152 px`) kẹp tọa độ trong viewport và truyền sát thương dự kiến sang `BattleMapView.set_projected_target_damage()` để vẽ đoạn máu mất nhấp nháy trên thanh HP chia vạch `100 HP`. (3) `BattleHudController._diagnose_defeat_cause()` đối chiếu trực tiếp `ScenarioVictoryEvaluator.defeat_conditions` để báo rõ nguyên nhân thất bại kèm `CombatLogPanel`.
- **Lý do:** Đảm bảo giao diện Map-First không bị tràn biên ở mọi tỷ lệ khung hình Web/Android và cung cấp phản hồi chiến thuật minh bạch 100%.
- **Cách đổi:** Điều chỉnh hằng số `TOP_BAR_HEIGHT`, `BOTTOM_DOCK_HEIGHT`, `PREVIEW_BOX_SIZE` trong `scripts/presentation/battle_hud_controller.gd`.

## DEC-016 — Local Hit-Stop (`Engine.time_scale = 1.0`), `PooledParticleCPU2D.amount_ratio` & Lưu Trữ 2 Tầng (`BattleSaveManager`)
- **Vấn đề:** (1) Đóng băng `Engine.time_scale = 0.0` khi Hit-stop sẽ làm nghẽn toàn bộ tween HUD và timer camera; (2) `CPUParticles2D` gốc trên `gl_compatibility` không có thuộc tính `amount_ratio` của `GPUParticles2D` nhưng hệ thống cài đặt VFX Quality (`Low = 0.4`, `Medium = 0.75`, `High = 1.0`) cần điều chỉnh mật độ hạt trực tiếp; (3) lưu JSON 64-bit seed có nguy cơ mất độ chính xác số thực IEEE-754.
- **Lựa chọn:** (1) `CombatJuiceHelper.play_local_hit_stop()` chỉ gán `speed_scale = 0.0` cục bộ trên các node hoạt ảnh tham gia va chạm và khôi phục bằng `get_tree().create_timer(..., true, false, true)` với `instance_from_id()`, giữ `Engine.time_scale = 1.0` mọi lúc. (2) Tạo lớp con `PooledParticleCPU2D extends CPUParticles2D` có setter `amount_ratio` tự động quy đổi `amount = maxi(1, round(16 * amount_ratio))` trên hồ `16` node ở `MapEffectLayer (z=42)` kèm khóa niên đại chặn `GunpowderSmokeCPU2D` ở thời Trần 1288. (3) `BattleSaveManager` (`RefCounted` độc lập `SceneTree` trong `scripts/core/`) tuần tự hóa `rng_seed` và `rng_state` dạng `String`, chỉ tự động lưu `user://saves/battle_session.json` ở ranh giới kết thúc lượt (`EndTurn`), và tạo bản sao lưu `.bak` trước khi ghi đè `user://saves/player_profile.json`.
- **Lý do:** Giữ 60 FPS ổn định trên `gl_compatibility` (Web/Android), tuân thủ WCAG 2.3.1 (`< 3 lần chớp/giây` khi bật `Reduce Flashing`), và đảm bảo khôi phục trận đánh bit-identical 100%.
- **Cách đổi:** Chỉnh `POOL_SIZE` trong `scripts/presentation/combat_juice_helper.gd` hoặc cấu hình bus trong `scripts/presentation/battle_audio_manager.gd`.
