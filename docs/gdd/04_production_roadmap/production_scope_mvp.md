# 14. Phạm vi sản xuất, Slice-01, Release MVP và tiêu chí nghiệm thu

[← Quay lại Mục lục GDD](../README.md)

---

## 14.1. Nguyên tắc quản trị phạm vi sản xuất

- **Lộ trình lịch sử cuốn chiếu theo *Era Pack*:** Tầm nhìn tổng thể của sản phẩm trải dài **từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (Triều Tây Sơn)**, nhưng tuyệt đối không sản xuất dàn trải nhiều thời kỳ cùng lúc. Đội ngũ bắt buộc hoàn thành và kiểm chứng **Slice-01: Đại Chiến Bạch Đằng 1288 (Mốc P2)** trước khi mở rộng thành **Gói Chiến dịch Thời Trần hoàn chỉnh (Release MVP — Mốc P5)**, sau đó mới phát triển cuốn chiếu các *Era Pack* tiếp theo.
- **Đồng nhất nền tảng công nghệ ngay từ đầu (`D-06`, `D-09`, `D-10`):** Phát triển bằng **Thuần GDScript 2.0 (Typed GDScript)** trên **Godot 4.7** với renderer **`gl_compatibility`**, duy trì chuẩn **60 FPS** xuyên suốt từ môi trường kiểm thử **Windows Desktop** sang hai nền tảng phân phối trọng tâm là **Web (HTML5/Wasm) và Android**.
- **Thứ tự ưu tiên sản xuất bất biến:**  
  `Cảm giác điều quân đầm tay` ➔ `Thông số rõ trên UnitInspector & Đánh ngay 1 chạm` ➔ `Ổn định 60 FPS đa nền tảng` ➔ `Khả năng biên tập màn chơi trong Editor (.tres + TileMapLayer)`.

---

## 14.2. Milestone thiết kế & sản xuất (`P0–P5`)

| Milestone | Checkpoint Kỹ thuật tương ứng | Trọng tâm thiết kế & Nội dung | Tiêu chí vượt cổng (Exit Criteria) |
|---|---|---|---|
| **P0 — Paper / Greybox Prototype** | `CP1` | Lưới Hex `Pointy-topped Axial`, địa hình cơ bản, camera 60 FPS và mô phỏng bàn cờ cốt lõi. | Kiểm chứng tỷ lệ bản đồ `12 × 10`, độ dễ đọc của 6 hướng tiếp cận và thao tác chạm/click cơ bản. |
| **P1 — Core Tactical Prototype** | `CP2` | Vòng lặp 7 pha, Combat `Seeded RNG`, giáp `100/(100+EffectiveDef)`, 4 bậc Sĩ khí Enum, ZoC & Phản kích. | Đánh trọn vẹn 1 trận thử nghiệm từ đầu đến kết thúc; Undo 1 bước và Deterministic Replay chạy chính xác 100%. |
| **P2 — Vertical Slice (Slice-01)** | `CP3` + `CP4` | Hoàn chỉnh 1 màn **Bạch Đằng 1288 (`stage_id: 10101`)** với AI Utility, `MapPhase_TideFall` Vòng 4, UI/Audio Polish và nhãn lịch sử chuẩn. | Đạt cả `CP4` kỹ thuật lẫn nghiệm thu Playtest độc lập `[D-17]` (`>= 4/5` người chơi ngoài dev hiểu rõ luật & nguyên nhân thắng/thua). |
| **P3 — Alpha (Systems Expansion)** | Nền tảng mở rộng sau `CP4` | Bật hệ thống **Kinh tế Chiến trường & Lương thảo** (`enable_economy = true`: `Coin, Food, Tech, Mana`, `MealFood`, `Starvation`), `CommandProfile` và 3–4 màn thử nghiệm chuỗi chiến dịch. | Vòng lặp hậu cần tạo quyết định cắt lương/giữ kho rõ nét mà không làm chậm nhịp trận đánh quá 25 phút. |
| **P4 — Beta (Content & Platform Complete)** | Tiến tới `CP5` | Hoàn thiện toàn bộ nội dung Gói Thời Trần, Tutorial, Codex; vượt **Asset IP Gate** (thay sạch 100% placeholder); tối ưu bộ nhớ WebAssembly & cảm ứng Android; chuẩn bị khung meta F2P thân thiện (`D-07`) cho lộ trình mở rộng. | Toàn bộ kịch bản Thời Trần có `Dossier` được duyệt; đạt chuẩn 60 FPS ổn định trên trình duyệt Web và thiết bị Android mục tiêu. |
| **P5 — Release MVP (1.0 Launch)** | Hoàn tất `CP5` | Phát hành chính thức **Gói Chiến dịch Thời Trần** hoàn chỉnh trên **Web + Android + Windows Desktop** (không chứa Gacha). | Không còn lỗi nghiêm trọng (Crash/Soft-lock/Desync), vượt qua Release QA, kiểm duyệt lịch sử và sẵn sàng vận hành thực tế. |

