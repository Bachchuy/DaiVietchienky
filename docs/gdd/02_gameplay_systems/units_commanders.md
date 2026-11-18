# 07. Tướng lĩnh, binh chủng và quân đội

[← Quay lại Mục lục GDD](../README.md)

---

## 7.1. Đơn vị tác chiến và Quy mô Gộp cờ (`TroopStack`)

Mỗi đơn vị (`Unit`) trên một ô Hex đại diện cho một đội hình tác chiến (không mô phỏng từng cá nhân rời rạc). Mỗi nguyên mẫu binh chủng (archetype) có vai trò, địa hình sở trường (`fond_terrain`), ưu thế và điểm yếu rõ ràng; các đơn vị lịch sử đưa vào Historical Scenario bắt buộc có `source_ref` và mức chứng cứ phù hợp (xem [historical_framework.md](../03_content_presentation/historical_framework.md)).

### Cơ chế Gộp cờ (`TroopStack`: 1x, 2x, 3x)
Một đạo quân khi triển khai đầu trận hoặc chiêu mộ tại Thành trì có biên chế quy mô **`max_stack` $\in \{1, 2, 3\}$ cờ**:
* **Ấn định đầu trận:** `max_hp = base_hp * max_stack` và hệ số quy mô lực công **`M_stack`** cố định suốt trận:
  * **1 Cờ (`1x`):** `max_hp = 1 * base_hp`, `M_stack = 1.00`, chi phí lương `1x MealRate`.
  * **2 Cờ (`2x`):** `max_hp = 2 * base_hp`, `M_stack = 1.65`, chi phí lương `2x MealRate`.
  * **3 Cờ (`3x` — Đại quân chủ lực):** `max_hp = 3 * base_hp`, `M_stack = 2.20`, chi phí lương `3x MealRate`.
* **Suy giảm mượt không "vách đá sát thương":** Khi đạo quân mất máu trong giao tranh, sát thương giảm liên tục theo tỷ lệ máu hiện tại `M_hp = 0.50 + 0.50 * (float(current_hp) / float(max_hp))`. Số lá cờ hiển thị trên đầu đơn vị (`active_banners = 3 / 2 / 1` ứng với `>66%`, `33%–66%`, `<33%` `max_hp`) là chỉ báo trực quan giúp người chơi đọc nhanh tình trạng tổn thất trên bản đồ mà **không trừ kép vào `M_stack` và không thu hẹp `max_hp`** (cho phép quân y hồi phục lại biên chế ban đầu nếu màn chơi cho phép).

---

## 7.2. Phân loại 5 Nhánh Binh chủng & Bảng Ánh xạ Thống nhất

### Hai miền tác chiến & 5 Nhánh Chỉ huy (`CommandBranch`)
* **Miền Thủy quân (`NAVAL`):** Chiến thuyền, mông đồng, lâu thuyền và thuyền hỏa công tác chiến trên sông biển.
* **Miền Lục quân (`LAND`):** Gồm 4 nhánh chuyên môn: **Bộ binh (`INFANTRY`)**, **Cung / Nỏ (`ARCHERY`)**, **Kỵ binh & Tượng binh (`CAVALRY`)**, và **Công thành / Pháo binh (`SIEGE`)**.
* Các đơn vị đặc thù (như Tượng binh Đại Việt, Tản binh du kích, Thám báo / Nội gián, Công binh) thuộc về nhánh chỉ huy gần nhất theo chức năng chiến thuật và gắn thêm `features` / `tags` riêng (ví dụ: `elephant`, `ignore_zoc`, `devoid_zoc`, `ambush_forest`).

### Bảng Ánh xạ `CommandBranch` ↔ `AttackMode × DefenseMode` ↔ `MealRate`
Bảng dưới đây đồng bộ hoàn toàn giữa phân nhánh tướng chỉ huy, ma trận khắc chế sát thương ([combat_formulas.md](../mechanics/combat_formulas.md)) và định mức tiêu thụ lương thảo ở chế độ bật kinh tế P3+ ([battlefield_economy.md](../mechanics/battlefield_economy.md)):

