# 06. Hệ thống chiến trường

[← Quay lại Mục lục GDD](../README.md)

---

## 6.1. Bản đồ và topology

Trò chơi sử dụng lưới lục giác đỉnh nhọn (**Pointy-topped Axial Hex Grid `(q, r)`**) kết hợp công thức quy đổi hai chiều với lưới chữ nhật **Offset `odd-r` `(col, row)`** phục vụ thiết kế bản đồ trong Godot `TileMapLayer`. Sáu hướng tiếp cận có khoảng cách hình học đồng đều theo **Khoảng cách Cube/Hex (`hex_distance`)**, loại bỏ sai lệch đường chéo của lưới vuông và giúp người chơi đọc chính xác cự ly bọc sườn, tầm bắn cũng như vùng kiểm soát.

> 📖 Đặc tả toán học tọa độ Axial/Offset, định tuyến A* và kiểm tra tầm nhìn: xem [hex_grid_pathfinding.md](../mechanics/hex_grid_pathfinding.md).

---

## 6.2. Chín loại địa hình chuẩn hóa & Địa hình sở trường (`fond_terrain`)

Hệ thống bản đồ thống nhất **9 loại địa hình** chiến thuật. Thiết kế tách bạch rõ hai lớp hiệu ứng:
1. **Hiệu ứng nội tại của địa hình (Intrinsic Effect):** Áp dụng cho **mọi đơn vị** đứng trên hoặc đi qua ô đó (chi phí MP nguyên `int`, hệ số giáp địa hình `TerrainDefMult`, cản tầm nhìn LOS).
2. **Hiệu ứng Địa hình sở trường (`fond_terrain` Bonus):** Chỉ kích hoạt khi đơn vị hoặc tướng có thuộc tính `fond_terrain` trùng khớp với địa hình ô hiện tại — thưởng thêm **`+15% ATK/DEF`** và giảm **`-1 MP`** chi phí bước vào ô đó (sàn tối thiểu **`1 MP`**).

| # | Địa hình (`TerrainType`) | MP Cơ bản (Bộ / Kỵ-Pháo / Thủy) | Hiệu ứng Nội tại (Mọi đơn vị) | Ý nghĩa Chiến thuật & `fond_terrain` tiêu biểu |
|:-:|---|:---:|---|---|
| 1 | **Đồng bằng** (`PLAINS`) | `2` / `2` / Cấm | `TerrainDefMult = 1.00`; không cản LOS. | Không gian mở thuận lợi dàn trận. *Sở trường:* Kỵ binh xung kích, Thiết kỵ. |
| 2 | **Rừng rậm** (`FOREST`) | `3` / `4` / Cấm | `TerrainDefMult = 1.20` (+20% Giáp); **chặn LOS** mặt đất; hỗ trợ ẩn thân `is_invisible` & phục kích. | Điểm tựa phòng ngự và mai phục. *Sở trường:* Tản binh du kích, Cung nỏ rừng. |
| 3 | **Đồi núi / Cao điểm** (`HILLS`) | `4` / `5` / Cấm | `TerrainDefMult = 1.15` (+15% Giáp); đơn vị tầm xa đứng trên cao `+10% ATK` và nhìn xuyên `FOREST`; **chặn LOS** từ dưới thấp. | Chiếm lĩnh tầm nhìn và chế áp hỏa lực. *Sở trường:* Cung nỏ, Sơn binh, Pháo binh. |
| 4 | **Đầm lầy / Bãi bùn** (`SWAMP`) | `4` / `6` / `4`* | `TerrainDefMult = 0.90` (-10% Giáp); Kỵ/Pháo giảm `-15% ATK` nội tại; che khuất `is_invisible` trong lau sậy (*chỉ thuyền nhỏ đi được*). | Kìm chân kỵ binh và trọng binh địch. *Sở trường:* Tản binh đầm lầy, Thủy lục binh. |
| 5 | **Sông cạn / Bờ sông** (`SHALLOW_RIVER`) | `4` / `5` / `2` | Lục quân lội nước chịu `TerrainDefMult = 0.90` (-10% Giáp; Thủy quân giữ `1.00`); không cản LOS. | Điểm nghẽn vượt sông, ranh giới thủy–bộ. *Sở trường:* Thủy binh ven sông, Tượng binh. |
| 6 | **Mặt nước sâu** (`DEEP_WATER`) | Cấm* / Cấm* / `2` | `TerrainDefMult = 1.00` (*Lục quân chỉ đi được khi lên thuyền vận tải tại Bến với `3 MP`, chịu `TerrainDefMult = 0.80` và `-20% ATK`*). | Chiến trường chính của hạm đội. *Sở trường:* Chiến thuyền, Mông đồng, Lâu thuyền. |
| 7 | **Thành trì / Công sự** (`FORT`) | `2` / `3` / Cấm | `TerrainDefMult = 1.30` (+30% Giáp); phát vùng **`CoC`** nhân `2` MP tiếp cận của địch; **chặn LOS** địch. | Cứ điểm phòng ngự và mục tiêu công phá. *Sở trường:* Cấm vệ thủ thành, Nỏ thủ giữ lũy. |
| 8 | **Đường cái / Bến thuyền** (`ROAD_PORT`) | `1` / `1` / `2` (tại Bến) | `TerrainDefMult = 1.00`; trục cơ động nhanh; Bến thuyền cho phép chuyển đổi Lục quân ↔ Thuyền vận tải (`2 MP`). | Mạch giao thông huyết mạch và bến đổ bộ (như `SignalDock`). *Sở trường:* Khinh kỵ, Đoàn vận lương. |
| 9 | **Bãi cọc ngầm lộ diện** (`STAKED_WATER`) | Cấm / Cấm / `4` (Địch) · `2` (Ta) | `TerrainDefMult = 0.85`; kích hoạt qua sự kiện `MapPhase` (triều rút): gây `35% max_hp` sát thương xuyên giáp và gán `march_disabled_turns = 2` lên tàu địch mắc cọc. | Bước ngoặt kịch bản thủy chiến (như Bạch Đằng 1288). *Sở trường:* Thủy quân khinh tiễn Đại Việt (miễn nhiễm bẫy cọc). |

