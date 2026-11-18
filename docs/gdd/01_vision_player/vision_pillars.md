# 02. Tầm nhìn, định vị và trụ cột thiết kế

[← Quay lại Mục lục GDD](../README.md)

---

## 2.1. Tầm nhìn

Kiến tạo một trò chơi chiến thuật lịch sử Việt Nam dễ tiếp cận ngay trên trình duyệt **Web và thiết bị di động Android (60 FPS)** nhờ giao diện trực quan và thao tác gọn gàng, nhưng mang chiều sâu chiến thuật thực thụ từ địa hình sông ngòi rừng núi, nhịp thủy triều, thế trận bao vây bọc sườn, quản trị 4 bậc sĩ khí và hậu cần tác chiến. Người chơi phải cảm nhận rõ mỗi thời kỳ lịch sử — **từ buổi đầu dựng nước & Bắc thuộc đến thế kỷ XVIII (Triều Tây Sơn)** — đều sở hữu học thuyết tác chiến và bản sắc riêng biệt, thay vì chỉ thay đổi lớp vỏ hình ảnh trên cùng một công thức quân đội.

---

## 2.2. Định vị và phân vai Benchmark

Không có một tựa game tham chiếu đơn lẻ nào bao phủ trọn vẹn cả chiến dịch lịch sử trung đại, chiến trường lưới Hex rõ nét, hậu cần tác chiến và khả năng vận hành mượt mà trên Web/Mobile. Do đó, nhóm thiết kế phân vai **7 game benchmark** (đối chiếu chi tiết tại [Phụ lục A](../appendices/appendix_a_benchmark_matrix.md) và nguồn [Phụ lục B](../appendices/appendix_b_sources.md)):

| Benchmark | Bài học thiết kế cốt lõi | Áp dụng có chọn lọc trong Đại Việt Chiến Kỳ |
|---|---|---|
| **Great Conqueror 2: Shogun** `[S1]`, `[S8]` | Tổ chức chương hồi chiến dịch, thế lực, gộp cờ `TroopStack`, 4 bậc Sĩ khí và kiến trúc 15 lớp kết xuất 2D. | Tham chiếu khung hệ thống chiến trường và cấu trúc dữ liệu; viết lại toàn bộ bối cảnh, binh chủng và kịch bản cho lịch sử Việt Nam trên Godot 4.7 GDScript. |
| **European War 7: Medieval** `[S11]`, `[S8]` | Bản sắc chiến tranh trung đại, kỹ năng chủ động của danh tướng, duyên phận lịch sử (`Fetters`) và cơ chế công thành cổ trung đại. | Tham chiếu cách khắc họa danh tướng và công sự phong kiến; **không sao chép** việc khóa cứng danh tướng lịch sử sau paywall nạp tiền thật (`D-07`). |
| **European War 6: 1914** `[S9]`, `[S8]` | Mạch nhiệm vụ theo giai đoạn, hệ thống thử thách 3 sao và cơ sở kinh tế trên bản đồ trận đánh. | Tham chiếu cách thiết kế mục tiêu phụ và nhịp sự kiện trong trận; tránh lặp màn hoặc ép người chơi cày cuốc lặp lại. |
| **Panzer Corps 2** `[S3]`, `[S10]` | Hình học lưới Hex, phân vai khắc chế binh chủng, vùng kiểm soát (`ZOC`), bao vây và sự tiếp nối lực lượng qua chiến dịch. | Tham chiếu độ sâu vị trí và giá trị bảo toàn quân số (tiêu chí 3 sao); không sao chép biên chế sư đoàn hiện đại hay mật độ thông số phức tạp. |
| **Unity of Command II** `[S4]` | Biến tuyến tiếp tế, trinh sát và sương mù chiến tranh thành các quyết định không gian trực quan trên bản đồ. | Tham chiếu cách làm cho Hậu cần/Lương thảo (`P3 scope`) dễ đọc bằng mắt thường thay vì bảng biểu vi mô nặng nề. |
| **Hearts of Iron IV** `[S5]` | Khái niệm nguồn cung ứng, kho lương trung tâm và điểm nghẽn giao thông chiến lược. | Tham khảo tư duy cắt tuyến lương thảo (như trận Vân Đồn hay kế *Vườn không nhà trống* ở `P3+`); không mô phỏng công nghiệp hay quản trị vĩ mô toàn quốc. |
| **World Conqueror 4** `[S2]`, `[S8]` | Cấu trúc 4 chế độ chơi bổ trợ nhau (*Scenario, Conquest, Legion, Domination*). | Tham chiếu cách mở rộng vòng đời sản phẩm dài hạn; mọi chế độ trong *Đại Việt Chiến Kỳ* đều dùng chung một bộ luật chiến trường cốt lõi. |

