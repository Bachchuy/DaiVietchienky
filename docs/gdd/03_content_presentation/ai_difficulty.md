# 12. AI và độ khó

[← Quay lại Mục lục GDD](../README.md)

---

## 12.1. Triết lý thiết kế AI chiến thuật

AI máy trong **Đại Việt Chiến Kỳ** vận hành trên cùng bộ luật chiến trường và chịu cùng giới hạn thông tin sương mù chiến tranh (`Fog of War`) như người chơi:
- **Không gian thông tin trung thực (Zero Map-Hack):** Hàm lập kế hoạch của AI chỉ được đọc dữ liệu từ khung nhìn hợp lệ của phe mình (`AIVisibleMapView`). AI **tuyệt đối không nhìn xuyên Fog of War** và **không được biết trước các bẫy ẩn chưa kích hoạt** (ví dụ tại Slice-01 Bạch Đằng 1288: trước Vòng 4 khi thủy triều chưa rút, vùng `area_bai_coc` vẫn là mặt nước thông thường nên AI không né tránh trước; AI chỉ nhận diện và né ô `StakedWater` sau khi sự kiện `MapPhase_TideFall` đã lộ diện bãi cọc!).
- **Kiến trúc Utility AI 3 giai đoạn & 5 Bộ Chấm Điểm (Evaluators):** Tạo sinh ứng viên hợp lệ (`Generators`) $\rightarrow$ Chấm điểm qua **5 Evaluators** (`ReachableAreaEvaluator`, `AttackTargetEvaluator`, `ObjectiveEvaluator`, `StatusEffectEvaluator`, `ManaEfficiencyEvaluator`) $\rightarrow$ Cộng nhiễu ngẫu nhiên có kiểm soát từ `RandomNumberGenerator` có seed của trận đấu để giữ tính tất định khi Replay/Resume.
- **Kết nối chặt với `ScenarioDirector` qua `ObjectiveEvaluator`:** AI không chỉ lao vào đánh gần nhất mà biết cân nhắc chiếm giữ/phòng thủ cứ điểm kịch bản (như `SignalDock (2, 8)`) và săn tìm hoặc hộ vệ Tướng mục tiêu (như Ô Mã Nhi / Trần Quốc Tuấn).
- **Conquest AI (Chiến lược vĩ mô):** Nằm ngoài phạm vi Slice-01, sẽ được đặc tả riêng khi mở chế độ Conquest ở các cột mốc sau (P3+).

> 📖 **Đặc tả toán học & mã nguồn GDScript 2.0 chi tiết:** xem [ai_decision_matrix.md](../ai/ai_decision_matrix.md).

---

## 12.2. Bốn cấp độ khó chuẩn (`AIDifficultyProfile`)

Thay vì gian lận chỉ số ngầm hay nhìn xuyên bản đồ, 4 cấp độ khó được cấu hình hướng dữ liệu qua Resource `AIDifficultyProfile` với bộ 4 trọng số vĩ mô `(w_atk, w_pos, w_obj, w_skill)` và biên độ nhiễu cộng tính `noise_amp` ($\eta_{\text{RNG}} \in [-\text{noise\_amp}, +\text{noise\_amp}]$):

| Cấp độ khó | Trọng số `(w_atk, w_pos, w_obj, w_skill)` | Nhiễu cộng tính `noise_amp` | Đặc trưng hành vi & Quy tắc kịch bản |
| :--- | :---: | :---: | :--- |
| **Easy (Dễ)** | `(0.50, 0.15, 0.20, 0.15)` | **`±18.0` điểm** | Hỗ trợ người chơi mới làm quen luật: AI thiên về tấn công trực diện đơn giản, ít kẹp sườn, đôi khi bỏ lỡ nước đi tối ưu do biên độ nhiễu cao; không gian lận tài nguyên. |
| **Normal (Thường)** | `(0.35, 0.25, 0.25, 0.15)` | **`±6.0` điểm** | Cấp độ chuẩn cân bằng: AI biết đọc khắc chế binh chủng, giữ cự ly cung nỏ, phối hợp dồn sát thương kết liễu và bám sát cứ điểm mục tiêu (`ObjectiveEvaluator`), tạo biến số tự nhiên giữa các lần chơi. |
| **Hard (Khó)** | `(0.30, 0.25, 0.25, 0.20)` | **`±1.5` điểm** | Bậc thầy chiến thuật: AI tính toán sắc bén gần như tối ưu, tích cực lập thế bao vây Pincer, tận dụng địa hình phòng thủ, tung kỹ năng khống chế đúng nhịp và gây sức ép liên tục lên cứ điểm then chốt nhưng **vẫn tuân thủ nghiêm ngặt Fog of War**. |
| **Challenge (Thử thách)** | `(0.28, 0.27, 0.25, 0.20)` | **`±0.5` điểm** | Chế độ thử thách danh tướng: Kết hợp bộ não chiến thuật chuẩn xác nhất với **các biến số kịch bản khắc nghiệt được công bố minh bạch ngay tại Briefing** (ví dụ: giới hạn vòng ngắn hơn, tiếp viện địch đến sớm hơn 1 vòng hoặc sĩ khí khởi đầu của giặc cao hơn), tuyệt đối không tăng lén HP/ATK ảo sau lưng người chơi. |
