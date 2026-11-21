# Nhật Ký Quyết Định Kỹ Thuật & Thiết Kế (`DECISIONS.md`)

Ghi lại toàn bộ các lựa chọn tự chủ khi gặp điểm mơ hồ hoặc cần đồng bộ chi tiết giữa các module GDD v3.4.1.

---

## DEC-001 — Cô lập thư mục `Assets/` cũ và chuẩn hóa nguồn tài nguyên sạch 100%
- **Vấn đề:** Trên ổ đĩa có sẵn thư mục `Assets/` (~2.464 file placeholder R&D) được nhắc trong tài liệu cũ, nhưng quy chế dự án cấm tuyệt đối nội dung thương mại và yêu cầu mọi tài nguyên phải khai báo trong `ASSETS.md`.
- **Lựa chọn:** Đưa `/Assets/` vào `.gitignore` và đặt `Assets/.gdignore` để Godot bỏ qua hoàn toàn thư mục cũ; chỉ dùng vẽ hình học procedural (`CanvasItem._draw()`), shader `.gdshader` tự viết hoặc tài nguyên đồ họa tạo mới sạch 100% đặt tại `res://assets_clean/` (chữ thường 100%, an toàn khi đóng gói `.pck` Web/Android) sau khi ghi vào `ASSETS.md`.
- **Lý do:** Đảm bảo 0% rủi ro dính tài nguyên thương mại ngay từ Cổng 1 và giữ tốc độ khởi động `godot --headless` cực nhanh.
- **Cách đổi:** Nếu sau này có bộ asset thương mại mua bản quyền hoặc tự vẽ mới, đặt vào `res://assets_clean/`, khai báo nguồn gốc trong `ASSETS.md` và cập nhật đường dẫn cấu hình trong `res://data/`.

## DEC-002 — [SUPERSEDED BY DEC-024] Đồng bộ kiến trúc 16 Lớp Kết Xuất (15 lớp Bản đồ + 1 lớp HUD) và ngưỡng `StrategicZoom = 0.65`
- **Vấn đề:** `implementation_plan.md` tóm tắt ngắn gọn là "15 Render Layers" và `Zoom < 0.7x`, trong khi đặc tả chi tiết `docs/gdd/ui_ux/battle_ui_and_rendering.md` định nghĩa **16 lớp** (gồm **15 lớp `Node2D` không gian bản đồ** `z_index 0..70` cộng **1 lớp `ScreenHudCanvasLayer`** `layer = 10`) và hằng số mã mẫu `STRATEGIC_TOKEN_THRESHOLD = 0.65` (giữa `Default 1.0x` và `Strategic 0.5x`).
- **Lựa chọn:** Triển khai đúng đủ 15 lớp `Node2D` bản đồ + 1 lớp `CanvasLayer` HUD (tổng 16 lớp đúng tên trong `battle_ui_and_rendering.md`) và đặt mặc định `@export var strategic_token_threshold: float = 0.65`.
- **Lý do:** Thống nhất 100% cả số lượng lớp bản đồ (15) lẫn tổng lớp hiển thị (16), đồng thời khớp trực tiếp với mã tham chiếu GDD.
- **Cách đổi:** Chỉnh thuộc tính `@export var strategic_token_threshold` trên `BattleCameraController` sang `0.70` trong Inspector hoặc scene nếu muốn chuyển sang huy hiệu chiến lược sớm hơn.

## DEC-003 — Chuẩn hóa Điểm Di Chuyển (`MP`) số nguyên `int` theo `hex_grid_pathfinding.md`
- **Vấn đề:** Ví dụ mẫu trong `data_and_save_system.md` ghi `mobility: 4` cho Bộ binh, trong khi `hex_grid_pathfinding.md` chuẩn hóa toàn bộ bảng chi phí 9 loại địa hình theo số nguyên `int` (`ROAD_PORT = 1`, `PLAINS = 2`, `FOREST = 3/4`, `HILLS = 4/5`, `SWAMP = 4/6`) kèm biên độ `max_mp`: Bộ binh `6–8 MP`, Cung/Pháo `6 MP`, Kỵ binh `10–12 MP`, Thủy quân `8–10 MP` để thưởng `fond_terrain (-1 MP)` luôn nguyên vẹn mà không sinh số thực.
- **Lựa chọn:** Dùng thang `int` chuẩn của `hex_grid_pathfinding.md` cho toàn bộ `BattleMapState`, `HexGridNavigator` và `res://data/settings/troop_settings.json` (ví dụ Bộ binh Trường Giáo `mobility = 6`, Thủy quân Nhẹ `mobility = 8`, Kỵ binh `mobility = 10`).
- **Lý do:** Bảo toàn tính tất định số nguyên 100% giữa Desktop, WebAssembly và Android, đồng thời giữ đúng tỉ lệ quãng đường đi được mỗi lượt (`3–4 ô đồng bằng`).
- **Cách đổi:** Chỉnh bảng `BASE_TERRAIN_MP` trong `scripts/core/battle_map_state.gd` và giá trị `mobility` trong `data/settings/troop_settings.json`.

