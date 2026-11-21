# 10. Nội dung lịch sử và quy trình thẩm định

[← Quay lại Mục lục GDD](../README.md)

---

## 10.1. Phạm vi Lịch sử & Tính toàn vẹn sử liệu (Historical Scope & Integrity)

### Phạm vi thời đại toàn dự án
**Đại Việt Chiến Kỳ** bao quát tiến trình lịch sử quân sự Việt Nam **từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (Triều Tây Sơn)** — trải dài từ các cuộc khởi nghĩa giành tự chủ thời Bắc thuộc (Hai Bà Trưng, Bà Triệu, Lý Bí – Đầm Dạ Trạch, Mai Thúc Loan, Phùng Hưng), bước ngoặt độc lập Ngô Quyền (938), Tiền Lê (981), Lý, Trần, Hồ, Khởi nghĩa Lam Sơn – Lê Sơ (thế kỷ XV), cho tới các chiến dịch thần tốc thời Tây Sơn cuối thế kỷ XVIII. Việc mở rộng nội dung được thực hiện cuốn chiếu theo từng chương chiến dịch sau khi hoàn tất kiểm chứng cơ chế tại Vertical Slice (Slice-01).

### Hệ thống phân hạng chứng cứ (Evidence Grade) & Nhãn mô hình hóa (`modeling_type`)
Mỗi dữ kiện lịch sử (`claim`) quan trọng đưa vào game phải gắn `source_ref` (đối chiếu danh mục tại [appendix_b_sources.md](../appendices/appendix_b_sources.md)) và phân hạng chứng cứ **A / B / C / D**, đồng thời ghi người rà soát cùng trạng thái duyệt trong hồ sơ màn chơi (dossier). **Evidence grade áp dụng cho từng claim cụ thể, không gán chung cho toàn bộ một cuốn sử:**
- **Grade A:** Bằng chứng mạnh, được đối chiếu chéo từ nhiều nguồn sơ cấp và/hoặc tư liệu khảo cổ học độc lập (`[S12]`, `[S13]`, `[S14]`, `[S15]`, `[S16]`).
- **Grade B:** Bằng chứng đáng tin cậy từ chính sử hoặc khảo cứu học thuật nhưng còn giới hạn về chi tiết chiến thuật cục bộ.
- **Grade C:** Bằng chứng gián tiếp, truyền thuyết địa phương hoặc còn mâu thuẫn đáng kể giữa các nguồn sử liệu.
- **Grade D:** Chưa xác minh hoặc không đủ căn cứ học thuật; tuyệt đối không trình bày như sự thật lịch sử (`fact`) trong Historical Mode.

Trường **`modeling_type`** được tách bạch hoàn toàn khỏi Evidence Grade và bắt buộc khai báo trong dữ liệu kịch bản:
- `historical_claim`: Phản ánh trực tiếp dữ kiện lịch sử đã được thẩm định.
- `abstraction` (Gameplay Abstraction): Đơn giản hóa, gộp lực lượng hoặc co giãn không gian – thời gian để tạo quyết định chiến thuật theo lượt rõ ràng.
- `fixture`: Cấu hình thử nghiệm cơ chế (như bố cục ô hex, chỉ số máu, lượt rút triều cố định của Slice-01).
- `what_if` / `fictional`: Nhánh giả định lịch sử hoặc hư cấu bổ trợ; phải gắn nhãn minh bạch trên UI/Codex và tách biệt khỏi chính sử.

> **Nguyên tắc bất di bất dịch:** Tuyệt đối không nâng khống Evidence Grade để hợp thức hóa thiết kế gameplay. Mọi chi tiết chưa hoàn tất đối chiếu sử liệu phải ghi rõ `[CẦN THẨM ĐỊNH]`.

---

## 10.2. Quy trình biên soạn & thẩm định nội dung

```
Nguồn sử liệu sơ cấp & Khảo cổ ([S6], [S7], [S12]–[S16])
  ➔ Lập Dossier trận đánh & tách từng claim gắn source_ref
  ➔ Chấm Evidence Grade (A/B/C/D) cho từng claim
  ➔ Khai báo modeling_type riêng (historical_claim / abstraction / fixture / what_if)
  ➔ Chuyển hóa thành cơ chế bản đồ, binh chủng & sự kiện kịch bản
  ➔ Kiểm duyệt Briefing, Lời thoại & mục từ Codex (Era-gating vũ khí/danh xưng)
  ➔ Phê duyệt phát hành & lưu vết thay đổi
```

Mỗi hồ sơ trận đánh (Scenario Dossier) phải xác định rõ: niên đại, quốc hiệu hai phe đương thời, địa danh cổ – kim, danh sách chỉ huy chính thống, mục tiêu chiến lược, diễn biến chính, đặc điểm thủy văn – địa hình, nguồn tham chiếu (`[S6]`, `[S7]`, `[S12]`–`[S16]`) và các điểm còn tranh luận học thuật. Thiết kế màn chơi **không được gộp chung các trận đánh khác thời đại dù diễn ra trên cùng một địa danh**; đồng thời phải kiểm soát chặt **Phân kỳ thời đại (`Era-gating`)** đối với vũ khí (ví dụ: Súng Thần Cơ / Hỏa pháo chỉ xuất hiện từ thời Hồ – Lê Sơ thế kỷ XV trở đi, tuyệt đối không xuất hiện ở các trận thế kỷ X–XIII).

---

## 10.3. Phân biệt Bạch Đằng 938, 981, 1288 & Chuẩn hóa Thẩm định Slice-01

