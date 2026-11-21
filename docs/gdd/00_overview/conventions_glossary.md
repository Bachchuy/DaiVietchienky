# 00. Quy ước đọc tài liệu và thuật ngữ

[← Quay lại Mục lục GDD](../README.md)

---

Bộ tài liệu GDD này là nguồn chân lý duy nhất (*Single Source of Truth*) cho cả thiết kế trải nghiệm lẫn đặc tả hệ thống của **Đại Việt Chiến Kỳ**:
- Tầm nhìn, luật gameplay tổng quát và quy trình thẩm định lịch sử nằm tại các thư mục `00_overview/` đến `03_content_presentation/`.
- Công thức toán học, cấu trúc dữ liệu `Resource` (`.tres`), thuật toán AI và pipeline kết xuất nằm trực tiếp trong các micro-modules chuyên sâu: [combat_formulas.md](../mechanics/combat_formulas.md), [morale_and_status.md](../mechanics/morale_and_status.md), [hex_grid_pathfinding.md](../mechanics/hex_grid_pathfinding.md), [data_and_save_system.md](../architecture/data_and_save_system.md), [ai_decision_matrix.md](../ai/ai_decision_matrix.md), [battle_ui_and_rendering.md](../ui_ux/battle_ui_and_rendering.md) và [scenario_scripting_and_events.md](../level_design/scenario_scripting_and_events.md).
- Phạm vi MVP, quản trị rủi ro và lộ trình kỹ thuật `R1–R5` (`CP6–CP10`) / `CP1–CP5` nằm tại [production_scope_mvp.md](../04_production_roadmap/production_scope_mvp.md), [risks_open_decisions.md](../04_production_roadmap/risks_open_decisions.md) và [implementation_plan.md](../04_production_roadmap/implementation_plan.md).
- Lịch sử tiến hóa phiên bản và bảng ánh xạ tách module nằm trong [CHANGELOG_3.3_to_3.4.md](CHANGELOG_3.3_to_3.4.md).

---

## Quy ước đọc (Normative Keywords)

- **MUST**: Yêu cầu thiết kế hoặc kỹ thuật bắt buộc tuân thủ 100% trong phạm vi đã khóa (`LOCKED`).
- **SHOULD**: Định hướng chuẩn khuyến nghị mạnh; chỉ điều chỉnh khi có số liệu playtest hoặc lý do thiết kế được duyệt.
- **MAY**: Tính năng hoặc biến thể tùy chọn theo từng kịch bản (`Scenario`) hoặc chế độ chơi (`Game Mode`).
- **OPEN**: Hạng mục chưa khóa cứng, có phương án mặc định (*Default*), người phụ trách (*Owner*) và hạn chốt cụ thể tại [risks_open_decisions.md](../04_production_roadmap/risks_open_decisions.md).
- **Fixture**: Dữ liệu hoặc thông số mồi dùng để dựng nguyên mẫu và kiểm thử luật chơi; không được coi là thông số cân bằng cuối cùng hay sự thật lịch sử đã duyệt.
- **Quy ước toàn vẹn lịch sử**: Mọi tuyên bố lịch sử chính thức phải đính kèm `sourceRef` (trỏ tới [Phụ lục B](../appendices/appendix_b_sources.md)) và `Evidence grade` (`A/B/C/D`). Độ vững bằng chứng (`Evidence grade`) tách biệt hoàn toàn với nhãn mô hình hóa (`ModelingType`: `historical claim`, `gameplay abstraction`, `What-if`, `fictional`). Nội dung chưa qua thẩm định bắt buộc gắn nhãn `[CẦN THẨM ĐỊNH]` hoặc `fixture / gameplay abstraction`.

---

## Glossary (Thuật ngữ nền tảng — Core Glossary)

Bảng dưới đây định nghĩa các khái niệm nền tảng xuất hiện xuyên suốt toàn bộ GDD. Các thuật ngữ chuyên sâu về công thức, hiệu ứng không gian, dữ liệu kịch bản và thẩm định lịch sử được định nghĩa riêng (không trùng lặp) tại [Phụ lục C: Glossary mở rộng](../appendices/appendix_c_extended_glossary.md).