## DEC-004 — [SUPERSEDED BY DEC-024] Quy đổi Tọa độ Màn hình `Pointy-topped Hex` chuẩn với bán kính ngoài `HEX_SIZE = 48.0 px`
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

## DEC-010 — [SUPERSEDED BY DEC-023] Mở Rộng Roster Binh Chủng Thủy Chiến Sạch Cho Slice-01
- **Vấn đề:** `data/settings/troop_settings.json` hiện có 6 ID (`40101..40104`, `40201`, `40901`), chưa có Thuyền Hỏa Công và Soái Hạm Lâu Thuyền cho Ô Mã Nhi.
- **Lựa chọn:** Giữ nguyên toàn bộ 6 ID cũ và bổ sung `40202` (*Thuyền Hỏa Công Đại Việt*, `NavalLight`, `attack_mode: "Fire" (6)`, tầm `1–2`) và `40902` (*Soái Hạm Lâu Thuyền Đại Nguyên*, `NavalHeavy`, `strength: 240`, `base_atk: 46`, `base_def: 18`, tầm `1–2`) vào `data/settings/troop_settings.json`.
- **Lý do:** Bảo toàn 100% tương thích ngược với test C1/C2 đồng thời tái hiện đúng hỏa công & soái hạm Bạch Đằng 1288.
- **Cách đổi:** Chỉnh thông số hoặc thêm/bớt phần tử trong `data/settings/troop_settings.json`.

## DEC-011 — Tách RNG Nhiễu Quyết Định AI Khỏi RNG Mô Phỏng Chiến Đấu (`BattleContext.rng`)
- **Vấn đề:** Khi `AIDecisionMatrix.execute_faction_turn` dùng trực tiếp `controller.context.rng` cho nhiễu cộng tính ở Pha 3 (`plan_unit_turn`), quá trình phát lại chuỗi lệnh `replay_from_dict` (vốn chỉ chạy lại các lệnh đã xuất ra chứ không chạy lại bộ lập kế hoạch AI) bị lệch trạng thái RNG ngay ở đòn đánh đầu tiên và làm gãy phát lại AI-vs-AI.
- **Lựa chọn:** Giữ `plan_unit_turn(..., rng)` nhận bất kỳ `SeededRng` nào cho unit test, nhưng trong `AIDecisionMatrix.execute_faction_turn`, tạo `decision_rng := SeededRng.new(initial_seed ^ (current_round * 100003) ^ (faction_id * 1009) ^ (uid * 97))` hoàn toàn tách biệt khỏi `controller.context.rng`.
- **Lý do:** Bảo toàn tuyệt đối 100% tính tất định cho cả hai chiều: cùng seed thì AI ra quyết định giống hệt nhau, và khi phát lại JSON Replay chỉ chứa `BattleCommands`, `BattleContext.rng.get_state()`, HP và tọa độ khớp 100%.
- **Cách đổi:** Điều chỉnh công thức băm `turn_seed` hoặc truyền RNG AI chuyên biệt trong `scripts/ai/ai_decision_matrix.gd`.

## DEC-012 — [SUPERSEDED BY DEC-026] Đồng Bộ Các Trạng Thái Thực Thi (`MOVING`, `ATTACKING`, `EXECUTE_SKILL`) trong `BattleInputFSM`
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

