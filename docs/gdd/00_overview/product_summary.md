# 01. Tóm tắt sản phẩm

[← Quay lại Mục lục GDD](../README.md)

---

**Đại Việt Chiến Kỳ** (*Dai Viet Chronicles*) là trò chơi chiến thuật quân sự theo lượt trên lưới lục giác (*Turn-Based Hex Wargame*), đưa người chơi vào vai người chỉ huy trong các trận đánh và chiến dịch tiêu biểu xuyên suốt lịch sử Việt Nam **từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (Triều Tây Sơn)**. Người chơi đọc địa hình sông ngòi rừng núi, tính toán nhịp thủy triều, thiết lập thế trận bao vây bọc sườn, quản trị 4 bậc sĩ khí và vận dụng năng lực danh tướng để xoay chuyển cục diện chiến trường. Toàn bộ nội dung lịch sử được triển khai cuốn chiếu theo từng **Gói Thời Kỳ (*Era Pack*)** và chỉ được trình bày như dữ kiện lịch sử chính thức sau khi có hồ sơ thẩm định (`Dossier`) được phê duyệt.

**Logline:** Chỉ huy các đạo quân qua hàng nghìn năm lịch sử Việt Nam — từ buổi đầu dựng nước, kháng chiến chống Bắc thuộc đến kỷ nguyên Đại Việt và hào khí Tây Sơn — làm chủ địa hình, thủy triều và thời cơ để biến mọi quyết định chiến thuật thành chiến thắng có thể giải thích.

---

## 1.1. Định dạng và phạm vi sản phẩm

| Thuộc tính | Định hướng chuẩn đã chốt |
|---|---|
| **Thể loại** | Turn-Based Military Strategy / Historical Hex Wargame (Single-player) |
| **Công nghệ & Nền tảng** | **Godot 4.7**, ngôn ngữ **Thuần GDScript 2.0 (Typed GDScript)**, Renderer **`gl_compatibility`**, mục tiêu **60 FPS** trên **Web (HTML5/Wasm) + Android** (phát triển & kiểm thử trên **Windows Desktop**) |
| **Không gian trận đánh** | Bản đồ lưới Hex cạnh nhọn (`Pointy-topped Axial`), nhiều đơn vị gộp cờ (`TroopStack` 1x–3x), lượt người chơi và AI luân phiên, bảng **`UnitInspector`** hiện thông số thô từng đạo quân, **đánh ngay 1 chạm** và cơ chế **`Seeded RNG`** (`80%–100%` + Crit, 100% Deterministic Replay) |
| **Vertical Slice đầu tiên (Mốc P2)** | **Slice-01: Đại Chiến Bạch Đằng 1288 (`stage_id: 10101`)** — bản đồ `12 × 10` hex, tối đa 10 lượt, Đại Việt đối đầu **Đại Nguyên (Quân Nguyên)**, sự kiện thủy triều rút đầu Vòng 4; ẩn kinh tế (`enable_economy = false`, thuộc P3); gắn nhãn `fixture / gameplay abstraction` |
| **Phạm vi Release MVP (Mốc P5)** | **Gói Chiến dịch Thời Trần** hoàn chỉnh (6–8 màn lịch sử, 10–12 binh chủng, 8–10 danh tướng, Tutorial theo tình huống & Codex lịch sử) phát hành trên Web + Android + Windows Desktop |
| **Phạm vi lịch sử dài hạn** | Triển khai cuốn chiếu theo từng *Era Pack* **từ thời dựng nước & Bắc thuộc (Văn Lang – Âu Lạc, Hai Bà Trưng, Bà Triệu, Lý Bí, Ngô Quyền) qua Đinh – Tiền Lê – Lý – Trần – Hồ – Lê Sơ đến thế kỷ XVIII (Tây Sơn)** |
| **Định hướng thương mại hóa (`D-07`)** | Không có Gacha trong Slice-01 và MVP; ở giai đoạn mở rộng (P4+), áp dụng mô hình **F2P thân thiện** (người chơi tích lũy Ngọc Bích & Lệnh Chiêu Mộ qua thành tựu/3 sao/sự kiện để sở hữu mọi phẩm tướng kể cả bậc Đỏ, **không khóa cứng danh tướng lịch sử sau paywall tiền thật**; khóa hồ sơ tướng `Preset Loadout` trong Historical Scenario) |

---

## 1.2. Phạm vi lịch sử và nguyên tắc phân tách kịch bản

Danh mục các thời kỳ, chiến dịch và danh tướng dài hạn được quản lý theo lộ trình *Era Pack*, không sản xuất dàn trải cùng lúc và không tự động tuyên bố mọi chi tiết thiết kế là sự thật lịch sử khi chưa hoàn tất thẩm định. Mỗi *Era Pack* phải xây dựng bộ hồ sơ `Dossier` độc lập xác định rõ niên đại, thế lực đối chiến, danh xưng đương thời, biên chế binh chủng, địa mạo và các vùng còn tranh luận sử học (xem [historical_framework.md](../03_content_presentation/historical_framework.md)).

Đặc biệt, ba trận thủy chiến trên sông **Bạch Đằng (938, 981 và 1288)** bắt buộc được phát triển thành các kịch bản và hồ sơ lịch sử hoàn toàn tách biệt, tuyệt đối không dùng chung một bản đồ, biên chế hay nguồn tư liệu chỉ vì trùng địa danh:
- **Bạch Đằng 938** (Ngô Quyền đánh tan quân Nam Hán): tham chiếu nguồn mộc bản `[S7]` và tổng quan `[S6]`.
- **Bạch Đằng 1288** (Quân dân nhà Trần đại thắng hạm đội **Đại Nguyên** do Ô Mã Nhi, Phàn Tiếp chỉ huy — trọng tâm của **Slice-01**): đối chiếu chéo từ hệ thống nguồn chính sử Việt Nam – Trung Hoa và báo cáo khảo cổ học thực địa `[S6]`, `[S12]`, `[S13]`, `[S14]`, `[S15]`, `[S16]` tại [Phụ lục B](../appendices/appendix_b_sources.md). Các chi tiết bố cục lưới Hex `12 × 10` và thông số chiến đấu trong Slice-01 hiện được gắn nhãn rõ là `fixture / gameplay abstraction` và `[CẦN THẨM ĐỊNH]` cho đến khi hoàn tất Gate `P2`.
