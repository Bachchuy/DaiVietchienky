# 03. Người chơi và trải nghiệm mục tiêu

[← Quay lại Mục lục GDD](../README.md)

---

## 3.1. Chân dung người chơi mục tiêu

| Nhóm người chơi | Nhu cầu cốt lõi | Đáp ứng thiết kế trong Đại Việt Chiến Kỳ |
|---|---|---|
| **Người chơi chiến thuật phổ thông (Web & Mobile)** | Vào trận nhanh không cần cài đặt nặng, hiểu luật trực quan trong vài phút, hoàn thành ván chơi gọn trong một phiên nghỉ ngắn. | Chạy mượt 60 FPS ngay trên trình duyệt Web & Android; Briefing ngắn gọn có nút Bắt đầu/Bỏ qua rõ ràng, mục tiêu nổi bật, chạm 1 lần vào địch trong tầm Đỏ để đánh ngay như `HexCrown`. |
| **Người yêu thích lịch sử Việt Nam** | Được trực tiếp chỉ huy các trận đánh hào hùng từ thời dựng nước & Bắc thuộc đến Tây Sơn với thái độ trân trọng sử liệu. | Hồ sơ Codex trích dẫn nguồn rõ ràng (`[S6]`, `[S12]–[S16]`), phân biệt minh bạch dữ kiện lịch sử (`historical claim`) với mô hình hóa lối chơi (`gameplay abstraction`). |
| **Người chơi đam mê Wargame theo lượt** | Đòi hỏi chiều sâu vị trí, tương khắc binh chủng, quản trị rủi ro tự tính toán và AI đối thủ công bằng. | Lưới Hex Axial chuẩn xác, ZoC/CoC, bọc sườn (`Flank`), bao vây đa cấp (`TrappedLevel`), 4 bậc Sĩ khí Enum và `UnitInspector` cung cấp đầy đủ thông số thô từng đạo quân. |

---

## 3.2. Hành trình cảm xúc trong trận đánh

### Trước trận — Đọc thế đất và lập mưu có chủ đích
- Người chơi đọc Briefing ngắn gọn, quan sát toàn cảnh bản đồ (hỗ trợ thu phóng mượt qua `StrategicZoom`) để nhận diện luồng sông, bãi cạn, rừng phục kích, cao điểm và vị trí cứ điểm trọng yếu.
- Trong chế độ **Historical Scenario**, trò chơi áp dụng hồ sơ tướng khóa sẵn (`Preset Loadout` — quyết định `D-02`) đúng bối cảnh trận đánh; người chơi tập trung đọc tương quan binh chủng, kỹ năng tướng (`UniqueSkill`) và địa hình sở trường (`FondTerrain`) để vạch kế hoạch tác chiến.
- Cảm giác mong muốn: *“Mình đã nhìn ra chỗ hiểm của bản đồ và nhịp con nước — giờ là lúc bày thế trận thực thi.”* Khi thất bại, người chơi truy nguyên được nguyên nhân từ quyết định chọn tuyến, giữ nhịp hoặc phân tán lực lượng của chính mình; trò chơi vận hành bằng **Controlled RNG có Seed tất định (`Seeded RNG`)** sinh dao động thực tế lúc giao tranh (không đánh trượt/`miss` vô lý), đồng thời giữ công khai mọi thông số gốc của từng đạo quân qua **`UnitInspector`** để người chỉ huy tự cân nhắc.