## DEC-015 — [SUPERSEDED BY DEC-024 & DEC-026] Kiến Trúc `BattleHudController` Map-First (`>= 80%` Bản Đồ), `CombatPreviewBox` Kẹp Biên & Chẩn Đoán 4 Nguyên Nhân Thất Bại
- **Vấn đề:** (1) `PanelContainer` tự động nới rộng `size` theo tổng `custom_minimum_size` của các nhãn con ở độ phân giải nhỏ (`960×540`), làm thu hẹp tỷ lệ diện tích bản đồ xuống dưới `80%`; (2) cần hiển thị cụ thể nguyên nhân thất bại trong 4 điều kiện (`LoseKeyArea`, `GeneralDefeated`, `AllUnitsEliminated`, `MaxRoundsUnfulfilled`) trên `ResultSummaryModal`.
- **Lựa chọn:** (1) Dùng `Panel` cố định chiều cao `TOP_BAR_HEIGHT = 40.0 px` và `BOTTOM_DOCK_HEIGHT = 56.0 px` với `clip_contents = true` và đặt `custom_minimum_size = Vector2(0.0, height)` trước khi gán `size = Vector2(vp.x, height)`, giữ tỷ lệ bản đồ thông suốt `82.2%–86.7%` (`>= 80%`) trên cả `16:9` (`1280×720`, `960×540`) lẫn `19.5:9` (`1560×720`) và `20:9` (`1600×720`). (2) `CombatPreviewBox` (`396×152 px`) kẹp tọa độ trong viewport và truyền sát thương dự kiến sang `BattleMapView.set_projected_target_damage()` để vẽ đoạn máu mất nhấp nháy trên thanh HP chia vạch `100 HP`. (3) `BattleHudController._diagnose_defeat_cause()` đối chiếu trực tiếp `ScenarioVictoryEvaluator.defeat_conditions` để báo rõ nguyên nhân thất bại kèm `CombatLogPanel`.
- **Lý do:** Đảm bảo giao diện Map-First không bị tràn biên ở mọi tỷ lệ khung hình Web/Android và cung cấp phản hồi chiến thuật minh bạch 100%.
- **Cách đổi:** Điều chỉnh hằng số `TOP_BAR_HEIGHT`, `BOTTOM_DOCK_HEIGHT`, `PREVIEW_BOX_SIZE` trong `scripts/presentation/battle_hud_controller.gd`.

## DEC-016 — Local Hit-Stop (`Engine.time_scale = 1.0`), `PooledParticleCPU2D.amount_ratio` & Lưu Trữ 2 Tầng (`BattleSaveManager`)
- **Vấn đề:** (1) Đóng băng `Engine.time_scale = 0.0` khi Hit-stop sẽ làm nghẽn toàn bộ tween HUD và timer camera; (2) `CPUParticles2D` gốc trên `gl_compatibility` không có thuộc tính `amount_ratio` của `GPUParticles2D` nhưng hệ thống cài đặt VFX Quality (`Low = 0.4`, `Medium = 0.75`, `High = 1.0`) cần điều chỉnh mật độ hạt trực tiếp; (3) lưu JSON 64-bit seed có nguy cơ mất độ chính xác số thực IEEE-754.
- **Lựa chọn:** (1) `CombatJuiceHelper.play_local_hit_stop()` chỉ gán `speed_scale = 0.0` cục bộ trên các node hoạt ảnh tham gia va chạm và khôi phục bằng `get_tree().create_timer(..., true, false, true)` với `instance_from_id()`, giữ `Engine.time_scale = 1.0` mọi lúc. (2) Tạo lớp con `PooledParticleCPU2D extends CPUParticles2D` có setter `amount_ratio` tự động quy đổi `amount = maxi(1, round(16 * amount_ratio))` trên hồ `16` node ở `MapEffectLayer (z=42)` kèm khóa niên đại chặn `GunpowderSmokeCPU2D` ở thời Trần 1288. (3) `BattleSaveManager` (`RefCounted` độc lập `SceneTree` trong `scripts/core/`) tuần tự hóa `rng_seed` và `rng_state` dạng `String`, chỉ tự động lưu `user://saves/battle_session.json` ở ranh giới kết thúc lượt (`EndTurn`), và tạo bản sao lưu `.bak` trước khi ghi đè `user://saves/player_profile.json`.
- **Lý do:** Giữ 60 FPS ổn định trên `gl_compatibility` (Web/Android), tuân thủ WCAG 2.3.1 (`< 3 lần chớp/giây` khi bật `Reduce Flashing`), và đảm bảo khôi phục trận đánh bit-identical 100%.
- **Cách đổi:** Chỉnh `POOL_SIZE` trong `scripts/presentation/combat_juice_helper.gd` hoặc cấu hình bus trong `scripts/presentation/battle_audio_manager.gd`.