| Thuật ngữ | Nghĩa chuẩn dùng trong GDD |
|---|---|
| **Action** | Lệnh hành động chính của một đơn vị trong lượt (như tấn công, thi triển kỹ năng hoặc phòng thủ tại chỗ); theo quy tắc chuẩn, sau khi thực hiện Action chính, đơn vị kết thúc lượt của mình. |
| **Controlled RNG (`Seeded RNG`)** | Cơ chế ngẫu nhiên có kiểm soát và có hạt giống tất định: lực đánh cơ bản dao động trong dải `80%–100%` kèm tỷ lệ Bạo kích (`Crit`), không có đánh trượt (`miss`) ngẫu nhiên; người chơi tự cân nhắc dựa trên thông số từng đạo quân trong `UnitInspector` trước khi chạm 1 lần để ra đòn (không hiện bảng tính sẵn sát thương), còn `seed/state` được lưu trong `RandomNumberGenerator` riêng để đảm bảo **100% Deterministic Replay**. |
| **Core Loop** | Chuỗi hoạt động cốt lõi lặp lại tạo nên trải nghiệm trung tâm của trò chơi (Đọc tình thế & chuẩn bị $\to$ Điều quân chiến thuật theo lượt $\to$ Xử lý bước ngoặt chiến trường $\to$ Tổng kết & mở khóa lịch sử). |
| **Era Pack** | Gói nội dung lịch sử phát triển cuốn chiếu theo từng thời kỳ (khởi đầu bằng Gói Thời Trần ở MVP, sau đó mở rộng từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII — Triều Tây Sơn). |
| **Fixture** | Bộ thông số hoặc kịch bản mẫu phục vụ kiểm thử nguyên mẫu (prototype/playtest) trước khi cân bằng cuối hoặc thẩm định sử học hoàn tất. |
| **Hex Axial (`q, r`)** | Hệ lưới lục giác cạnh nhọn (*Pointy-topped Axial Grid*) dùng làm không gian bản đồ chiến trường chuẩn, bảo đảm 6 hướng tiếp cận đồng đều. |
| **LOS (Line of Sight)** | Đường ngắm thông thoáng cần thiết để quan sát mục tiêu hoặc phát động đòn tấn công/phản kích tầm xa; bị che khuất bởi rừng rậm hoặc đồi núi tùy luật địa hình. |
| **Morale (Sĩ khí)** | Trạng thái tinh thần tổ chức của đơn vị, biểu diễn bằng **4 bậc Enum rời rạc**: `HIGH` (Hưng Phấn), `NORMAL` (Ổn Định), `LOW` (Dao Động) và `CHAOS` (Hỗn Loạn — khóa hành động tạm thời theo lượt rồi tự hồi về `LOW`); không sử dụng thang điểm phần trăm liên tục. |
| **MP (Movement Points)** | Ngân sách điểm di chuyển mà đơn vị có thể tiêu hao để đi qua các ô địa hình trong một lượt. |
| **Scenario** | Màn chơi lịch sử được biên tập có bối cảnh, phe phái, địa hình, chuỗi sự kiện kịch bản và điều kiện thắng/3 sao xác định. |
| **Slice-01** | Vertical slice đầu tiên của dự án (Mốc `P2`): màn **Đại Chiến Bạch Đằng 1288 (`stage_id: 10101`)**, bản đồ `12 × 10` hex, tối đa 10 lượt, ẩn lớp kinh tế (`enable_economy = false`). |
| **Supply (Hậu cần)** | Hệ thống duy trì lương thảo và khả năng tác chiến của đạo quân trong trận đánh hoặc chiến dịch dài ngày *(thuộc phạm vi P3 Alpha, không bật trong Slice-01)*. |
| **ZOC (Zone of Control)** | Vùng kiểm soát bao phủ 6 ô Hex liền kề của mỗi đơn vị đang còn tổ chức (không ở trạng thái `CHAOS`), buộc đơn vị đối phương bước vào phải dừng di chuyển ngay lập tức (`RemainingMP = 0`). |

> Tra cứu tiếp hơn 20 thuật ngữ cơ chế chuyên sâu (`TroopStack`, `TrappedLevel`, `StakedWater`, `SignalDock`, `Flank`, `CHAOS`, `Retaliation`, `IgnoreZoc`, `DevoidZoc`, `CoC`, `FondTerrain`, `Starvation`, `MealFood`, `Fetters`, `UniqueSkill`, `CommandProfile`, `Dossier`, `ModelingType`, `sourceRef`, `StrategicZoom`,...) tại [Phụ lục C: Glossary mở rộng](../appendices/appendix_c_extended_glossary.md).