Sông Bạch Đằng gắn liền với ba trận đại thủy chiến ở ba triều đại khác nhau (**Ngô Quyền đánh quân Nam Hán năm 938** `[S7], [S12]`; **Lê Hoàn phá quân Tống năm 981** `[S6], [S12]`; và **Nhà Trần đại phá quân Đại Nguyên năm 1288** `[S6], [S12], [S13], [S14], [S15], [S16]`). Mỗi trận bắt buộc có dossier, biên chế binh chủng, thế trận và điều kiện thắng riêng biệt.

### Hồ sơ thẩm định chuẩn cho Slice-01: Đại Chiến Bạch Đằng 1288 (`stage_id: 10101`)

1. **Chuẩn hóa Quốc hiệu & Mã thời kỳ (`historical_claim` — Grade A, `[S12], [S13], [S14]`):**
   - Năm 1271, Hốt Tất Liệt đã chính thức đặt quốc hiệu là **Đại Nguyên**. Vì vậy, trong cuộc kháng chiến lần thứ ba (1287–1288), phe đối phương bắt buộc định danh chuẩn là **`"Đại Nguyên (Quân Nguyên)"`** và mã thời kỳ trong dữ liệu `StageDef` (`.tres`) là **`"Tran_Nguyen"`** (không gộp chung danh xưng với giai đoạn đế quốc Mông Cổ năm 1258).

2. **Chỉ huy lịch sử vs. Trừu tượng hóa Phó tướng trong Slice-01 (`abstraction` / `fixture`):**
   - **Dữ kiện chính sử (`[S12]` *Đại Việt Sử Ký Toàn Thư*, `[S13]` *An Nam Chí Lược*, `[S14]` *Nguyên Sử*):** Tại đại chiến sông Bạch Đằng ngày 8 tháng 3 năm Mậu Tý (9/4/1288), lực lượng Đại Việt do **Quốc công Tiết chế Hưng Đạo Vương Trần Quốc Tuấn** tổng chỉ huy cùng **Thượng hoàng Trần Thánh Tông**, **Vua Trần Nhân Tông** và các tướng lĩnh như **Nguyễn Khoái** (chỉ huy quân Thánh Dực), **Phạm Ngũ Lão**, **Trần Nhật Duật**... chặn đánh hạm đội rút lui của **Ô Mã Nhi (Omar)**, **Phàn Tiếp**, **Tích Lệ Cơ Ngọc**. Trong khi đó, **Nhân Huệ Vương Trần Khánh Dư** nổi danh với chiến thắng quyết định tiêu diệt đoàn thuyền lương của Trương Văn Hổ tại **Vân Đồn (cuối năm 1287 – đầu 1288)** tạo tiền đề buộc quân Nguyên phải rút lui đường thủy qua Bạch Đằng.
   - **Nhãn thiết kế trong Slice-01 (`modeling_type: "abstraction"` / `"fixture"`):** Việc đưa **Trần Khánh Dư** vào vị trí phó tướng thủy quân sát cánh cùng Trần Quốc Tuấn ngay trong màn `battle_10101` được gắn nhãn minh bạch là **`abstraction` / `fixture`** (cô đọng hai mắt xích thủy chiến Vân Đồn – Bạch Đằng vào một sa bàn Vertical Slice duy nhất để kiểm thử cơ chế phối hợp 2 tướng chỉ huy có kỹ năng riêng). Khi mở rộng chiến dịch thời Trần ở giai đoạn Alpha/Beta (P3+), trận **Vân Đồn** sẽ được tách thành màn kịch bản độc lập cho Trần Khánh Dư, và đội hình Bạch Đằng 1288 sẽ trả về đúng các tướng Nguyễn Khoái, Phạm Ngũ Lão theo chính sử.

3. **Bãi cọc ngầm, Thủy triều & Sa bàn `12 × 10` hex (`fixture` / `abstraction`, `[S12], [S15], [S16]`):**
   - Các phát hiện khảo cổ học tại bãi cọc **Yên Giang – Đồng Vạn Muối – Đồng Má Ngựa (Quảng Yên, Quảng Ninh)** `[S15]` và **Cao Quỳ – Đầm Thượng (Thủy Nguyên, Hải Phòng)** `[S16]` cho thấy hệ thống trận địa cọc phân bố thành nhiều dải khóa các lạch triều và cửa nhánh sông, không phải một hàng cọc chắn ngang giữa dòng sông sâu duy nhất.
   - Trong Slice-01, lưới bản đồ **`12 × 10` hex (Pointy-topped Axial)** là một **sa bàn phóng đại chiến thuật (`Tactical Zoom-in Map`)**, trong đó vùng cọc `area_bai_coc`, cứ điểm Bến Hiệu Lệnh `SignalDock (2, 8)` và nhịp rút triều cố định ở **đầu Vòng 4 (`MapPhase_TideFall`)** đều được gắn nhãn **`modeling_type: "fixture"`** nhằm phục vụ nhịp độ chiến thuật 10 lượt rõ ràng, có thể đọc hiểu và phản ứng được.

> 📖 **Liên kết đặc tả dữ liệu & nguồn sử liệu:**
> - Chi tiết cấu trúc kịch bản `stage_10101.tres` + `stage_10101_map.tscn` (Resource `.tres` + `TileMapLayer`), điều kiện Thắng/Thua, 3 Sao và hệ thống sự kiện: xem [scenario_scripting_and_events.md](../level_design/scenario_scripting_and_events.md).
> - Danh mục nguồn tham khảo lịch sử, khảo cổ học và benchmark (`[S1]`–`[S16]`): xem [appendix_b_sources.md](../appendices/appendix_b_sources.md).