---

## 6.3. Di chuyển, tầm nhìn (LOS) và vùng kiểm soát (`ZoC` / `CoC`)

* **Vùng khống chế binh chủng (`ZoC` — Zone of Control):**
  * Mọi đơn vị còn sống và **không ở trạng thái `MoraleLevel.CHAOS`** phát `ZoC` ra 6 ô Hex liền kề (trừ khi đơn vị địch đó đang đứng kề một đồng minh của phe di chuyển có thuộc tính phá vây `devoid_zoc`).
  * **Bước từ ngoài vào ô `ZoC` địch:** Nếu đơn vị không có `ignore_zoc`, chi phí bước vào ô đó bằng `max(step_cost, remaining_mp)` (tính trên `remaining_mp` còn lại tại bước đang xét trên đường đi A*, không dùng `max_mp` đầu lượt). Đơn vị dừng di chuyển ngay tại ô đó (`remaining_mp = 0`), nhưng **vẫn giữ quyền thực hiện hành động chính** (`Attack` hoặc `CastSkill`).
  * **Quy tắc rút lui khi đầu lượt đã đứng sẵn trong `ZoC`:** Đơn vị được phép rút thẳng ra một ô liền kề nằm ngoài mọi `ZoC` địch với chi phí địa hình bình thường; tuy nhiên nếu bước trượt trực tiếp từ một ô `ZoC` sang **một ô `ZoC` khác** của địch (không có `ignore_zoc`), đơn vị bị ghìm chân ngay lập tức (`max(step_cost, remaining_mp)`), ngăn chặn việc luồn ra sau lưng tuyến phòng ngự trong cùng một lượt.
* **Vùng khống chế thành quách (`CoC` — Castle of Control):**
  * Ô `FORT` của địch phát `CoC` ra 6 ô xung quanh: nhân **`2` lần chi phí địa hình (`terrain_cost * 2`)** đối với quân tiếp cận (miễn nhiễm nếu có `ignore_coc`) và gây sát thương hỏa lực công sự tự động vào cuối lượt địch.
* **Tầm nhìn (`LOS`) & Sương mù chiến tranh (`Fog of War`):**
  * Đường ngắm tính bằng thuật toán nội suy tuyến tính `hex_linedraw`. Các ô trung gian thuộc `FOREST`, `HILLS` hoặc `FORT` chặn tầm nhìn của đơn vị đứng dưới thấp; đơn vị đứng trên `HILLS` hoặc `FORT` nhìn vượt qua `FOREST` và đội hình quân.
  * Bản đồ chia 3 trạng thái: `UNEXPLORED` (chưa khám phá), `SHROUDED` (đã mở bản đồ nhưng khuất tầm nhìn hiện tại — ẩn vị trí quân địch) và `VISIBLE` (đang quan sát trực tiếp).