**Design Rationale — Phân vai benchmark:** Tách bạch bài học từ từng tựa game giúp dự án chắt lọc được sự gọn nhẹ, đầm tay của dòng wargame di động Á Đông kết hợp cùng tính kỷ luật không gian của wargame PC phương Tây, đồng thời chủ động loại bỏ các yếu tố thương mại hóa gây mất cân bằng.

---

## 2.3. Năm trụ cột thiết kế (Design Pillars)

| Trụ cột | Nguyên tắc thiết kế | Dấu hiệu kiểm chứng trong Playtest |
|---|---|---|
| **1. Lịch sử có căn cứ** | Phân biệt minh bạch giữa dữ kiện lịch sử (`historical claim`), trừu tượng hóa lối chơi (`gameplay abstraction`) và giả định (`What-if`); mọi tuyên bố lịch sử có `sourceRef` và `Evidence grade` (xem [historical_framework.md](../03_content_presentation/historical_framework.md)). | Người chơi nhận biết rõ đâu là sự kiện có nguồn sử liệu/khảo cổ và đâu là cơ chế mô hình hóa của game. |
| **2. Dễ đọc, khó làm chủ** | Mọi nước đi có nhân quả rõ ràng; cơ chế **Controlled RNG có Seed tất định (`Seeded RNG`)** hiển thị công khai dải sát thương `[Min, Max]`, `% Crit`, phản kích và các hệ số địa hình/sĩ khí trên **Combat Preview** (không có đánh trượt ngẫu nhiên). | Ít nhất `4/5` người chơi thử (`[D-17]`) tự giải thích được nguyên nhân thắng, thua hoặc mất thế trận mà không cần dev giải thích. |
| **3. Bản sắc quân sự Việt Nam** | Thủy triều lên xuống, bãi cọc ngầm (`StakedWater`), rừng rậm phục kích, voi chiến phá tuyến và kế cắt lương thảo (`Starvation` ở `P3`) tạo ra lối đánh đặc trưng cho từng thời kỳ. | Trận Bạch Đằng 1288 đòi hỏi tư duy nhử địch theo con nước hoàn toàn khác một trận công thành hay giao chiến đồng bằng. |
| **4. Quyết định có đánh đổi** | Ngân sách điểm di chuyển (`MP`), 1 hành động chính/lượt, giới hạn 1 phản kích/lượt và áp lực số lượt (`<= 8` lượt cho 2 Sao) buộc người chơi liên tục cân nhắc giữa tiến công, khép vây và giữ cứ điểm. | Mỗi lượt người chơi đứng trước ít nhất 2 phương án khả thi có rủi ro – phần thưởng khác biệt rõ rệt, không có nước đi auto-win. |
| **5. Mở rộng bền vững đa nền tảng** | Phát triển cuốn chiếu theo từng *Era Pack* trên kiến trúc dữ liệu JSON và **Godot 4.7 GDScript 2.0**, duy trì **60 FPS** ổn định trên cả Web lẫn Android nhờ `gl_compatibility` và `StrategicZoom`. | Bổ sung kịch bản và thời kỳ mới bằng dữ liệu mà không phải viết lại core engine hay làm sụt giảm hiệu năng thiết bị. |

---

## 2.4. Non-goals (Những điều dự án chủ động KHÔNG làm)

- **Không mô phỏng đại chiến lược vĩ mô toàn diện:** Không quản lý dân số chi tiết, thuế khóa phức tạp, nội chính triều đình hay cây công nghiệp quốc gia.
- **Không làm RTS thao tác nhanh:** Không yêu cầu phản xạ thời gian thực hay điều khiển vi mô từng người lính riêng lẻ.
- **Không áp đặt học thuyết quân sự cận – hiện đại:** Không gán ghép cấp sư đoàn, lữ đoàn hay thông số đạn đạo hiện đại lên các đạo quân cổ – trung đại Việt Nam.
- **Không đưa Multiplayer, PvP xếp hạng hay Gacha vào Slice-01 và MVP (`P2–P5`):** Toàn bộ giai đoạn đầu tập trung 100% cho trải nghiệm chiến thuật đơn người chơi chất lượng cao. Ở giai đoạn mở rộng về sau (`P4+`), hệ thống chiêu mộ tướng bắt buộc tuân thủ nguyên tắc **F2P thân thiện (`D-07`)** — không khóa cứng bất kỳ danh tướng lịch sử nào sau paywall tiền thật và giữ nguyên `Preset Loadout` công bằng trong Historical Scenario.
- **Không biến dữ liệu tạm (`fixture`) thành tuyên bố sử học:** Không khẳng định bất kỳ hình ảnh minh họa, vị trí ô Hex hay con số sát thương nào là sự thật lịch sử tuyệt đối nếu chưa qua thẩm định `Dossier`.
