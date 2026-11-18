# Phụ lục A. Feature Reference Matrix & Checklist Đo lường Định lượng

[← Quay lại Mục lục GDD](../README.md)

---

## A.1. Bảng đối chiếu học hỏi từ 7 Game Benchmark (Feature Reference Matrix)

Các tựa game tham chiếu dưới đây cung cấp bài học về cấu trúc chế độ chơi, ngôn ngữ không gian chiến trường và trải nghiệm người dùng dựa trên thông tin công khai (đồng bộ 100% với phân vai tại [vision_pillars.md](../01_vision_player/vision_pillars.md#22-định-vị-và-phân-vai-benchmark); danh mục nguồn tại [Phụ lục B](appendix_b_sources.md)). Bảng này định rõ ranh giới giữa nguyên tắc thiết kế được kế thừa có chọn lọc và những yếu tố chủ động loại bỏ.

| Game Benchmark | Bài học đáng nghiên cứu | Ứng dụng trong Đại Việt Chiến Kỳ | Tuyệt đối không sao chép |
|---|---|---|---|
| **Great Conqueror 2: Shogun** `[S1]`, `[S8]` | Tổ chức chương chiến dịch, thế lực, gộp cờ `TroopStack`, 4 bậc Sĩ khí và kiến trúc phân lớp 2D. | Tham chiếu khung vận hành trận đánh, nhịp gộp cờ 1x–3x và cách trình bày chiến dịch Á Đông. | Tên gọi, mỹ thuật, UI gốc, dữ liệu JSON thương mại, cốt truyện Nhật Bản và thông số cân bằng nguyên bản. |
| **European War 7: Medieval** `[S11]`, `[S8]` | Bản sắc chiến tranh cổ – trung đại, kỹ năng chủ động của danh tướng, hệ thống duyên phận (`Fetters`) và công thành phong kiến. | Tham chiếu cách khắc họa vai trò danh tướng chỉ huy, liên kết lịch sử giữa các hào kiệt và nhịp công phá thành lũy. | Chính sách khóa cứng danh tướng lịch sử bậc cao nhất sau paywall nạp tiền thật (`D-07`) hoặc để trang bị đè bẹp chiến thuật. |
| **European War 6: 1914** `[S9]`, `[S8]` | Cấu trúc chương hồi theo giai đoạn, thử thách 3 sao và hệ thống công trình kinh tế trong trận. | Tham chiếu cách đặt mục tiêu phụ có thời hạn lượt (như mốc 2 Sao `<= 8` lượt) và cơ sở hậu cần ở `P3`. | Vòng lặp cày cuốc lặp lại nhàm chán hoặc ép nâng cấp chỉ số ngoại trận để vượt ải lịch sử. |
| **Panzer Corps 2** `[S3]`, `[S10]` | Hình học lưới Hex chuẩn mực, phân vai khắc chế binh chủng, vùng kiểm soát (`ZOC`), bao vây và giá trị bảo toàn quân lực. | Tham chiếu kỷ luật vị trí trên lưới Hex, cơ chế bao vây `TrappedLevel` và tiêu chí 3 Sao giữ tổn thất `<= 20%`. | Tổ chức biên chế sư đoàn cơ giới Thế chiến II, mật độ thông số phức tạp và thời lượng màn chơi quá dài. |
| **Unity of Command II** `[S4]` | Chuyển hóa tuyến hậu cần, trinh sát và sương mù chiến tranh thành bài toán không gian dễ đọc trên bản đồ. | Học cách thể hiện nguy cơ đứt lương thảo (`Starvation` ở `P3`) trực quan trên bản đồ thay vì bảng tính khô khan. | Mô phỏng mạng lưới vận tải cấp chiến dịch quá nặng so với nhịp chơi 10–25 phút trên Web/Mobile. |
| **Hearts of Iron IV** `[S5]` | Khái niệm nguồn phát sinh hậu cần, kho dự trữ và điểm nghẽn giao thông chiến lược. | Tham khảo tư duy đánh cắt kho lương/thuyền lương (như trận Vân Đồn hay kế *Vườn không nhà trống* ở `P3+`). | Hệ thống công nghiệp quốc phòng, cây sản xuất vũ khí và quản trị chính trị vĩ mô cấp quốc gia. |
| **World Conqueror 4** `[S2]`, `[S8]` | Hệ sinh thái 4 chế độ chơi bổ trợ nhau (*Scenario, Conquest, Legion, Domination*). | Khung tham chiếu mở rộng vòng đời sản phẩm hậu MVP trên cùng một bộ luật chiến trường cốt lõi. | Bối cảnh hiện đại, biểu tượng quân sự thế kỷ XX và cấu trúc thương mại hóa cũ. |

---

## A.2. Checklist Đo lường Định lượng UX, Chiến thuật & Hiệu năng

Để tránh đánh giá cảm tính, mọi bản dựng từ mốc **`CP4` / Gate `P2` (Slice-01)** đến **`CP5` / Gate `P5` (Release MVP)** đều phải được đo kiểm trực tiếp trên trình duyệt Web (`gl_compatibility` / Wasm) và thiết bị Android tầm trung theo bảng chỉ số định lượng sau:

| Hạng mục đo lường | Chỉ số mục tiêu chuẩn (Target Metric) | Phương pháp kiểm chứng thực tế |
|---|---|---|
| **1. Chi phí thao tác mỗi hành động (Input Efficiency)** | **`<= 2 chạm / click`** sau khi đã chọn đơn vị để hoàn tất di chuyển hoặc xác nhận tấn công (`Two-Step Combat Confirmation`). | Đếm trực tiếp số thao tác trên cả chuột (Web/Desktop) và màn hình cảm ứng (Android); không phát sinh menu phụ chồng chéo. |
| **2. Độ rõ & Minh bạch của Combat Preview** | Hiển thị đầy đủ **100%** các thông tin quyết định trước khi ra đòn: khoảng sát thương `[Min, Max]` (`Seeded RNG` `80%–100%`), tỷ lệ `% Crit`, dự báo sát thương phản kích (`Retaliation`) và các thẻ modifier chính (Địa hình, Sĩ khí, Khắc chế, `Flank`, `TroopStack`). | Screenshot verification hộp Combat Preview + khảo sát người chơi thử xem có hiểu vì sao sát thương tăng/giảm hay không. |
| **3. Hiệu năng khung hình đa nền tảng (Frame Rate)** | Duy trì ổn định **`>= 60 FPS`** (thời gian vẽ khung hình `<= 16.67 ms`), không tụt quá ngưỡng khi thu phóng toàn cảnh nhờ `StrategicZoom` (`Zoom < 0.7x`). | Đo bằng bộ đếm profiler của Godot 4.7 trên trình duyệt Web và máy Android tầm trung trong kịch bản 20–50 đơn vị hoạt động. |
| **4. Tốc độ phản hồi lượt máy (AI Turn Pacing)** | Toàn bộ lượt đi của phe AI hoàn tất trong **`1.5 – 3.0 giây`** (tính toán ngầm `< 1.5s`, kết hợp lia camera mượt tới điểm giao tranh chính). | Đo log thời gian thực thi AI trong headless simulation 100 trận và ghi hình thực tế trong Slice-01. |
| **5. Tỷ lệ không gian bản đồ (Map-First Screen Ratio)** | Vùng bản đồ chiến trường chiếm **`>= 80%`** diện tích hiển thị màn hình ở trạng thái bình thường; nhận diện tức thì 4 bậc Sĩ khí (`HIGH/NORMAL/LOW/CHAOS`) và ô bãi cọc `StakedWater`. | Kiểm tra bố cục trên cả tỷ lệ `16:9` (Web/PC) và `19.5:9` – `20:9` (Android) qua ảnh chụp màn hình thực tế. |
| **6. Mức độ thấu hiểu luật tự nhiên (`[D-17]`)** | **`>= 4/5` (80%)** người chơi độc lập ngoài nhóm phát triển nêu đúng điều kiện thắng/thua và tự giải thích được nguyên nhân kết quả trận mà không cần dev hướng dẫn miệng. | Biên bản phỏng vấn ngắn ngay sau phiên chơi thử đầu tiên tại Gate `P2`. |

---

## A.3. Bộ câu hỏi sàng lọc tính năng mới (Feature Admission Gate)

Trước khi đề xuất đưa bất kỳ cơ chế mới nào từ các game benchmark vào backlog sản xuất, người thiết kế bắt buộc trả lời đủ 4 câu hỏi:
1. **Quyết định:** Tính năng này tạo ra sự đánh đổi chiến thuật mới nào cho người chơi trong lượt đi?
2. **Bản sắc:** Tính năng này làm nổi bật đặc trưng quân sự / địa hình Việt Nam ở thời kỳ nào?
3. **Độ rõ UX:** Người chơi nhận biết nó trên bản đồ và trong Combat Preview chỉ trong `<= 2 chạm` bằng cách nào?
4. **Kiểm chứng:** Tính năng này có thể kiểm thử tự động bằng headless test và đánh giá qua playtest trong vòng 15 phút hay không?

> *Nếu không trả lời thuyết phục được cả 4 câu hỏi trên, tính năng đó bắt buộc phải hoãn khỏi phạm vi sản xuất hiện tại.*