> 📖 Chi tiết thuật toán A*, `ZoC`/`CoC` và `hex_linedraw` bằng GDScript 2.0: xem [hex_grid_pathfinding.md](../mechanics/hex_grid_pathfinding.md).

---

## 6.4. Giải quyết Giao tranh (Combat Resolution)

> 📖 **Đặc tả toán học & mã nguồn mẫu GDScript 2.0 đầy đủ:**  
> Xem [Công Thức Chiến Đấu & Sát Thương (combat_formulas.md)](../mechanics/combat_formulas.md).

### Nguyên lý thiết kế chuẩn hóa
1. **Controlled RNG có Seed tất định (`Seeded RandomNumberGenerator`):**
   * Sát thương cơ bản dao động trong biên độ mặc định **`80% – 100%`** `base_atk` (khinh binh/du kích `75% – 95%`, cấm vệ tinh nhuệ `85% – 100%`).
   * Phiên trận lưu trữ `rng_seed` và `rng_state` sau mỗi lệnh để đảm bảo **100% Deterministic Replay** đa nền tảng (Web & Android), chống gian lận tải lại vô hạn nhưng vẫn giữ nhịp điệu bất ngờ hợp lý của chiến trường.
   * Mọi kết quả sát thương chốt bằng hàm làm tròn số nguyên **`round_half_up(x)`** với sàn tối thiểu `max(1, final_damage)` khi đòn đánh hợp lệ.
2. **Đường cong Giáp phi tuyến thống nhất (`DefReduction`):**
   $$\text{EffectiveDef} = \text{BaseDef} \times \text{TerrainDefMult} \times \text{MoraleDefMult}$$
   $$\text{DefReduction} = \frac{100.0}{100.0 + \max(0.0, \text{EffectiveDef})}$$
   Trong đó `MoraleDefMult = 0.80` khi mục tiêu ở trạng thái `MoraleLevel.LOW` (*Dao Động*, giảm 20% Giáp), còn lại bằng `1.00`. Hàm `max(0.0, EffectiveDef)` chặn biên an toàn tuyệt đối.
3. **Quy mô Gộp cờ (`TroopStack`: 1x, 2x, 3x) không "vách đá sát thương":**
   * Quy mô biên chế đầu trận `max_stack` (`1`, `2`, `3`) ấn định cố định `max_hp = base_hp * max_stack` và hệ số quy mô `M_stack` (`1.00`, `1.65`, `2.20`).
   * Khi tổn thất máu trong trận, lực đánh giảm mượt liên tục theo `M_hp = 0.50 + 0.50 * (float(current_hp) / float(max_hp))`. Số lá cờ hiển thị trên đầu đơn vị (`active_banners = 3 / 2 / 1` ứng với `>66%`, `33%–66%`, `<33%` `max_hp`) đóng vai trò tín hiệu thị giác trực quan, không trừ kép vào `M_stack`.
4. **Hệ số toàn diện trong `FinalDamage`:**
   * Kết hợp khắc chế `6 AttackMode × 5 DefenseMode` (`DamagePercent`), thông thạo binh chủng sở trường của tướng `CommandProfile` (`M_command`: `S = +25%`, `A = +15%`, `B = +8%`, `C = +0%`, `D = -10%`) cùng `GenBonus = GeneralCommandStat * 1` (`1..30`) và Hào quang Chỉ huy `CommandAura` (`1–2 hex`), Sĩ khí bên công `M_morale` (`1.15 / 1.00 / 0.75 / 0.00`), phạt mục tiêu hỗn loạn `M_target_chaos` (`1.30` khi mục tiêu `CHAOS`), bọc sườn `M_flank` (`1.15`), địa hình `M_terrain`, nạn đói `M_starvation` (`0.75` ở P3+), và kháng sát thương chặn biên `clampi(damage_resist, -50, 75)`.
