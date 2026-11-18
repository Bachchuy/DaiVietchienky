# 11. UI/UX và khả năng tiếp cận

[← Quay lại Mục lục GDD](../README.md)

---

## 11.1. Nguyên tắc giao diện

- **Map-first:** Bản đồ chiến trường là trung tâm (chiếm tối thiểu 80% diện tích hiển thị); HUD gọn sạch, không che khuất vùng tác chiến.
- **Explainable:** Mọi modifier chiến đấu, LOS, ZOC, hiệu ứng địa hình và tiến độ mục tiêu đều được giải thích minh bạch.
- **Progressive disclosure:** Thông tin cốt lõi đọc lướt được ngay; chi tiết công thức mở rộng theo yêu cầu người chơi.
- **Consistent controls:** Thao tác chạm (Android) và chuột/phím (Web/PC) tuân thủ chung một máy trạng thái đầu vào (`BattleInputFSM`).
- **Accessible:** Không phụ thuộc duy nhất vào màu sắc; luôn đi kèm biểu tượng hình học, độ tương phản cao, thanh trượt giảm rung camera (0–100%) và chế độ giảm chớp sáng.

---

## 11.2. Camera và điều hướng (`Godot 4.7 Camera2D`)

Camera ưu tiên trải nghiệm **map-first**, vận hành mượt ở **60 FPS** trên cả Web (`gl_compatibility`) và Android:
- Hỗ trợ pan bằng `WASD` hoặc kéo chuột giữa trên Web/PC; vuốt kéo 1 ngón và chụm mở 2 ngón (Pinch-to-zoom) trên màn hình cảm ứng Android.
- Nội suy lướt camera độc lập tốc độ khung hình theo công thức hàm mũ `1.0 - exp(-smooth_speed * delta)` kết hợp kẹp biên bản đồ (`Viewport Bounds Clamping`) tính theo tỷ lệ Zoom thực tế.
- **3 nấc Zoom chuẩn & Ngưỡng cắt LOD tự động:**
  - *Tactical Zoom (`1.2x`):* Quan sát cận cảnh mô hình tiểu đội 2D hoạt họa và hiệu ứng giao chiến.
  - *Default Zoom (`1.0x`):* Khung nhìn chiến thuật chuẩn bao quát 10–12 ô hex xung quanh tâm điểm.
  - *Strategic Zoom (`0.5x`):* Toàn cảnh sa bàn chiến dịch.
  - **Ngưỡng chuyển đổi tự động (`zoom < 0.65`):** Ngay khi tỷ lệ phóng đại thu nhỏ xuống dưới `0.65`, hệ thống tự động ẩn lớp mô hình lính (`UnitModelLayer`) và bật lớp huy hiệu quân sự tối giản (**`StrategicTokenLayer` — Military Token**) để giảm tải Draw Calls, giữ vững 60 FPS trên Web & Android.
- Focus nhanh tới đơn vị đang còn lượt bằng double-click hoặc phím `Tab`; camera tự động lướt mượt tới đơn vị chủ đạo khi mở đầu lượt.
- **Game Feel & Rung Chấn (`Trauma-based Shake`):** Biên độ rung phi tuyến theo bình phương độ chấn thương (`trauma * trauma`) ghi vào `Camera2D.offset`, sử dụng bộ sinh số ngẫu nhiên riêng của giao diện (`_fx_rng`) để tuyệt đối không làm lệch trạng thái RNG tất định của mô phỏng chiến đấu.
- Khóa thao tác pan thủ công (`camera_locked = true`) trong lúc AI đang đi quân hoặc khi chạy hộp thoại sự kiện lịch sử.
- Chi tiết kỹ thuật và mã nguồn GDScript 2.0: xem [battle_ui_and_rendering.md](../ui_ux/battle_ui_and_rendering.md).

---

## 11.3. Battle UI và phản hồi

Giao diện chiến trường kế thừa bố cục `form_battle_game` và tinh giản theo phạm vi từng màn chơi:
- **Top Status Bar (Thanh Trạng thái Động):**
  - Luôn hiển thị: Nút Tạm dừng (`[PAUSE]`), Bộ đếm vòng đấu (ví dụ Slice-01: `VÒNG: 03/10`), Phe đang hành động, Điểm Mưu lược (`Mana`) và Tóm tắt mục tiêu chính.
  - **Ẩn/Hiện Kinh tế theo cờ kịch bản (`enable_economy`):** Ở các màn chiến thuật thuần túy như **Slice-01 Bạch Đằng 1288 (`enable_economy == false`)**, cụm tài nguyên `Coin / Food / Tech` được ẩn hoàn toàn để giữ HUD gọn sạch đúng phạm vi MVP; chỉ tự động hiển thị ở các màn P3+ có bật kinh tế chiến trường (`enable_economy == true`).