## DEC-017 — Module Kinh Tế Chiến Trường (`BattleEconomy`), Tiêu Hao `MealFood`, Luật `Starvation` & 7 Lệnh Kinh Tế Không Hoàn Tác
- **Vấn đề:** Cần cô lập tuyệt đối hệ thống kinh tế để màn chơi chiến thuật thuần (`stage_id: 10101`, `enable_economy = false`) không bị ảnh hưởng, đồng thời ở các màn hậu cần (`enable_economy = true`, như Vân Đồn) phải xử lý tất định 4 tài nguyên (`Coin`, `Food`, `Tech`, `Mana`), thu hoạch công trình, tiêu hao lương `MealFood`, phạt `Starvation` và 7 lệnh kinh tế.
- **Lựa chọn:** Triển khai `BattleEconomy` (`scripts/core/battle_economy.gd`, `RefCounted` độc lập `SceneTree`) và `data/settings/facility_settings.json`:
  1. Pha 1 `process_begin_round()` chỉ chạy khi `controller.enable_economy == true`: thu hoạch `Farm`/`Market`/`Mine`/`Temple`/`Academy` (kẹp trần `Food` theo `Granary` `1000 + 500 * level`), trừ `TotalMealFood = sum(base_meal * clampi(max_stack, 1, 3))` (`Infantry/Archer = 10`, `NavalLight = 15`, `Cavalry/NavalHeavy/Siege = 20`, `Elephant = 30`).
  2. Khi `food < 0` (`is_starving == true`; lưu ý `food == 0` không đói): hạ `-1` bậc sĩ khí chạm đáy tại `LOW` (không bao giờ tụt xuống `CHAOS`), nhân `0.75x` sát thương trong `CombatResolver` (hiển thị rõ nhãn `Đói lương (Starvation -25% / x0.75)` trên `CombatPreviewBox`), và khóa hồi máu (`can_heal_unit == false`).
  3. Cung cấp 7 lệnh tất định không hoàn tác (`can_undo() == false`): `RobAreaIncomeCommand` (tối đa 3 lượt tích lũy, giảm một nửa `0.50x` nếu có `Granary`, reset `turns_unrobbed = 0`), `TradeCommand` (bắt buộc có `Market`, tỷ giá thường `100 Coin -> 75 Food` và tỷ giá khẩn cấp khi đang đói `100 Coin -> 38 Food`, cấm bán lương lấy tiền khi đang đói), `UpgradeFacilityCommand`, `FortifyHexCommand`, `UnlockBattleTechCommand` (bắt buộc mở tuần tự Tier `1 -> 2 -> 3` và chặn thuốc súng ở thế kỷ XIII), `RecruitCommand`, và `ApplyTacticCommand` (tiêu hao `Mana` toàn phe, không khóa `has_acted` / `skill_cooldown` của đơn vị).
- **Lý do:** Khớp 100% công thức GDD v3.4.1 (`economy_resources.md`), bảo toàn Replay tất định và giữ thời gian suy nghĩ AI `< 3.0s/lượt`.
- **Cách đổi:** Chỉnh thông số công trình trong `data/settings/facility_settings.json` hoặc bảng `compute_unit_meal_food` trong `scripts/core/battle_economy.gd`.

## DEC-018 — Gói Chiến Dịch Thời Trần 6 Màn (`10101..10106`), Phân Tách Codex (`938/981/1288`) & Bộ Kiểm Định `AssetIpAuditor`
- **Vấn đề:** (1) Cần tổ chức 6 màn chiến dịch thời Trần liên kết chặt chẽ gồm cả màn chiến thuật thuần (`10101` Bạch Đằng 1288) và màn kinh tế hậu cần (`10105` Vân Đồn 1288) với khóa đội hình lịch sử ở lần chơi đầu; (2) trên hệ tệp NTFS Windows không phân biệt hoa/thường, hàm `FileAccess.file_exists()` không phát hiện lỗi viết hoa đường dẫn `res://` vốn sẽ gây lỗi `.pck` trên Web/Android.
- **Lựa chọn:**
  1. Biên soạn đủ 6 màn (`10101` Bạch Đằng 1288, `10102` Bình Than – Vạn Kiếp 1282, `10103` Hàm Tử 1285, `10104` Chương Dương 1285, `10105` Vân Đồn 1288 `enable_economy: true`, `10106` Nội Bàng 1288), 12 binh chủng sạch không thuốc súng (`troop_settings.json`), 9 danh tướng (`general_settings.json`), và 7 mục Bách khoa Sử ký (`codex_entries.json`) phân tách rõ Bạch Đằng `938` (Ngô Quyền), `981` (Lê Hoàn), `1288` (Trần Quốc Tuấn), tách hạng `A–D` khỏi nguồn tham chiếu cơ chế `[S1][S2][S8]` và không bao giờ gắn `historical_claim` cho tư liệu hạng `D`.
  2. Triển khai `CampaignMenuController` (`scenes/main_menu.tscn`), `TutorialOverlay` (lưu cờ `tutorial_flags` vào `player_profile.json`, chỉ hiện tip kinh tế khi `enable_economy == true`), và `CodexPanel` (`scenes/ui/codex_panel.tscn`).
  3. Triển khai `AssetIpAuditor` (`scripts/core/asset_ip_auditor.gd`) duyệt từng phân đoạn thư mục bằng `DirAccess.list_dir_begin()`/`get_next()` để kiểm tra khớp chính xác chữ hoa/thường 100% ngay trên Windows, kiểm tra đăng ký `ASSETS.md` và cô lập `scripts/core/` + `scripts/ai/`.