| Nhánh Chỉ huy (`CommandBranch`) | Kiểu Tấn công (`AttackMode`) | Loại Giáp (`DefenseMode`) | Định mức Lương (`MealRate`) | Vai trò Chiến thuật Cốt lõi |
|---|---|:---:|:---:|---|
| **`INFANTRY`** (Bộ binh) | `1` (*Đao thương cận chiến*) | `1` (*Giáp vải*), `2` (*Giáp da*), `3` (*Giáp sắt*) | **`10`** Food / cờ / lượt | Giữ tuyến phòng ngự, phát `ZoC` chắn đường, chiếm cứ điểm `FORT` và bảo vệ tuyến sau. |
| **`ARCHERY`** (Cung / Nỏ) | `3` (*Cung tên / Nỏ liên châu*), `6` (*Hỏa tiễn*) | `1` (*Giáp vải*), `2` (*Giáp da*) | **`12`** Food / cờ / lượt | Hỏa lực tầm xa `[2, 2]`–`[2, 3]`, chế áp từ cao điểm `HILLS`, yếu khi bị cận chiến áp sát. |
| **`NAVAL`** (Thủy quân) | `5` (*Chiến thuyền / Thủy công*), `6` (*Bè lửa / Hỏa tiễn*) | `2` (*Thuyền nhẹ*), `3` (*Mông đồng*), `5` (*Đại lâu thuyền*) | **`15`** Food / cờ / lượt | Làm chủ mặt nước (`DEEP_WATER`, `SHALLOW_RIVER`), đánh chìm thuyền lương và khóa cửa sông. |
| **`CAVALRY`** (Kỵ binh & Tượng binh) | `2` (*Xung kích Kỵ / Tượng*) | Kỵ: `2` (*Da*), `3` (*Sắt*)<br/>Tượng (`elephant`): `4` (*Voi chiến*) | Kỵ: **`20`** Food / cờ / lượt<br/>Tượng: **`30`** Food / cờ / lượt | Cơ động cao ở `PLAINS`, bọc sườn `Flank`, Tượng binh có `devoid_zoc` xé toạc trận tuyến; bất lợi ở `SWAMP`/`FOREST`. |
| **`SIEGE`** (Công thành / Hỏa khí) | `4` (*Thần cơ pháo / Máy bắn đá*), `6` (*Hỏa hổ*) | `2` (*Giáp da*), `5` (*Công sự tĩnh*) | **`20`** Food / cờ / lượt | Chuyên phá `FORT` (`150%` sát thương công thành) và thiết giáp nặng; di chuyển chậm, cần bộ binh hộ tống. |

---

## 7.3. Tướng lĩnh, Hồ sơ Chỉ huy (`CommandProfile`), Hào quang (`CommandAura`) & Quy tắc Bổ nhiệm

### Quy tắc gắn Tướng chỉ huy (Áp dụng cho cả Quân ta & Quân địch)
* **Giới hạn biên chế:** Tối đa **1 Tướng chỉ huy / 1 đạo quân (`Unit`)**, và mỗi danh tướng chỉ xuất hiện duy nhất một lần trên chiến trường. Cả lực lượng Đại Việt lẫn quân đội đối phương trong lịch sử đều có hệ thống Tướng chỉ huy phân bố đầy đủ từ bậc Lục đến bậc **Tím, Cam và Đỏ** (ví dụ: Mã Viện, Hốt Tất Liệt/Bá Nhan, Trương Phụ bậc Đỏ; Ô Mã Nhi, Quách Quỳ, Cao Biền bậc Cam).
* **Thời điểm gắn Tướng:**
  * Trong **Historical Scenario (Lần vượt ải lịch sử chuẩn)**: khóa sẵn hồ sơ tướng lịch sử (`Preset Loadout — D-02`) của cả hai phe theo đúng kịch bản để bảo toàn thử thách chiến thuật. Sau khi đã vượt qua màn chơi, người chơi có thể mở chế độ **Chơi lại Tự do (`Free Replay / What-If`)** để tự do gắn các danh tướng trong bộ sưu tập (bao gồm cả Tướng đối phương đã chiêu mộ) vào các ô `general_seat`.
  * Trong **Conquest, Legion & Domination (P3+)**: người chơi tự do điều động toàn bộ danh tướng Đại Việt và danh tướng đối phương đã mở khóa/chiêu mộ vào đội hình hoặc bổ nhiệm tại **Thành chính / Đô thành** thuộc quyền kiểm soát.