5. **Bạo kích (`Crit`) & Phản kích (`Retaliation`):**
   * **Bạo kích:** `crit_rate = clampi(base_crit + int(hp_ratio * 10.0) + int(general_luck * 0.15) + morale_crit_mod + crit_rate_bonus, 0, 100)`. Khi nổ Crit, sát thương nhân `(1.50 + crit_damage_bonus / 100.0)` (làm tròn `round_half_up`) và giáng ngay **`-1 bậc` Sĩ khí** lên mục tiêu.
   * **Phản kích:** Bên công đánh trước; nếu bên thủ còn sống (`current_hp > 0`), không bị `CHAOS` hay `attack_disabled_turns > 0`, chưa dùng lượt phản kích trong vòng đối phương (`not has_retaliated_this_round`), và kẻ tấn công nằm trong `[min_range, max_range]` **kèm LOS hợp lệ**, bên thủ phản kích với sát thương `round_half_up(counter_raw_damage * counter_percent / 100.0)` (mặc định `counter_percent = 75`).

---

## 6.5. Bọc sườn (Flank)

Flank thưởng cho việc phối hợp thế trận từ nhiều hướng mà không bắt người chơi quản lý hướng quay mặt (facing) rườm rà:
* **Điều kiện hình học chuẩn:** Đơn vị tấn công có ít nhất **1 đơn vị đồng minh khác** (còn sống và không ở trạng thái `MoraleLevel.CHAOS`) đang đứng kề mục tiêu tại một ô Hex **không kề cạnh** với ô của đơn vị tấn công (tức hợp lệ ở cả góc kẹp chéo $120^\circ$ lẫn góc đối xứng gọng kìm $180^\circ$).
* **Tác động:** Đòn đánh nhận hệ số `M_flank = 1.15` (+15% sát thương) và giáng **`-1 bậc` Sĩ khí** lên mục tiêu. Riêng thế kẹp đối xứng $180^\circ$ đồng thời thỏa mãn điều kiện hợp vây `TrappedLevel 2` (xem mục 6.6).

---

## 6.6. Sĩ khí 4 Bậc (`MoraleLevel`) & Bao vây (`TrappedLevel`)

Hệ thống Sĩ khí vận hành hoàn toàn bằng **4 bậc Enum rời rạc** (không dùng thang điểm số `0–100` và không xóa sổ đơn vị tự động):

1. **`HIGH` (*Hưng Phấn*):** `M_morale = 1.15` (+15% sát thương), `+20%` tỷ lệ Crit.
2. **`NORMAL` (*Ổn Định* — Mặc định khởi đầu trận):** `M_morale = 1.00`, `MoraleDefMult = 1.00`.
3. **`LOW` (*Dao Động*):** `M_morale = 0.75` (-25% sát thương), `MoraleDefMult = 0.80` (-20% Giáp), `-5%` tỷ lệ Crit.
4. **`CHAOS` (*Hỗn Loạn*):** `M_morale = 0.00` — **khóa toàn bộ di chuyển, tấn công, kỹ năng và phản kích**, mất khả năng phát `ZoC`, và chịu thêm **`+30%` sát thương nhận vào** (`M_target_chaos = 1.30`). Đơn vị vẫn hiện diện trên bản đồ để đồng minh có cơ hội giải vây hoặc dùng mưu lược khích lệ.

* **Dịch chuyển bậc (`±1 bậc`):**
  * **Tăng `+1 bậc` (tối đa `HIGH`):** Kết liễu hoàn toàn 1 đơn vị địch (`+1 bậc` cho người hạ gục; nếu hạ Tướng địch thì toàn bộ quân ta trong bán kính `2 hex` được `+1 bậc`), nhận Kỹ năng khích lệ / Trống đồng / Hịch truyền, hoặc chiếm lĩnh cứ điểm mục tiêu.
  * **Giảm `-1 bậc` (trừ khi có `is_morale_locked`):** Bị đánh `Flank`, trúng đòn `Crit`, có đồng minh sát cạnh tử trận (`NeighboringDeadMates` bán kính `1 hex` — được miễn nếu đứng cạnh Tướng Cam/Đỏ có `CommandAura`), **có Tướng phe mình bị loại khỏi vòng chiến (`D-15`: phạt `-1 bậc` cho toàn bộ đồng minh trong bán kính `2 hex`, hoặc `3 hex` nếu là Chủ soái)**, kết thúc lượt trong `TrappedLevel 1`, hoặc chịu `Starvation` đầu vòng (riêng `Starvation` chỉ hạ tối đa xuống `LOW`, không bao giờ đẩy xuống `CHAOS` để chống soft-lock).