- **Lý do:** Đảm bảo 100% tính minh bạch lịch sử theo GDD v3.4.1 và chặn đứng mọi lỗi đường dẫn `.pck` hoặc rò rỉ tài nguyên trước khi xuất bản Web/Android.
- **Cách đổi:** Bổ sung màn chơi vào `data/settings/stage_settings.json` hoặc mục tư liệu vào `data/settings/codex_entries.json`.

## DEC-019 — Cấu Hình `export_presets.cfg` Cho Web (Single-Threaded Wasm) & Android (`arm64-v8a`, `gl_compatibility`)
- **Vấn đề:** Bản xuất Web (HTML5/Wasm) nếu bật đa luồng (`variant/thread_support = true`) sẽ yêu cầu máy chủ cấu hình header `Cross-Origin-Opener-Policy: same-origin` và `Cross-Origin-Embedder-Policy: require-corp` (`SharedArrayBuffer`), dễ gây lỗi màn hình trắng trên các dịch vụ lưu trữ tĩnh phổ thông (GitHub Pages, itch.io mặc định). Đồng thời cần chặn tuyệt đối thư mục tham khảo `Assets/` và bộ kiểm thử `tests/` khỏi gói `.pck` phát hành.
- **Lựa chọn:**
  1. Thiết lập `[preset.0]` (`name="Web"`, `platform="Web"`, `export_path="build/web/index.html"`) với `variant/thread_support=false`, `html/canvas_resize_policy=2` (Adaptive), `html/focus_canvas_on_start=true`, và `exclude_filter="Assets/*,tests/*,.ai/*,docs/*"`.
  2. Thiết lập `[preset.1]` (`name="Android"`, `platform="Android"`, `export_path="build/android/dai_viet_chien_ky.apk"`) với `package/unique_name="com.daiviet.chienky"`, `package/name="Đại Việt Chiến Kỳ"`, `architectures/arm64-v8a=true`, `screen/immersive_mode=true`, và cùng bộ lọc `exclude_filter="Assets/*,tests/*,.ai/*,docs/*"`.
  3. Giữ `rendering/renderer/rendering_method="gl_compatibility"` và `rendering/renderer/rendering_method.mobile="gl_compatibility"` thống nhất giữa Desktop, WebGL2 và Android GLES3.
- **Lý do:** Chạy trực tiếp trên mọi static host mà không cần COOP/COEP header, giữ dung lượng `.pck` tối giản sạch 100% bản quyền và đạt 60 FPS (`<= 16.67 ms/frame`) nhờ batching 2D + LOD `StrategicTokenLayer` + hồ hạt `CPUParticles2D`.
- **Cách đổi:** Chỉnh tùy chọn trong `export_presets.cfg` hoặc qua hộp thoại `Project -> Export` của Godot Editor sau khi cài đặt gói Export Templates `.tpz`.