* **Hậu quả sống còn khi đạo quân Tướng bị loại (`Decapitation Strike — D-15`):**
  * Kỹ năng độc quyền (`UniqueSkill`) và **Hào quang Chỉ huy (`CommandAura`)** của tướng đó ngừng hiệu lực ngay lập tức trong phần còn lại của trận (đây là trạng thái rút khỏi vòng chiến về mặt gameplay, không mặc định đồng nhất với tử trận lịch sử trừ khi kịch bản quy định).
  * **Sốc tâm lý hai chiều (`±1 bậc` Sĩ khí bán kính `2 hex`):** Toàn bộ đơn vị đồng minh của tướng vừa bị loại trong **bán kính `2 hex`** lập tức bị giáng **`-1 bậc` Sĩ khí** (nếu là Chủ soái / Tướng Cờ Đầu `is_commander_in_chief == true` bị hạ mà màn chơi chưa kết thúc ngay, bán kính phạt mở rộng lên **`3 hex`**); ngược lại, toàn bộ đơn vị của phe tiêu diệt trong **bán kính `2 hex`** quanh vị trí đó được thưởng ngay **`+1 bậc` Sĩ khí**.

### Ba Lớp Đóng góp Sức mạnh của Tướng Chỉ huy trên Chiến trường
Để khẳng định tầm quan trọng quyết định của các vị tướng mà không biến một đơn vị lẻ loi thành "siêu nhân bất tử" phá vỡ tính chiến thuật, mỗi danh tướng đóng góp vào sức mạnh tác chiến qua **3 lớp bổ trợ** ([combat_formulas.md](../mechanics/combat_formulas.md)):
1. **Chỉ số Chỉ huy & Khí vận (`GeneralCommandStat` & `GeneralLuck`):**
   * `general_command_stat` (miền `1..30`): cộng trực tiếp `GenBonus = general_command_stat * 1` vào lực công nền của đạo quân.
   * `general_luck` (miền `0..100`): cộng `int(general_luck * 0.15)` (`0%..15%`) vào tỷ lệ bạo kích và giảm sát thương từ bẫy/phản pháo.
2. **Bậc Thông thạo 5 Nhánh Binh chủng (`CommandProfile` → `M_command` khuếch đại sát thương sở trường):**
   * Phản ánh sở trường cầm quân riêng biệt (ví dụ: Trần Quốc Tuấn bậc `S` Thủy/Bộ, Trần Khánh Dư bậc `S` Thủy quân, Mã Viện bậc `S` Kỵ/Bộ), nhân trực tiếp hệ số `M_command` vào sát thương đầu ra:
     * Bậc **`S`** (*Tuyệt kỹ sở trường*): **`+25%`** (`M_command = 1.25`)
     * Bậc **`A`** (*Tinh thông*): **`+15%`** (`M_command = 1.15`)
     * Bậc **`B`** (*Thuần thục*): **`+8%`** (`M_command = 1.08`)
     * Bậc **`C`** (*Tiêu chuẩn*): **`+0%`** (`M_command = 1.00` — mặc định khi không gắn tướng)
     * Bậc **`D`** (*Sở đoản*): **`-10%`** (`M_command = 0.90`)
3. **Hào quang Chỉ huy Chiến thuật (`CommandAura` — Bán kính `1–2 hex`):**
   * Đạo quân gắn Danh tướng phát ra hào quang chỉ huy lên bản thân và các đơn vị đồng minh đứng trong bán kính `aura_radius_hex` (không cộng dồn nhiều hào quang cùng loại, chỉ lấy mức cao nhất):
     * **Tướng bậc Lam / Tím (`aura_radius_hex = 1`):** Cộng **`+5%` `damage_deepen`** (hoặc `+5%` `damage_resist` tùy định hướng tướng) cho đồng minh kề cạnh.
     * **Tướng bậc Cam / Đỏ (`aura_radius_hex = 2`):** Cộng **`+8%` đến `+10%` `damage_deepen` / `damage_resist`** cho đồng minh trong bán kính `2 hex`, đồng thời giúp đồng minh sát cạnh (`1 hex`) miễn giảm Sĩ khí khi có đơn vị bạn tử trận (`NeighboringDeadMates`).

