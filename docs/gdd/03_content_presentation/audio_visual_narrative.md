# 13. Mỹ thuật, âm thanh và tường thuật (Audio/Visual & Narrative)

[← Quay lại Mục lục GDD](../README.md)

---

> 📖 **Tài liệu đặc tả chi tiết chuyên sâu:**  
> Xem toàn bộ kiến trúc phản hồi va chạm (Trauma Shake, Local Hit-Stop, Squash & Stretch, Hit Flash `canvas_item`), hệ thống hạt `CPUParticles2D` kết hợp Object Pooling (tối ưu `gl_compatibility` cho Web & Android 60 FPS) và Audio Bus 4 luồng tại:  
> 👉 [Hệ Thống VFX, SFX & Đánh Bóng Phản Hồi (vfx_sfx_and_polish.md)](../vfx_sfx/vfx_sfx_and_polish.md)

---

## 13.1. Art Direction (Định hướng mỹ thuật & Lộ trình Đồ họa `DEC-022`)

- **Giai đoạn Vertical Slice kỹ thuật (`R3`):** Tạm thời kế thừa bộ `TileSet` lục giác, công trình Đỏ/Xanh, 12 sprite sheet đơn vị `32×32` có hoạt ảnh, shader (`FactionTint`, `pulse_highlight`, `territory_border`) và bộ SFX sạch từ `HexCrown` vào `res://assets_clean/hexcrown/` để đảm bảo bản đồ `TileMapLayer` và `unit_view.tscn` vận hành mượt ở **60 FPS** trên renderer **Godot 4.7 `gl_compatibility`** (Web & Android).
- **Cổng So sánh Mỹ thuật (`R4` — Chưa khóa cứng phong cách cuối cùng):** Trước khi sản xuất hàng loạt asset riêng, bắt buộc dựng **2 mẫu nhỏ trên cùng cảnh Bạch Đằng** để người dùng đối chiếu trực quan và chốt phong cách chính thức, tiến tới thay thế dần asset kế thừa từ `HexCrown`:
  1. **Mẫu A — Pixel Art:** Đồng bộ phong cách `HexCrown`, thiết kế bổ sung Sprite Chiến thuyền và Bãi cọc Bạch Đằng (`StakedWater`).
  2. **Mẫu B — 2D Cách điệu chiến thuật kiểu EasyTech (2D Stylized Historical Map):** Bản đồ quân sự cổ cách điệu hóa, đường nét rõ sắc và trang phục lịch sử Việt Nam tự thiết kế.
- **Quy tắc cứng quy trình tạo Asset (`DEC-022`):** Khi đến bất kỳ bước thiết kế hoặc tạo asset mới nào, **bắt buộc dừng lại hỏi người dùng** để người dùng lên phương án và chọn công cụ thiết kế; tuyệt đối không tự ý vẽ hay sinh asset.
- **Yêu cầu hiển thị:** Bản đồ dễ đọc địa hình, silhouette binh chủng tách biệt rõ ràng ở cả tầm nhìn gần (`UnitModelLayer`) lẫn khi thu nhỏ sang huy hiệu quân sự (`StrategicTokenLayer` ở `zoom < 0.65`), màu sắc phân phe sắc nét và không lấn át thông tin chiến thuật.
- **Chân dung tướng:** Là tranh minh họa tái dựng nghệ thuật theo tư liệu trang phục thời đại; khi không có di ảnh lịch sử đương thời xác thực, tuyệt đối không gắn nhãn như chân dung lịch sử nguyên bản.
- **Tính đồng bộ & Quản trị Placeholder:** Map tiles, icon, chân dung, VFX và thanh trạng thái đơn vị tuân thủ chung hệ thống tỷ lệ và độ tương phản. Mọi tài nguyên placeholder dùng thử nghiệm nội bộ phải được kiểm kê minh bạch và thay thế 100% trước bản phát hành chính thức theo lộ trình tại [ASSET_CATALOG.md](../../assets/ASSET_CATALOG.md).

---

## 13.2. Âm thanh & Nhạc Nền Thích Ứng (SFX & Dynamic BGM)