## DEC-020 — Ngưỡng Cờ Hiển Thị (`active_banners`) Cho Đạo 3 Cờ & `PauseButton` Mở Modal Idempotent
- **Vấn đề:** (1) GDD (`mechanics/combat_formulas.md`) vừa nêu ngưỡng tường minh `3 / 2 / 1` cờ ứng với `> 66%`, `33%–66%`, `< 33%` `max_hp` cho đạo 3 cờ, vừa nêu công thức tổng quát `clampi(ceili(hp_ratio * max_stack), 1, max_stack)`; hai cách cho kết quả khác nhau tại biên (ví dụ `320/480 = 66.7%` → ngưỡng cho `3`, `ceili(2.0)` cho `2`). (2) `PauseButton` dùng `toggle_pause_modal`, nên nhấp đúp nhanh mở rồi đóng ngay modal.
- **Lựa chọn:** (1) `BattleUnit.get_active_banners()` dùng ngưỡng tường minh khi `s_max == 3`, giữ công thức `ceili` cho `s_max` 1–2. (2) `PauseButton.pressed` gọi `open_pause_modal()` (idempotent); đóng modal qua `[TIẾP TỤC]` hoặc phím `Esc` (vẫn dùng `toggle_pause_modal`).
- **Lý do:** Ngưỡng tường minh là quy tắc cụ thể hơn trong GDD và chỉ ảnh hưởng hiển thị (không đổi sát thương `M_hp`); modal tạm dừng không được tự đóng vì nhấp đúp.
- **Cách đổi:** Sửa nhánh `s_max == 3` trong `scripts/core/battle_unit.gd` hoặc nối lại `_pause_btn.pressed` trong `scripts/presentation/battle_hud_controller.gd`.

## DEC-021 — Chiến Lược Lộ Trình Tái Kiến Trúc: Làm Chuẩn Chỉnh Vertical Slice `10101` Trước Khi Nhân Rộng (`R1–R5`)
- **Vấn đề:** Sau khi kiểm thử trực quan đối chiếu với `D:\code\HexCrown`, phiên bản cũ tuy đạt `82/82` unit tests và `256/256` E2E tests nhưng lớp vỏ trải nghiệm không đạt chuẩn (View 2D trong Editor trống, dữ liệu JSON không chỉnh được trong Inspector, nút Briefing/Pause bị cắt do `clip_contents`, đồ họa chỉ là đa giác tô màu bệt). Nếu sửa dàn trải cả 6 màn cùng lúc sẽ kéo dài rủi ro kiến trúc.
- **Lựa chọn:** Tập trung tái kiến trúc và nâng cấp toàn diện **Vertical Slice (`10101` Bạch Đằng 1288)** đạt/vượt chất lượng `HexCrown` qua 4 cổng đầu (`R1 -> R2 -> R3 -> R4`), nghiệm thu thực tế trong Editor và chơi thử xong mới nhân rộng sang 5 màn Thời Trần còn lại (`10102–10106` ở Cổng `R5`).
- **Lý do:** Giảm thiểu rủi ro, chứng minh chuẩn kỹ thuật và mỹ thuật trên 1 màn đại diện trước khi nhân bản hàng loạt.
- **Cách đổi:** Điều chỉnh thứ tự ưu tiên trong `TASKS.md` và `docs/gdd/04_production_roadmap/implementation_plan.md`.

## DEC-022 — Định Hướng Đồ Họa & Cổng Dừng Bắt Buộc Hỏi Người Dùng Khi Tạo Asset (`R3` Kế Thừa `HexCrown`, `R4` So Sánh 2 Mẫu)
- **Vấn đề:** Cần nhanh chóng có đồ họa game thật (`TileSet`, công trình, sprite đơn vị có hoạt ảnh) cho Vertical Slice `10101` trong khi phong cách mỹ thuật cuối cùng của dự án vẫn chưa chốt cứng giữa Pixel Art và 2D Cách điệu.
- **Lựa chọn:**
  1. Ở Cổng `R3`, kế thừa tạm bộ Tileset lục giác, công trình Đỏ/Xanh, 12 sprite sheet lính `32×32`, shader (`FactionTint`, `pulse_highlight`, `territory_border`) và bộ SFX sạch từ `D:\code\HexCrown\assets` vào `res://assets_clean/` để khung game chạy và chỉnh được ngay trong Editor.
  2. Ở Cổng `R4` (**🛑 CỔNG DỪNG BẮT BUỘC HỎI NGƯỜI DÙNG**), dựng **2 mẫu nhỏ trên cùng cảnh Bạch Đằng**: **Mẫu A (Pixel Art** đồng bộ `HexCrown` kèm Chiến thuyền & Bãi cọc `StakedWater`) vs **Mẫu B (2D Cách điệu lịch sử kiểu EasyTech** thiết kế riêng) để người dùng so sánh trực quan và chọn phong cách chính thức, tiến tới thay thế dần asset của `HexCrown`.
  3. **Quy tắc cứng:** Khi đến bất kỳ bước thiết kế/tạo asset mới nào, agent **bắt buộc dừng lại hỏi người dùng** để người dùng lên phương án và chọn công cụ thiết kế; tuyệt đối không tự ý vẽ hay sinh asset.