> **Lưu ý thiết kế lịch sử:** Bậc phẩm màu của tướng (`QualityTier`: Đỏ / Cam / Tím / Lam / Lục) áp dụng công bằng cho cả Danh tướng Đại Việt lẫn Danh tướng Đối phương, chỉ biểu thị tầm vóc thử thách quân sự trên chiến trường, độ hiếm sưu tầm và độ phức tạp cơ chế bộ kỹ năng trong gameplay, **tuyệt đối không phải sự tôn vinh chính trị hay phán xét đạo đức lịch sử** của các nhân vật.

### Cấu trúc Dữ liệu `CommandProfile` & `CommandAura` chuẩn GDScript 2.0

```gdscript
class_name CommanderData
extends Resource

enum CommandBranch {
	INFANTRY = 0,
	ARCHERY = 1,
	CAVALRY = 2,
	SIEGE = 3,
	NAVAL = 4,
}

enum ProficiencyTier {
	D = 0,
	C = 1,
	B = 2,
	A = 3,
	S = 4,
}

@export var general_id: int = 0
@export var display_name: String = ""
@export var is_adversary_general: bool = false
@export var is_commander_in_chief: bool = false
@export_range(1, 30) var general_command_stat: int = 10
@export_range(0, 100) var general_luck: int = 20
@export var fond_terrain: int = -1 # -1 nếu không có sở trường riêng
@export_range(0, 2) var aura_radius_hex: int = 1
@export_range(0, 15) var aura_damage_deepen_bonus: int = 5
@export_range(0, 15) var aura_damage_resist_bonus: int = 0

@export var command_profile: Dictionary[CommandBranch, ProficiencyTier] = {
	CommandBranch.INFANTRY: ProficiencyTier.C,
	CommandBranch.ARCHERY: ProficiencyTier.C,
	CommandBranch.CAVALRY: ProficiencyTier.C,
	CommandBranch.SIEGE: ProficiencyTier.C,
	CommandBranch.NAVAL: ProficiencyTier.C,
}


func get_command_multiplier(branch: CommandBranch) -> float:
	var tier: ProficiencyTier = command_profile.get(branch, ProficiencyTier.C)
	match tier:
		ProficiencyTier.S:
			return 1.25
		ProficiencyTier.A:
			return 1.15
		ProficiencyTier.B:
			return 1.08
		ProficiencyTier.C:
			return 1.00
		ProficiencyTier.D:
			return 0.90
		_:
			return 1.00
```

---

## 7.4. Phân định Kỹ năng Tướng (`CastSkill`), Mưu lược Phe (`ApplyTactic`) & Trang bị

* **Đặc tính nội tại (`Traits` / `Features`):** Hiệu ứng thụ động ổn định theo binh chủng hoặc danh tướng (ví dụ: `ignore_zoc` của Thám báo / Nội gián, `devoid_zoc` của Tượng binh, `ambush_forest` của Tản binh du kích).
* **Kỹ năng Chủ động của Tướng (`CastSkill`):** Gắn trực tiếp với đạo quân do Tướng chỉ huy; vận hành bằng **bộ đếm hồi chiêu riêng theo lượt (`skill_cooldown: int`) kết hợp điều kiện chiến thuật nội tại** (đứng trên sông, kề cạnh địch, máu dưới ngưỡng...). `CastSkill` là hành động chính trong lượt của đạo quân đó và **không tiêu tốn `Mana` toàn phe** (bị tạm khóa nếu đạo quân dính `CHAOS` hoặc `skill_disabled_turns > 0`).
* **Mưu lược Quân sư toàn phe (`ApplyTactic`):** Hệ thống sách lược cấp chiến dịch (như *Hịch Tướng Sĩ*, *Hỏa Công*, *Nghi Binh*) sử dụng bể tài nguyên **`Mana`** chung của toàn Faction, thi triển độc lập mà không chiếm mất hành động chính của từng đạo quân trên bản đồ.
* **Trang bị & Bảo vật (`Equipment`):** Gồm 5 ô bảo vật (Cận chiến, Tầm xa, Hộ giáp, Thú cưỡi, Binh thư) gắn đúng niên đại văn hóa quân sự Việt Nam, mở khóa từ mốc **P3 Alpha**. Xem cấu trúc JSON chi tiết tại [data_and_save_system.md](../architecture/data_and_save_system.md) và tiến trình Meta tại [generals_and_meta_economy.md](../progression/generals_and_meta_economy.md).