- **UI Audio:** Ngắn gọn, dứt khoát, nhất quán trên `UI Bus` và không gây mỏi tai khi thao tác qua hàng trăm lượt.
- **Chiến trường (SFX) & Phân kỳ thời đại (`Era-gating`):**
  - Cấp phát qua **Audio Pooling 24 kênh** (`AudioStreamPlayer2D` / `AudioStreamPlayer`) để triệt tiêu độ trễ cấp phát bộ nhớ trên Web & Android.
  - **Quy tắc `Era-gating` bắt buộc:** Hệ thống âm thanh vũ khí phải khóa chặt theo thời kỳ lịch sử của kịch bản. Cụ thể, tiếng nổ hỏa khí (**Súng Thần Cơ, Hỏa pháo, Hỏa mai**) chỉ được kích hoạt ở các chiến dịch từ **thời Hồ – Lê Sơ (thế kỷ XV) đến Tây Sơn (thế kỷ XVIII)**; **tuyệt đối không xuất hiện trong Slice-01 Bạch Đằng 1288** (thời Trần thế kỷ XIII chỉ sử dụng âm thanh đao kiếm, trường giáo, cung nỏ, hỏa thuyền bốc cháy, chiến thuyền va cọc gỗ, trống đồng và tù và).
- **Âm nhạc (Dynamic BGM):**
  - *Player Turn:* Nhạc cụ truyền thống (đàn tranh, đàn bầu, sáo trúc, tiêu) trầm tĩnh, tạo không gian suy tính nước đi.
  - *Combat / AI Turn:* Trống trận dồn dập, tiết tấu dâng cao thúc đẩy nhịp độ giao tranh.
  - *Nguy cấp / Hậu cần đứt gãy (ở các màn P3+ có kinh tế):* Giai điệu trầm uất cảnh báo áp lực chiến trường.

---

## 13.3. Phản Hồi Va Chạm (Game Feel / Juice)

- **Trauma-based Screen Shake:** Rung lắc `Camera2D.offset` phi tuyến tính theo công thức $\text{Shake} = \text{Trauma}^2 \times \text{Strength}$, sử dụng RNG riêng của tầng hiệu ứng (`_fx_rng`) tách biệt hoàn toàn khỏi RNG mô phỏng trận đánh.
- **Local Hit-Stop (Micro-freeze 40–150ms cục bộ):** Chỉ tạm dừng hoạt cảnh của **2 đơn vị đang trực tiếp giao chiến** kèm bộ đếm thời gian thực (`ignore_time_scale = true`), **tuyệt đối không đặt `Engine.time_scale = 0.0` toàn cục** để giữ mượt camera, HUD và âm thanh.
- **Squash & Stretch & Hit Flash tối ưu Batching:** Đơn vị trúng đòn biến dạng đàn hồi qua `Tween` và chớp sáng 50ms bằng shader `canvas_item` gắn tạm thời (hoặc `self_modulate` overbright trên cấu hình thấp) để không làm gãy chuỗi **2D Batching** trên `gl_compatibility`.
- **Trợ năng (Accessibility):** Cung cấp thanh trượt cường độ rung màn hình (`0%–100%`) và tùy chọn giảm chớp sáng (`Reduce Flashing`) tuân thủ ngưỡng an toàn thị giác WCAG 2.3.1.

---

## 13.4. Tường thuật (Narrative)

- **Briefing trước trận:** Ngắn gọn, súc tích, nêu bật bối cảnh lịch sử, tương quan thế trận, điều kiện Thắng/Thua và các quy tắc đặc biệt của màn chơi.
- **Codex:** Lưu trữ bài viết bối cảnh chuyên sâu, nguồn trích dẫn (`[S6]`, `[S7]`, `[S12]`–`[S16]`), phân biệt rõ phần sự thật lịch sử (`historical_claim`) với phần cô đọng gameplay (`abstraction` / `fixture`).
- **Nhịp độ:** Không ngắt quãng giao tranh bằng các đoạn văn bản dài (*wall of text*); lời thoại trong trận chỉ xuất hiện ngắn gọn tại các bước ngoặt chiến thuật (như thời khắc thủy triều rút ở đầu Vòng 4 Bạch Đằng 1288).