### Trong trận — Cảm giác cầm quân và nắm bắt thời cơ
- Ngân sách điểm di chuyển (`MP`) và quy tắc dừng bước khi chạm `ZOC` khiến từng ô tiến hay lùi đều mang tính cam kết vị trí; đơn vị đã thực hiện hành động chính không thể rút lui thêm trong cùng lượt (trừ phi sở hữu đặc tính du kích chuyên biệt).
- **`UnitInspector` & Đánh ngay 1 chạm (không dùng bảng biết trước `CombatPreview`):** Người chơi chạm/chuột phải vào từng đạo quân để đọc thông số gốc (HP, Công, Thủ, Tầm đi/đánh, Sĩ khí, Địa hình) rồi **tự tính toán tương quan lực lượng**; khi đã chọn quân ta và chạm 1 lần vào địch trong tầm Đỏ là giao chiến ngay lập tức, hệ thống giải quyết công thức Giáp `100 / (100 + EffectiveDef)`, `TroopStack`, `Flank` kèm độ lệch ngẫu nhiên (`Seeded RNG` `80%–100%` + Crit) và nảy số thiệt hại thực tế. Nhờ bộ tạo số ngẫu nhiên gắn `seed/state` riêng, mọi pha giao tranh đều bảo đảm **100% Deterministic Replay**.
- Người chơi liên tục đứng trước các bài toán đánh đổi chiến thuật sắc nét: **dùng thủy đội nhẹ nhử và khép vây chiến thuyền quân Đại Nguyên lọt vào khu vực bãi cọc ngầm đúng thời điểm thủy triều rút (`MapPhase_TideFall` đầu Vòng 4), hay rút bớt chủ lực về gia cố tuyến phòng thủ quanh Bến Hiệu Lệnh (`SignalDock`) trước sức ép mũi đột kích địch** — không có lựa chọn máy móc nào luôn đúng trong mọi tình huống.
- Mỗi lượt trôi qua làm dịch chuyển thế trận, bậc Sĩ khí và tiến độ mục tiêu 3 sao; kết thúc trận, người chơi giải thích rành mạch vì sao kế hoạch thành công hay vỡ trận.

### Sau trận — Thấu hiểu nhân quả và được ghi nhận xứng đáng
- Màn hình **Battle Result** tổng kết kết quả mục tiêu chính, đánh giá 3 mốc Sao (Thắng trận / Thắng nhanh `<= 8` lượt / Bảo toàn lực lượng tổn thất HP `<= 20%`), thống kê thiệt hại hai phe và nhật ký điểm nhấn chiến thuật.
- Trong các chế độ chiến dịch mở rộng về sau (`P3+`), kết quả trận đánh kết nối trực tiếp sang phần thưởng Quân công, Ngọc Bích tích lũy F2P và mở khóa mục từ mới trong **Codex Lịch sử** kèm trích dẫn nguồn đã duyệt.
- Người chơi có động lực rõ ràng để thử lại trận đánh với phương án điều quân tối ưu hơn nhằm chinh phục đủ 3 Sao hoặc thử sức ở bậc độ khó cao hơn.

### Hành trình trải nghiệm mẫu trong Slice-01 (`stage_id: 10101` — Bạch Đằng 1288)
Người chơi đọc Briefing trận Bạch Đằng 1288 (gắn nhãn `fixture / gameplay abstraction`), xác định hai trọng tâm sống còn: bảo vệ vững chắc **Bến Hiệu Lệnh (`SignalDock` tại `(2, 8)`)** và tận dụng con nước triều rút ở đầu **Vòng 4** để tiêu diệt hạm đội **Đại Nguyên** do **Ô Mã Nhi** thống lĩnh. Trong 3 vòng đầu, người chơi xem thông số đội hình địch qua `UnitInspector` để tự cân nhắc thế đánh, vừa kìm chân tiền quân giặc vừa khéo léo nhử và ép các chiến thuyền chủ lực của địch tiến sâu vào vùng nước bãi cọc ngầm. Đầu Vòng 4, sự kiện `MapPhase_TideFall` kích hoạt: bãi cọc nhọn nhô lên đâm thủng thuyền giặc đang đứng trên cọc (`-35% MaxHP`, khóa di chuyển `MarchDisabled` 2 lượt và đẩy Sĩ khí địch sụp xuống `CHAOS` 1 lượt), đồng thời phục binh Đại Việt hai bên bờ xuất kích khép gọng kìm (`Flank` / `TrappedLevel`). Người chơi chớp thời cơ dồn hỏa lực hạ gục soái hạm Ô Mã Nhi trong khi vẫn giữ vững `SignalDock (2, 8)` để giành **Chiến thắng tức thì** trước lượt thứ 8 (đạt mốc 2 Sao và hướng tới mốc 3 Sao tổn thất `<= 20%` HP).

