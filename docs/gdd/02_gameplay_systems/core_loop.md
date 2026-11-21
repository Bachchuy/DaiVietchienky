# 04. Core Loop và cấu trúc lượt

[← Quay lại Mục lục GDD](../README.md)

---

## 4.1. Vòng lặp chính (Core Loop)

1. **Chọn chế độ và màn chơi:** Lựa chọn Scenario, Conquest, Legion hoặc Domination.
2. **Chuẩn bị trước trận (Briefing & Deployment):** Đọc mục tiêu nhiệm vụ, địa hình, điều kiện 3 sao; bố trí đội hình và gắn tối đa **1 Tướng chỉ huy / đạo quân** trong giới hạn ô tướng (`general_seat`) của kịch bản.
3. **Quan sát và ra lệnh theo lượt:** Đọc thế trận trên lưới Hex, kiểm tra tầm nhìn (LOS), vùng kiểm soát (`ZoC`/`CoC`) và thông số đạo quân trên `UnitInspector` để tự tính toán trước khi ra đòn trực tiếp 1 chạm.
4. **Theo dõi phản ứng chiến trường:** Quan sát đòn phản kích, biến động 4 bậc Sĩ khí, sự kiện kịch bản (`MapPhase` thủy triều, phục binh) và lượt hành động của đối phương.
5. **Tổng kết và tiến trình:** Nhận kết quả Thắng/Thua, đối chiếu nhật ký chiến đấu (`CombatLog`), nhận thưởng tiến trình và mở khóa màn chơi tiếp theo.

---

## 4.2. Battle Loop (Vòng lặp Chiến trường 7 Pha)

Vòng lặp trận đánh vận hành trên **Godot 4.7 (Typed GDScript 2.0)** theo chu trình chuẩn **OnBeginRound → Faction Turn Loop (Player → Ally → Enemy → Neutral) → OnEndRound** (đặc tả kiến trúc lưu trữ tại [data_and_save_system.md](../architecture/data_and_save_system.md) và trạng thái sĩ khí tại [morale_and_status.md](../mechanics/morale_and_status.md)):

| Pha | Tên Pha Kỹ thuật | Xử lý Hệ thống & Điều người chơi nhận biết |
|---|---|---|
| **1. Khởi tạo Vòng** | `OnBeginRound` | Nếu màn chơi bật kinh tế (`enable_economy == true`, phạm vi P3+), thu hoạch tài nguyên từ công trình, khấu trừ `MealFood` và xét `Starvation` (hạ tối đa xuống `LOW`, `-25%` sát thương, khóa hồi HP). Thực thi `ScenarioEvents` đầu vòng và chuyển pha bản đồ `MapPhase` (ví dụ: thủy triều rút lộ bãi cọc). |
| **2. Khởi tạo Lượt Phe** | `FactionTurnStart` | Phe đến lượt được hồi đầy điểm di chuyển (`current_mp = max_mp`), đặt lại trạng thái hành động (`has_acted = false`), lượt phản kích (`has_retaliated_this_round = false`), quyền hoàn tác (`has_used_undo = false`) và giảm `-1` bộ đếm hồi chiêu kỹ năng tướng (`skill_cooldown`). |
| **3. Quan sát & Cân nhắc** | `ObservationAndDecision` | Người chơi kiểm tra thông số đạo quân trên `UnitInspector`, địa hình, LOS/Fog of War và đường đi A* kèm cảnh báo dừng bước `ZoC` / phạt `CoC` để tự ước lượng thế đánh (bỏ bảng tính sẵn `CombatPreview`); AI gọi `plan_turn` nội bộ. |
| **4. Thực thi Mệnh lệnh** | `CommandExecution` | Đóng gói và thực thi các lệnh `BattleCommand`: Di chuyển (`March`), Tấn công (`Attack`), Kỹ năng Tướng (`CastSkill`), Mưu lược Quân sư toàn phe (`ApplyTactic`), Chiêu mộ (`Recruit`), Giao thương khẩn cấp (`Trade`). |
| **5. Giải quyết Tức thì & Xét Thắng/Thua** | `ImmediateResolutionAndVictoryCheck` | Giải quyết hậu quả ngay sau mỗi lệnh: tính sát thương và phản kích, kích hoạt lan truyền tâm lý `NeighboringDeadMates`, xét hợp vây `TrappedLevel 2/3` gây `CHAOS` tức thời, chạy `ScenarioEvents` giữa lượt, **kiểm tra điều kiện Thắng/Thua tức thì** (như hạ Tướng chủ soái, mất cứ điểm sống còn) và ghi Auto-Save Checkpoint. |
| **6. Kết thúc Lượt Phe** | `FactionTurnEnd` | Khi gửi `EndTurn`: xét `TrappedLevel` cuối lượt cho các đơn vị thuộc phe vừa kết thúc lượt (`TrappedLevel 1` giảm `-1 bậc` Sĩ khí); giảm `-1` các bộ đếm khống chế (`chaos_turns`, `attack_disabled_turns`, `march_disabled_turns`, `skill_disabled_turns`) của phe đó. Khi `chaos_turns == 0` và không bị giam trong `TrappedLevel 3`, đơn vị tự hồi phục `CHAOS → LOW`. Chuyển lượt sang phe kế tiếp. |
| **7. Kết thúc Vòng** | `OnEndRound` | Sau khi mọi phe hoàn tất lượt trong vòng: tăng bộ đếm vòng (`current_round += 1`) và kiểm tra giới hạn `max_rounds` (xét thắng phòng thủ trụ vững hoặc thua do quá số vòng quy định). |