---

## 14.3. Phạm vi Slice-01 (Mốc P2 — Vertical Slice Bạch Đằng 1288)

Slice-01 tập trung toàn lực vào **duy nhất 01 màn chơi hoàn chỉnh** để chứng minh chất lượng cốt lõi của trò chơi (xem cấu trúc kịch bản `.tres` & `TileMapLayer` tại [scenario_scripting_and_events.md](../level_design/scenario_scripting_and_events.md) và [data_and_save_system.md](../architecture/data_and_save_system.md)):

- **Định danh kịch bản:** `stage_id: 10101` — **Đại Chiến Bạch Đằng 1288**.
- **Không gian & Thời lượng:** Bản đồ **`12 × 10` hex** (`Pointy-topped Axial`), giới hạn tối đa **10 lượt** (`MaxRounds = 10`).
- **Phe phái đối chiến:**
  - Phe người chơi: **Đại Việt** (Quân dân nhà Trần — giữ thế chủ động giăng bẫy thủy triều và bảo vệ cứ điểm).
  - Phe AI đối phương: **Đại Nguyên (Quân Nguyên)** (Hạm đội rút lui đường thủy do Ô Mã Nhi thống lĩnh).
- **Biên chế & Tướng lĩnh (`Preset Loadout` — `D-02`):** 4–5 archetype binh chủng đặc trưng (Chiến thuyền chủ lực, Thuyền nhẹ/Mông đồng hỏa công, Bộ binh giữ bến, Cung/Nỏ yểm trợ bờ sông), 1–2 danh tướng gắn `UniqueSkill` (Trần Quốc Tuấn, Ô Mã Nhi), sử dụng cơ chế gộp cờ `TroopStack` (`1x–3x`).
- **Hệ thống Chiến đấu & Sĩ khí chuẩn:**
  - **Controlled RNG có Seed tất định (`Seeded RNG`):** Biên độ sát thương `80%–100%` + Bạo kích (`Crit`), công thức giáp chuẩn `100 / (100 + EffectiveDef)`, làm tròn `RoundHalfUp`, lưu `seed/state` bảo đảm **100% Deterministic Replay** (không có đánh trượt ngẫu nhiên). Bỏ hộp dự báo sát thương `CombatPreview`: người chơi xem thông số từng đạo quân trên **`UnitInspector`** để tự tính và **chạm 1 lần vào địch trong tầm Đỏ để đánh ngay** như `HexCrown`.
  - **Sĩ khí 4 bậc Enum rời rạc:** `HIGH` (Hưng Phấn), `NORMAL` (Ổn Định), `LOW` (Dao Động), `CHAOS` (Hỗn Loạn — khóa di chuyển, tấn công, phản kích và mất ZoC tạm thời theo lượt rồi tự hồi về `LOW`).
- **Trạng thái Kinh tế / Lương thảo:** **Ẩn hoàn toàn trong Slice-01 (`enable_economy = false`)** — toàn bộ 4 tài nguyên trong trận (`Coin, Food, Tech, Mana`), tiêu hao `MealFood` và `Starvation` được khóa lại cho **Mốc P3 Alpha** ([battlefield_economy.md](../mechanics/battlefield_economy.md)) để người chơi tập trung tuyệt đối vào vị trí, nhịp con nước và bao vây.
- **Nhãn toàn vẹn lịch sử:** Các thông số tọa độ ô Hex, số lượng đơn vị, chỉ số chiến đấu và lời thoại sự kiện trong Slice-01 hiện được gắn nhãn rõ ràng là **`fixture / gameplay abstraction`** cho đến khi hội đồng cố vấn duyệt xong `Dossier` chính thức theo nguồn `[S12]–[S16]`.