- **Lý do:** Đảm bảo khung kỹ thuật và trải nghiệm chạy mượt ngay ở `R3`, đồng thời trao toàn quyền quyết định mỹ thuật và công cụ thiết kế cho người dùng ở `R4`.
- **Cách đổi:** Thực hiện tại Cổng `R4` theo quyết định trực tiếp của người dùng.

## DEC-023 — Chuyển Dữ Liệu Tĩnh Sang Custom `Resource` (`.tres`) & Biên Tập Màn Chơi 2 Chiều (`@tool`)
- **Vấn đề:** GDD v3.4.1 cũ quy định lưu toàn bộ danh mục thiết kế (`troop_settings.json`, `stage_settings.json`, `battle_10101.json`) bằng JSON đọc thành `Dictionary`, khiến designer không thể chỉnh thông số trực tiếp trong Godot Inspector hoặc xem trước màn chơi trên View 2D.
- **Lựa chọn:**
  1. Toàn bộ danh mục tĩnh (`TroopDef`, `GeneralDef`, `TacticDef`, `FacilityDef`, `CodexEntryDef`, `DataRegistry`) chuyển sang Custom `Resource` (`.tres`) có `@export` đầy đủ, chỉnh trong Godot Inspector.
  2. Mỗi màn chơi kết hợp **Scene Bản đồ (`stage_<id>_map.tscn`)** (vẽ địa hình trực tiếp trên `TileMapLayer` và kéo-thả điểm đặt quân / vùng đặc biệt trong View 2D nhờ script `@tool`) với **Resource Kịch bản (`stage_<id>.tres` — `StageDef`)** chứa các Sub-Resource (`ScenarioEventDef`, `DialogueLineDef`, `VictoryConditionDef`) chỉnh trong Inspector.
  3. Định dạng `.json` chỉ dùng duy nhất cho Save/Load runtime (`user://saves/battle_session.json`, `user://saves/player_profile.json` + `.bak`) và xuất/nhập Replay.
- **Lý do:** Đạt tiêu chuẩn Editor-First của Godot 4.7 tương tự `HexCrown` (`UnitResource` `.tres` + `level.tscn` `TileMapLayer`), đồng thời giữ an toàn tuyệt đối cho save game người dùng trên Web IndexedDB/Android.
- **Cách đổi:** Mở rộng thuộc tính `@export` trong các lớp `res://data/defs/*.gd` và chạy lại scene `@tool`.

## DEC-024 — Kiến Trúc 4 Tầng ("Lõi Thuần + Vỏ Dựng Trong Editor"), Xóa 3 Siêu File Presentation & Trần `<= 400 Dòng/Script`
- **Vấn đề:** Tầng trình diễn cũ phình to với 3 siêu file sinh node và vẽ hình học hoàn toàn bằng code (`battle_hud_controller.gd` 1.556 dòng, `battle_map_view.gd` 880 dòng, `battle_sandbox_cp1.gd` 806 dòng), khiến `battle_sandbox_cp1.tscn` chỉ có 1 node và HUD gặp lỗi cắt nút `clip_contents` + tự hit-test `_input()` sai lệch.
- **Lựa chọn:**
  1. Tổ chức cây thư mục 4 tầng chuẩn: `res://data/` (`.tres` + `.tscn`) -> `res://sim/` (`RefCounted` thuần độc lập `SceneTree`) -> `res://game/battle/battle_session.gd` (`Node` duy nhất giữ `BattleState`, nhận `Command`, phát `signal` có kiểu) -> `res://game/battle/` & `res://ui/` (`.tscn` + `theme.tres`), kèm `res://autoload/` chỉ chứa dịch vụ toàn cục không state trận đấu (`Settings`, `SaveService`, `Audio`, `SceneRouter`).
  2. Giới hạn cứng **mỗi script `<= 400` dòng**; phụ thuộc truyền có kiểu qua `@export var session: BattleSession` (cấm service locator kiểu `var grid: Node` không kiểu của `HexCrown` và cấm `get_node("/root/...")`).
  3. Xóa bỏ hoàn toàn 3 siêu file presentation cũ, thay bằng `battle.tscn`, `battle_map.tscn` (`TileMapLayer`), `unit_view.tscn` (ghép Component như `HexCrown`), và các scene HUD/Modal tách rời trong `ui/battle_hud/*.tscn` + `ui/common/theme.tres`.