---

## 4.3. Nguyên tắc Hành động, Phân quyền Kỹ năng & Replay Tất định

* **Ngân sách hành động mỗi lượt:** Mỗi đạo quân không ở trạng thái `MoraleLevel.CHAOS` có thể di chuyển trong phạm vi `current_mp` (nếu `march_disabled_turns == 0`) rồi thực hiện tối đa **1 hành động chính** (`Attack` hoặc `CastSkill`). Sau hành động chính, đơn vị kết thúc lượt tại chỗ (không cho phép `move – attack – move`).
* **Phân tách `CastSkill` và `ApplyTactic`:**
  * **Kỹ năng Tướng (`CastSkill`):** Gắn với đạo quân có Tướng chỉ huy, dùng bộ đếm hồi chiêu riêng theo lượt (`skill_cooldown`) và điều kiện kích hoạt nội tại — **không tiêu tốn `Mana` chung của phe**.
  * **Mưu lược Quân sư (`ApplyTactic`):** Mệnh lệnh chiến trường cấp toàn phe, tiêu tốn bể tài nguyên **`Mana`** chung của Faction và không làm mất lượt hành động của từng đạo quân riêng lẻ.
* **Quy tắc Hoàn tác 1 bước (`1-Step Undo`):** Trong lượt của mình (`has_used_undo == false`), người chơi được phép hoàn tác lệnh `March` cuối cùng để đưa đơn vị về ô xuất phát **chỉ khi** lệnh di chuyển đó chưa làm lộ thông tin mới từ Fog of War, chưa kích hoạt bẫy/sự kiện ẩn và đơn vị chưa thực hiện `Attack` hay `CastSkill`.
* **Command Pattern & Deterministic Replay:** Mọi `BattleCommand` cùng trạng thái bộ sinh số giả ngẫu nhiên có hạt giống (`rng_seed` và `rng_state` của `RandomNumberGenerator`) đều được tuần tự hóa vào phiên lưu trận đánh, đảm bảo phát lại (Replay) và khôi phục phiên chơi chính xác 100% trên cả Web và Android. Xem chi tiết tại [data_and_save_system.md](../architecture/data_and_save_system.md).