* **Bao vây đa cấp (`TrappedLevel 0..3` — bắt buộc có `>= 2` địch kề cạnh):**
  * `TrappedLevel 0` (*An toàn*): `< 2` địch kề cạnh hoặc `<= 1` hướng bị chặn (đứng tựa lưng vào núi khi chỉ có 0–1 địch không bao giờ tự hoảng loạn).
  * `TrappedLevel 1` (*Khóa sườn*): `>= 2` địch kề cạnh và tổng `2–3` hướng bị chặn (địch + địa hình cấm đi) → cuối lượt phe đó giảm `-1 bậc` Sĩ khí.
  * `TrappedLevel 2` (*Hợp vây / Pincer*): `>= 2` địch đứng kẹp đối xứng $180^\circ$ (hoặc `>= 3` địch kề cạnh với tổng `4–5` hướng bị chặn) → rơi ngay vào `CHAOS` (`chaos_turns = 1`).
  * `TrappedLevel 3` (*Tứ bề thọ địch*): `6/6` hướng bị chặn với `>= 2` địch kề cạnh → duy trì `CHAOS` cho đến khi được đồng minh phá vây mở đường thoát.

> 📖 Chi tiết 7 hiệu ứng khống chế (CC) và mã nguồn `UnitCombatState` GDScript 2.0: xem [morale_and_status.md](../mechanics/morale_and_status.md).

---

## 6.7. Hậu cần & Kinh tế Chiến trường (Supply & Logistics)

Hệ thống kinh tế trong trận (`Coin`, `Food`, `Tech`, `Mana`, khấu trừ `MealFood` và `Starvation`) **ẩn trong Slice-01 Bạch Đằng (`enable_economy = false`)** để người chơi tập trung hoàn toàn vào địa hình và nhịp thủy triều. Hệ thống được bật đầy đủ từ mốc **P3 Alpha** cho chế độ Conquest và các đại chiến dịch dài ngày.

> 📖 Xem đặc tả đầy đủ tại [battlefield_economy.md](../mechanics/battlefield_economy.md) và [factions_economy.md](factions_economy.md).

---

## 6.8. Thời tiết, Thủy chiến & Kịch bản Bãi cọc (`STAKED_WATER`)

Thời tiết và thủy triều là biến số kịch bản được báo trước qua Briefing / UI đếm ngược để người chơi chủ động bày binh bố trận. Trong các trận thủy chiến như Slice-01 Bạch Đằng 1288:
* Khi triều cường (vòng đầu), khu vực bãi cọc ẩn dưới dạng `DEEP_WATER`.
* Khi sự kiện kịch bản `MapPhase` kích hoạt nước triều rút, dải ô mục tiêu chuyển sang địa hình **`STAKED_WATER`** (*Bãi cọc ngầm lộ diện*): chiến thuyền hạng nặng của địch nằm trên bãi cọc hoặc lao vào ô cọc lập tức chịu sát thương xuyên giáp (`35% max_hp`) và bị khóa di chuyển (`march_disabled_turns = 2`), tạo thời cơ vàng để thủy quân nhẹ Đại Việt đổ ra đánh gọng kìm (`TrappedLevel 2`) và kết liễu chủ tướng giặc.

> 📖 Quy chuẩn thiết kế kịch bản sự kiện `MapPhase` và Slice-01: xem [scenario_scripting_and_events.md](../level_design/scenario_scripting_and_events.md) và [production_scope_mvp.md](../04_production_roadmap/production_scope_mvp.md).

---

## 6.9. Kỵ binh và Bộ binh

Kỵ binh phát huy uy lực khi chọn đúng không gian mở (`PLAINS`, `ROAD_PORT`) và thời điểm xung kích, nhưng không được phép `move – attack – move`: sau khi ra đòn, kỵ binh giữ nguyên vị trí đến lượt kế tiếp và phải đối mặt nguy cơ bị bộ binh giáo mác phản công hoặc kẹp sườn nếu lao quá sâu vào rừng lầy (`FOREST`, `SWAMP`). Bộ binh thắng nhờ giữ tuyến vững chắc, chiếm cứ điểm `FORT` và che chắn cho cung nỏ/pháo binh phía sau. Chỉ số cấu hình từng đơn vị được định nghĩa hướng dữ liệu tại [data_and_save_system.md](../architecture/data_and_save_system.md).