### Nhịp sự kiện 3 hồi & Bước ngoặt Thủy triều rút (`MapPhase_TideFall`)
1. **Hồi 1 (Vòng 1–3 — Nhử địch vào thế trận):** Đại quân **Đại Nguyên** ồ ạt tiến dọc luồng sông uy hiếp hạ lưu; người chơi điều thuyền nhẹ đánh nhử, kìm nhịp tiến của địch để gom các chiến thuyền chủ lực của giặc vào khu vực bãi cọc ngầm, đồng thời bảo toàn tuyến phòng thủ quanh `SignalDock (2, 8)`.
2. **Hồi 2 (Đầu Vòng 4 đến Vòng 6 — Thủy triều rút & Phục binh xuất kích):**
   - Ngay **đầu Vòng 4 (`OnRoundStart: Round == 4`)**, sự kiện **`MapPhase_TideFall`** kích hoạt: nước triều rút mạnh làm lộ diện toàn bộ các ô **Bãi cọc ngầm (`StakedWater`)**.
   - Mọi chiến thuyền quân Đại Nguyên đang đứng trên ô bãi cọc lập tức bị cọc nhọn đâm thủng: chịu sát thương trực tiếp **`-35% MaxHP`**, dính hiệu ứng khóa di chuyển **`MarchDisabled` trong 2 lượt** và sụp đổ Sĩ khí xuống bậc **`CHAOS` trong 1 lượt** (sau đó tự hồi về `LOW`).
   - Cùng lúc đó, **Phục binh Đại Việt xuất kích** từ hai bên bờ sông/nhánh sông, tạo thế gọng kìm bọc sườn (`Flank`) và bao vây (`TrappedLevel`) hạm đội giặc đang rối loạn.
3. **Hồi 3 (Vòng 7–10 — Khép vây tiêu diệt chủ tướng):** Quân Nguyên nỗ lực phá vây tuyệt vọng nhắm vào Bến Hiệu Lệnh; người chơi quyết định dồn lực dứt điểm soái hạm **Ô Mã Nhi** để kết thúc sớm trận đánh hoặc quét sạch tàn quân giữ vững trận địa.

### Điều kiện Thắng / Thua & Thách thức 3 Sao của Slice-01
- **Điều kiện Thắng chính (Primary Victory) — Thỏa mãn 1 trong 2 điều kiện:**
  1. **Chiến thắng quyết định (Instant Victory):** Hạ gục chủ tướng **Ô Mã Nhi** trong khi Đại Việt vẫn đang kiểm soát **Bến Hiệu Lệnh (`SignalDock` tại tọa độ `(2, 8)`)** $\rightarrow$ **Thắng ngay lập tức** tại thời điểm hạ tướng *(thiết kế đồng bộ hoàn hảo để người chơi chinh phục mốc 2 Sao `<= 8` lượt!)*.
  2. **Chiến thắng giữ trận & tiêu hao (Hold & Attrition Victory):** Bảo vệ vững chắc quyền kiểm soát `SignalDock (2, 8)` đến hết lượt 10 **và** tiêu diệt được **`>= 75%`** tổng số đơn vị quân Đại Nguyên (trong khi Đại Việt còn ít nhất 1 đơn vị có khả năng chiến đấu).
- **Điều kiện Thua (Defeat):** Để mất quyền kiểm soát `SignalDock (2, 8)` theo điều kiện thất thủ của kịch bản / khi kết thúc lượt 10, hoặc toàn bộ đơn vị chiến đấu của Đại Việt bị tiêu diệt.
- **Tiêu chuẩn Đánh giá 3 Sao (3-Star Challenges):**
  - ⭐ **1 Sao:** Đạt Điều kiện Thắng chính.
  - ⭐⭐ **2 Sao:** Giành chiến thắng trong vòng **`<= 8` lượt** (đòi hỏi tận dụng triệt để bẫy cọc Vòng 4 để kết liễu nhanh Ô Mã Nhi).
  - ⭐⭐⭐ **3 Sao:** Tổng lượng HP tổn thất cộng dồn của toàn quân Đại Việt khi kết thúc trận **`<= 20%`**.

> **Out of scope tuyệt đối cho Slice-01 (Mốc P2):** Chế độ Conquest, Domination, Legion; Kinh tế chiến trường (`enable_economy = false`); `CommandProfile`, Trang bị bảo vật, Duyên phận `Fetters`, Cây công nghệ và hệ thống Chiêu mộ Gacha.

---

## 14.4. Phạm vi Release MVP (Mốc P5 — Gói Chiến dịch Thời Trần)

Khác với Slice-01 chỉ gồm 1 màn kiểm chứng ở mốc `P2`, sản phẩm phát hành chính thức lần đầu (**Release MVP 1.0** tại mốc `P5`) là một gói trải nghiệm lịch sử trọn vẹn, sạch bản quyền và hoàn thiện đa nền tảng:

