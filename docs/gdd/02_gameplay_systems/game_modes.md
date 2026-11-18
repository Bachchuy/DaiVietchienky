# 05. Các mode chơi

[← Quay lại Mục lục GDD](../README.md)

---

Scenario, Conquest, Legion và Domination là bốn chế độ chơi dài hạn của **Đại Việt Chiến Kỳ** (100% Single-player trên Web và Android); tất cả dùng chung hệ lưới Hex, 9 loại địa hình, vai trò binh chủng, 4 bậc Sĩ khí và công thức chiến đấu để người chơi không phải học lại luật cốt lõi khi chuyển chế độ. Khác biệt giữa các mode nằm ở quy mô mục tiêu, quản trị nguồn lực và cách tổ chức lực lượng.

**Design Rationale — Dùng chung luật chiến trường:** Khi mọi chế độ chia sẻ cùng quy tắc di chuyển, vùng kiểm soát (`ZoC`/`CoC`), giao tranh và Sĩ khí, kỹ năng đọc địa hình học được từ một kịch bản lịch sử sẽ chuyển hóa trực tiếp sang chiến dịch Chinh phạt hoặc Thử thách tác chiến.

---

## 5.1. Scenario — Chiến dịch và trận kịch bản

Scenario là trải nghiệm lịch sử được biên tập chặt chẽ, gồm briefing bối cảnh, lực lượng, bản đồ chiến thuật, mục tiêu chính/phụ (1–3 sao) và sự kiện theo lượt (`ScenarioEvents` / `MapPhase`). Các trận trong cùng một chương nối tiếp nhau theo dòng thời gian lịch sử. **Historical Scenario** khóa hồ sơ tướng và biên chế cốt lõi theo kịch bản để bảo toàn tính toàn vẹn lịch sử và độ khó chuẩn; nhánh giả định (*What-if*) nếu có bắt buộc gắn nhãn riêng.

Nhiệm vụ có thể yêu cầu trấn giữ cứ điểm, bảo vệ chủ tướng hoặc đoàn thuyền lương, phá vây, nghi binh dụ địch vào trận địa mai phục, tiêu diệt soái kỳ địch hoặc trụ vững đến lượt quy định.

### Kết quả và phản hồi thất bại
Sau trận, màn hình `Battle Result` tổng kết rõ các mục tiêu đạt/trượt (1–3 sao), thương vong và các bước ngoặt quyết định; người chơi có thể mở `CombatLog` để tra cứu từng pha giao tranh. Từ đây có thể chơi lại ngay, quay về bước bố trí trước trận (`Pre-Battle Deployment`), hoặc rời màn. Khi thất bại, giao diện chỉ rõ nguyên nhân chiến thuật trực tiếp (ví dụ: mất `SignalDock`, chủ tướng bị hợp vây `CHAOS`, quá giới hạn `max_rounds`) thay vì chỉ báo "Thất bại" chung chung.

### Quy chuẩn Quy mô & Sa bàn Phóng đại Chiến thuật (Tactical Zoom-in Map)
* **Kích thước trung bình:** `18 × 16` hex (~288 hex).
* **Phân cấp quy mô màn chơi:**
  * *Nhỏ / Mở màn (Skirmish):* `12 × 10` đến `14 × 12` hex (`8–12` vòng, ví dụ: Slice-01 Bạch Đằng 1288).
  * *Tiêu chuẩn (Standard):* `16 × 14` đến `18 × 16` hex (`12–16` vòng, 220–290 hex).
  * *Đại chiến dịch (Major Decisive):* `24 × 20` đến `34 × 28` hex (`18–25` vòng, 480–950 hex).
* **Nguyên lý Sa bàn Phóng đại Tỷ lệ Chiến thuật (`Tactical Zoom-in Map`):** Mỗi màn Scenario được gắn neo vào một tọa độ địa chiến lược `anchor_hex (q, r)` trên bản đồ toàn quốc để hiển thị vị trí lịch sử trên giao diện chọn màn, nhưng bản thân lưới Hex trong trận (như lòng sông, bãi bồi, rừng rậm và bãi cọc Bạch Đằng `12 × 10`) là **sa bàn chiến thuật được thiết kế và phóng đại riêng theo tỷ lệ trận đánh**, tuyệt đối không cắt thô 12 ô vĩ mô từ bản đồ chiến lược Conquest.