- **Lý do:** Kết hợp điểm mạnh lõi tất định có unit test của dự án với trải nghiệm trực quan trong Godot Editor của `HexCrown`, loại bỏ lỗi UI tự chế bằng code.
- **Cách đổi:** Tuân thủ quy trình trong `.agents/skills/project-architecture/SKILL.md`.

## DEC-025 — Đánh Dấu Trạng Thái `CP1–CP5` Cũ & Mở Bộ Cổng Tái Kiến Trúc `R1–R5` (`CP6–CP10`)
- **Vấn đề:** `TASKS.md` và `STATE.md` đang đánh dấu `18/18` nhiệm vụ cũ (`CP1–CP5`) hoàn tất trong khi lớp vỏ UI/Data/Đồ họa thực tế không đạt chuẩn chơi thử.
- **Lựa chọn:** Ghi nhận trong `TASKS.md` và `STATE.md` rằng `CP1–CP5` cũ **chỉ đạt phần Lõi Mô phỏng (`Sim`)**, còn **phần UI/Data/Đồ họa cũ bị BÁC BỎ (`REJECTED`)**. Mở 5 Cổng mới **`R1–R5` (`CP6–CP10`)** với tiêu chí nghiệm thu bắt buộc kiểm thử `assert_button_reachable()` (qua `Viewport.push_input` thật, không bị cắt bởi `clip_contents`) và kiểm tra View 2D + Inspector trực tiếp trong Godot Editor.
- **Lý do:** Phản ánh trung thực chất lượng sản phẩm hiện tại và thiết lập tiêu chuẩn nghiệm thu không cho phép lỗi UI lọt cổng.
- **Cách đổi:** Theo dõi tiến độ từng nhiệm vụ trong `TASKS.md`.

## DEC-026 — Bỏ Triết Lý Biết Trước (`CombatPreviewBox` & `AimingTarget`), Dùng `UnitInspector` & Đánh Ngay 1 Chạm Như `HexCrown`
- **Vấn đề:** Cơ chế cũ hiển thị hộp `CombatPreviewBox` tính hộ sẵn khoảng sát thương `[Min, Max]` và phản kích trước khi ra đòn (kèm trạng thái nhắm 2 bước `AimingTarget`), làm mất đi tính phán đoán chiến thuật tự tính của người chơi và rườm rà thao tác so với `HexCrown`.
- **Lựa chọn:**
  1. **Loại bỏ hoàn toàn `CombatPreviewBox`** và không hiển thị bất kỳ con số sát thương dự kiến hay phản kích dự kiến nào trước khi giao tranh; xóa hàm `preview_combat()` khỏi luồng HUD người chơi (hàm ước lượng nội bộ cho AI trong `AIDecisionMatrix` vẫn giữ kín bên trong máy).
  2. Thay bằng **`UnitInspector` (`res://ui/battle_hud/unit_inspector.tscn`)**: chỉ hiển thị **thông số thô của từng đạo quân đang xem/chọn** (tên binh chủng/tướng, HP & số cờ hiện tại, Công `min~max` hoặc `base_atk`, Thủ, Tầm đi/đánh, Sĩ khí, và địa hình ô đang đứng). Người chơi tự đối chiếu thông số để tính toán; khi ra đòn, hệ thống tính công thức và tung số ngẫu nhiên (`Seeded RNG`) thực tế trên va chạm.
  3. **Rút gọn `BattleInputFSM` từ 8 xuống 7 trạng thái** (`IDLE`, `UNIT_SELECTED`, `MOVING`, `POST_MOVE_ACTION`, `ATTACKING`, `SKILL_TARGETING`, `EXECUTE_SKILL` — **bỏ `AIMING_TARGET`**): khi chưa chọn quân ta (hoặc click chuột phải / chạm vào địch ngoài tầm) thì `UnitInspector` hiện thông số đạo quân đó; khi đã chọn quân ta (`UNIT_SELECTED` hoặc `POST_MOVE_ACTION`) và ô địch sáng Đỏ trong tầm đánh, **click/chạm 1 lần vào địch là chuyển thẳng sang `ATTACKING` ra đòn ngay lập tức như `HexCrown`**.
- **Lý do:** Trả lại trải nghiệm wargame chiến thuật thuần túy (người chơi tự cân não với thông số và bất định `Seeded RNG`) cùng thao tác điều quân nhanh gọn, tự nhiên như `HexCrown`.
- **Cách đổi:** Điều chỉnh luồng chuyển trạng thái trong `BattleInputFSM` và scene `ui/battle_hud/unit_inspector.tscn`.