| Hạng mục MVP (Mốc P5) | Quy mô & Tiêu chuẩn bàn giao |
|---|---|
| **Chiến dịch Lịch sử (Historical Campaign)** | Hoàn chỉnh **Gói Chiến dịch Thời Trần (Ba lần kháng chiến chống Mông – Nguyên thế kỷ XIII)** gồm **6–8 màn chơi lịch sử** liên hoàn có kịch bản sự kiện độc lập (các ứng viên tiêu biểu qua thẩm định `Dossier`: *Bình Lệ Nguyên – Đông Bộ Đầu, Chương Dương – Hàm Tử, Vân Đồn cắt lương, Tây Kết, Đại Chiến Bạch Đằng 1288*,...). |
| **Hệ thống Binh chủng (Unit Roster)** | **10–12 binh chủng** hoàn chỉnh mỹ thuật gốc 2D & âm thanh riêng, bao phủ đầy đủ Thủy quân (Đại chiến thuyền, Mông đồng, Hỏa thuyền,...) và 4 nhánh Lục quân (Bộ binh đao khiên/giáo câu liêm, Cung/Nỏ thủ, Kỵ binh/Tượng binh, Công thành/Hỏa khí sơ kỳ). |
| **Đội ngũ Danh tướng (Commanders)** | **8–10 danh tướng** hai phe Đại Việt – Đại Nguyên có chân dung gốc, `UniqueSkill` và `CommandProfile` riêng biệt (áp dụng `Preset Loadout` cân bằng chặt chẽ trong từng màn Historical Scenario). |
| **Cơ chế Gameplay tích hợp** | Đầy đủ hệ thống chiến trường cốt lõi của P2 **cộng thêm** lớp Hậu cần & Kinh tế chiến trường (`enable_economy = true` cho các màn chiến dịch dài ngày như chặn đoàn thuyền lương Vân Đồn), hệ thống lưu game 2 tầng (`Session Auto-Save` & `Profile Save`) và 4 mức độ khó AI. |
| **Hướng dẫn & Tri thức Lịch sử** | **Tutorial theo tình huống (Contextual Tutorial)** lồng ghép mượt trong 2–3 màn đầu tiên (không ép đọc tường chữ dài) và **Codex Lịch sử hoàn chỉnh** tích hợp `sourceRef`, `Evidence grade`, phân tách rõ sự thật sử liệu và mô hình hóa gameplay. |
| **Nền tảng, Hiệu năng & Thương mại hóa** | Xuất bản chính thức đạt **60 FPS** trên **Web (HTML5/Wasm) + Android** (cùng bản Windows Desktop); 100% tài nguyên đồ họa/âm thanh sạch bản quyền; **không tích hợp Gacha trong MVP** (các chế độ tự do Conquest/Domination và chiêu mộ F2P thân thiện thuộc lộ trình cập nhật hậu MVP). |

---

## 14.5. Definition of Done (DoD) & Tiêu chí Nghiệm thu Playtest (`D-17`)

Một mốc bàn giao (đặc biệt là Gate `P2` cho Slice-01 và Gate `P5` cho Release MVP) chỉ được công nhận hoàn thành khi thỏa mãn đồng thời toàn bộ các tiêu chí có bằng chứng kiểm chứng sau:

1. **Hoàn chỉnh vòng lặp độc lập:** Người chơi khởi động game, đọc Briefing, điều quân qua đủ các hồi kịch bản và nhận kết quả Thắng (1–3 Sao) hoặc Thua mà không cần bất kỳ sự can thiệp hay giải thích miệng nào từ lập trình viên.
2. **Minh bạch thông số & Replay tất định:** Bảng **`UnitInspector`** hiển thị đầy đủ thông số từng đạo quân khớp 100% với `Resource` (`.tres`), và **`CombatLog`** ghi lại kết quả sát thương thực tế khớp 100% với công thức trong `res://sim/`; phát lại cùng chuỗi lệnh với cùng `seed` cho kết quả trùng khớp tuyệt đối (kiểm chứng qua headless test).
3. **Ổn định AI & Hiệu năng 60 FPS:** AI hoàn tất mọi lượt đi dưới 3 giây mà không xảy ra vòng lặp vô tận hay soft-lock; tốc độ khung hình duy trì `>= 60 FPS` kèm bằng chứng chụp màn hình (screenshot verification) và log đo đạc.
4. **Chuẩn mực nhãn lịch sử:** 100% văn bản Briefing, thoại sự kiện và Codex đều có `sourceRef` + `Evidence grade` hợp lệ hoặc được gắn nhãn `fixture / gameplay abstraction` minh bạch.
5. **Nghiệm thu Playtest độc lập (`[D-17]`):** Thực hiện tối thiểu một đợt kiểm thử với **ít nhất 5 người chơi độc lập ngoài đội ngũ phát triển** (có biên bản ghi chép): đạt tỷ lệ **`>= 4/5` người chơi** tự nêu đúng điều kiện thắng/thua, nhận biết được cơ chế thủy triều rút lộ bãi cọc ở Vòng 4 và tự giải thích hợp lý nguyên nhân dẫn đến chiến thắng hoặc thất bại của mình.