---

## 3.3. Nhịp độ và thời lượng mục tiêu

| Hoạt động trải nghiệm | Thời lượng mục tiêu |
|---|---:|
| Một trận Historical Scenario quy mô gọn (như Slice-01: 10 lượt) | **8–15 phút** |
| Một trận chiến dịch quy mô lớn (nhiều giai đoạn / có kinh tế hậu cần P3) | **15–25 phút** |
| Thời gian thao tác của người chơi trong 1 lượt trung bình | **45–90 giây** |
| Thời gian máy xử lý lượt AI (kèm lia camera phản hồi) | **1.5–3.0 giây** |
| Một phiên chơi trọn vẹn trên Web / Mobile | **10–30 phút** |

Các ngưỡng trên là mục tiêu thiết kế dùng để đo kiểm trong vòng Playtest (`[D-17]`): hệ thống cần ghi nhận thời lượng trung vị hoàn thành màn, số lượt thực tế đạt chiến thắng, số chạm trung bình mỗi lệnh (`<= 2 chạm`) và tỷ lệ bỏ dở giữa chừng để tinh chỉnh trước Gate `P2`.

---

## 3.4. Anti-experience — Những trải nghiệm tuyệt đối tránh

- **“Tôi thua/thắng chỉ vì một cú đánh trượt may rủi vô lý.”** Trò chơi loại bỏ hoàn toàn cơ chế đánh trượt (`miss`) ngẫu nhiên; **Seeded RNG** chỉ tạo biên độ dao động hợp lý (`80%–100%` + Crit) dựa trên thông số minh bạch của từng đạo quân trên `UnitInspector`, đặt quyền tính toán rủi ro vào tay người chỉ huy.
- **“Tôi thua vì game giấu luật hoặc bất ngờ bẫy người chơi không báo trước.”** Mọi hệ số địa hình, trạng thái `CHAOS`, `MarchDisabled`, điều kiện thắng tức thì và dấu hiệu thủy triều đều được báo hiệu rõ qua Briefing, cảnh báo đầu vòng, tooltip và Combat Log.
- **“Tôi phải nạp tiền thật hoặc cày tướng thật mạnh mới qua được ải lịch sử.”** Chế độ Historical Scenario khóa cứng `Preset Loadout` (`D-02`); đồng thời ở giai đoạn mở rộng (`P4+`), chính sách **F2P thân thiện (`D-07`)** cam kết người chơi có thể tích lũy Ngọc Bích và Lệnh Chiêu Mộ miễn phí để sở hữu mọi phẩm tướng kể cả bậc Đỏ, không khóa danh tướng lịch sử sau paywall.
- **“Tôi phải học hàng chục bảng số liệu mới bắt đầu chơi được.”** Áp dụng nguyên tắc tiết lộ tiệm tiến (*Progressive Disclosure*): Slice-01 ẩn lớp kinh tế (`enable_economy = false`) để người chơi làm chủ không gian Hex, Sĩ khí và địa hình trước khi tiếp cận Hậu cần ở các chương nâng cao (`P3`).
- **“Cứ co cụm thủ một góc chờ hết lượt là thắng.”** Mốc 2 Sao (`<= 8` lượt), ngưỡng tiêu diệt `>= 75%` quân địch khi đánh hết 10 lượt và cơ hội vàng lúc triều rút Vòng 4 khuyến khích người chơi chủ động điều quân giăng bẫy thay vì phòng ngự thụ động.
- **“Đây chỉ là game nước ngoài thay hình lính Việt.”** Từ con nước Bạch Đằng, thế trận cọc ngầm, hỏa thuyền cho đến ngữ cảnh lịch sử có thẩm định đều được thiết kế xoay quanh đặc trưng địa quân sự Việt Nam.