- **Overhead Unit Badges:** Nổi trực tiếp phía trên từng đạo quân (Thanh máu chia nấc theo số cờ gộp `TroopStack`, Icon 4 bậc Sĩ khí, Badges hiệu ứng khống chế CC).
- **Bottom Command Dock:** Khung Avatar Tướng, thông tin binh chủng/địa hình và cụm nút lệnh chuẩn hóa cho thao tác ngón cái: `[ĐI]`, `[ĐÁNH]`, `[MƯU LƯỢC]`, `[HOÀN TÁC]`, `[ĐỢI]` (chốt vị trí sau khi di chuyển) và `[KẾT THÚC LƯỢT]`.
- **Combat Preview Box (Xác nhận Đòn đánh 2 Bước):**
  - *Bước 1 (Nhắm mục tiêu):* Chạm lần 1 vào quân địch trong tầm để mở hộp dự báo sát thương (`Min~Max`, tỷ lệ Chí mạng `%`, dự báo Phản kích, hệ số Khắc chế/Địa hình/Flank) kèm hiệu ứng nhấp nháy phần máu dự kiến mất.
  - *Bước 2 (Thực thi):* Chạm lần 2 vào mục tiêu hoặc bấm nút `[ĐÁNH]` trên Command Dock để tung đòn — triệt tiêu hoàn toàn lỗi chạm nhầm trên màn hình cảm ứng.
- Sát thương nảy số động trên đầu quân (`WorldSpaceUnitHudAndTextLayer` — Floating Combat Text).
- Kiến trúc **16 lớp kết xuất phân tầng** (bao gồm `MapEffectLayer`, `StrategicTokenLayer`, `FogOfWarLayer` và `ScreenHudCanvasLayer`) cùng luồng **Input FSM 8 trạng thái** (`Idle -> UnitSelected -> Moving -> PostMoveAction -> ...`): xem [battle_ui_and_rendering.md](../ui_ux/battle_ui_and_rendering.md).

---

## 11.4. Undo và trợ giúp người chơi

### Quy tắc Undo 1 bước (`MarchCommand.can_undo()`)
Chỉ duy nhất lệnh di chuyển (`MarchCommand`) hỗ trợ hoàn tác khi đơn vị đang ở trạng thái `PostMoveAction` và thỏa mãn đồng thời **cả 5 điều kiện**:
1. Đơn vị chưa thực hiện hành động chính trong lượt (`!unit.has_acted`: chưa tấn công, chưa thi triển kỹ năng/mưu lược, chưa bấm `[ĐỢI]` chốt vị trí).
2. Chưa mở thêm ô sương mù hay phát hiện đơn vị địch mới trên bản đồ (`revealed_fog_cells.is_empty()`).
3. Chưa kích hoạt bất kỳ bẫy hay sự kiện ô bản đồ nào (`!triggered_cell_event`).
4. Chưa bước vào vùng kiểm soát ZOC của địch (`!entered_enemy_zoc`).
5. Đơn vị chưa sử dụng quyền Undo trong lượt hiện tại (`!unit.has_used_undo_this_turn`).

> **Giới hạn thiết kế:** Tối đa **01 lần Undo mỗi lượt cho mỗi đơn vị**, và các lệnh gây hệ quả vĩnh viễn/tiêu thụ RNG (`AttackCommand`, `CastSkillCommand`, `ApplyTacticCommand`) tuyệt đối không có hàm `undo()`. Quy tắc này cho phép sửa thao tác chạm nhầm mà ngăn chặn triệt để lối chơi *move–undo–move* trinh sát sương mù miễn phí. Đặc tả kỹ thuật lớp lệnh: xem [data_and_save_system.md](../architecture/data_and_save_system.md).

### Hướng dẫn & Codex
- **Codex:** Từ điển tra cứu nhanh về Sĩ khí (`Morale`), Vùng kiểm soát (`ZOC`), Gọng kìm (`Flank`), Thủy triều – Bãi cọc (`StakedWater`), phân kỳ vũ khí và hồ sơ nhân vật/sự kiện lịch sử (gắn rõ nhãn `historical_claim` vs. `abstraction`).
- **Tutorial ngữ cảnh:** Hiển thị gợi ý ngắn gọn ngay tại thời điểm cơ chế xuất hiện lần đầu (ví dụ: cảnh báo thủy triều rút và hiệu ứng bãi cọc ở Vòng 4 Slice-01), không ngắt mạch chơi bằng các trang hướng dẫn dài.