### Slice-01 (Bạch Đằng 1288)
Slice-01 là kịch bản trọng tâm của giai đoạn Vertical Slice (P2): bản đồ `12 × 10` hex, giới hạn `10` vòng, có chuyển pha thủy triều `MapPhase` làm lộ bãi cọc ngầm (`STAKED_WATER`) và mục tiêu giữ vững Bến Hiệu Lệnh (`SignalDock`). Đặc tả chi tiết nhịp độ 3 hồi, điều kiện 3 sao và dữ liệu kịch bản xem tại [production_scope_mvp.md](../04_production_roadmap/production_scope_mvp.md) và [scenario_scripting_and_events.md](../level_design/scenario_scripting_and_events.md).

---

## 5.2. Conquest — Chinh phạt toàn cục

Conquest mở ra khả năng chơi lại cao bằng cách cho người chơi chọn một thế lực trong một niên đại lịch sử và tranh quyền kiểm soát giang sơn. Mỗi vòng bật đầy đủ hệ thống kinh tế chiến trường (`enable_economy = true`, xem [battlefield_economy.md](../mechanics/battlefield_economy.md)): thu hoạch `Coin / Food / Tech / Mana`, cân đối quân lương `MealFood`, bổ nhiệm danh tướng tại Thành chính, nâng cấp công sự và điều phối nhiều mặt trận cùng lúc.

### Quy chuẩn Bản đồ Chiến lược Trục Dọc Bắc – Nam (Conquest Map Dimension)
Khác với bản đồ nằm ngang của quần đảo Nhật Bản, bản đồ chiến lược Đại Việt được thiết kế theo **trục dọc Bắc – Nam** ôm trọn địa hình dải chữ S, lưu vực sông Hồng – sông Mã – sông Lam, dãy Trường Sơn, vùng biên viễn phía Bắc và thềm biển Đông:
* **Bản đồ Tiêu chuẩn (`1.0x`):** **`120 × 240 hex`** (~28.800 hex theo hệ Offset `odd-r` quy đổi sang Pointy-topped Axial), hỗ trợ `15–25` thế lực, thời lượng trung bình `40–80` vòng.
* **Bản đồ Mở rộng Liên khu vực (`1.5x – 2.0x`):** Mở rộng lên **`180 × 360 hex`** hoặc **`240 × 480 hex`** cho các kịch bản đại chiến khu vực Đông Á – Đông Nam Á.

> **Phạm vi sản xuất:** Out of scope cho Slice-01; triển khai từ mốc **P3 Alpha** trở đi.

---

## 5.3. Legion — Thử thách tác chiến (Challenge Mode)

Legion cung cấp các bài toán chiến thuật chuyên biệt với quy tắc ràng buộc rõ ràng: hộ tống thuyền lương qua luồng hẹp, đột kích phá kho lương địch, tử thủ cửa ải qua nhiều đợt công kích hoặc giới hạn số ô tướng. Để đảm bảo chiến thuật thuần túy và chống lấy cấp độ đè bài toán (*anti-grind*), các ải thử thách áp dụng **Giới hạn Cấp Trần (`Level / Stat Cap`)** công khai trước trận.

> **Phạm vi sản xuất:** Out of scope cho Slice-01; triển khai từ mốc **P3 Alpha**.

---

## 5.4. Domination — Tổng hành dinh và phát triển lực lượng

Domination là tầng quản lý ngoại trận (Meta Layer) giữa các màn chơi để chiêu mộ, bồi dưỡng Danh tướng theo 4 trục, rèn Bảo vật Đại Việt và kích hoạt Duyên phận lịch sử (xem chi tiết tại [meta_progression.md](meta_progression.md) và [generals_and_meta_economy.md](../progression/generals_and_meta_economy.md)). Hệ thống mở khóa hướng tới mở rộng lựa chọn phối hợp đội hình và thân thiện với người chơi miễn phí (F2P), không thay thế vai trò của địa hình, bao vây hay khắc chế binh chủng trên chiến trường.

> **Phạm vi sản xuất:** Out of scope cho Slice-01; triển khai từ mốc **P3 Alpha**.
