# SỔ TAY QUẢN LÝ TÀI NGUYÊN (ASSET CATALOG & TECHNICAL AUDIT)
## DỰ ÁN: ĐẠI VIỆT CHIẾN KỲ (VIETNAM HISTORY STRATEGY)
**Trạng thái:** Kiểm kê thực tế ổ đĩa (**2,464 files gốc / ~273 MB** trong `Assets/` — Placeholder nội bộ R&D)  
**Vị trí:** `docs/assets/ASSET_CATALOG.md`  
**Liên kết GDD:** [← Quay lại Mục lục GDD](../gdd/README.md)

---

## 1. TỔNG QUAN KIỂM KÊ THỰC TẾ TRÊN Ổ ĐĨA (VERIFIED DIRECTORY MAP)

Theo kết quả kiểm toán trực tiếp thư mục dự án, toàn bộ kho tài nguyên tham chiếu hiện nằm trong `res://Assets/` với tổng cộng **2,464 tệp gốc (~273 MB)** *(chưa tính các tệp `.import` / `.uid` do Godot sinh tự động)*. Thư mục `Data/` của bản giải mã cũ **hiện không có trên ổ đĩa**; toàn bộ dữ liệu thiết kế của **Đại Việt Chiến Kỳ** được biên soạn mới hoàn toàn bằng chữ thường chuẩn tại **`res://data/`**:

```text
d:\code\VietNamHistoryStrategy\
│
├── Assets/                                    # 2,464 FILES GỐC (~273 MB) — PLACEHOLDER THỬ NGHIỆM NỘI BỘ
│   ├── Audio/                                 # 120 files (.wav, .mp3: SFX binh khí, thủy chiến, UI, BGM)
│   ├── Buildings/                             # 108 files (.png: cầu gỗ, thành trì, doanh trại, công sự)
│   ├── Shaders/                               # 159 files (.fsh, .vsh, .tcsh, .tesh — GLSL Cocos2d-x tham chiếu)
│   ├── Soldiers/                              # 661 files (.png, .atlas, .bin Spine & thư mục nháp debug_parts/ cần dọn)
│   ├── SpineEffects/                          # 427 files (.bin Spine 4.1.21, .atlas, .ktx, .png)
│   └── UI/                                    # 989 files đồ họa giao diện chia làm 7 thư mục con:
│       ├── Avatars/                           # 740 files (chân dung tướng tên Pinyin định dạng .png & .ktx)
│       ├── Battle/                            # 141 files (.png: icon bản đồ anno_*, cờ hiệu, thành phần HUD trận đánh)
│       ├── BattleAtlas/                       # 2 files (battlegen_hd.png, battleres_hd.png)
│       ├── Chapters/                          # 71 files (.png: chapter_*.png tranh nền chương hồi)
│       ├── Treasures/                         # 17 files (.png: equip_team_101.png .. bảo vật/trang bị đội quân)
│       ├── Gacha/                             # 9 files (.png: luck_draw_*.png, arena_back.png, rogue_stage_back_*.png)
│       └── Store/                             # 9 files (.webp, .png: purchase_*.webp/.png)
│
├── data/                                      # [BIÊN SOẠN MỚI — CHỮ THƯỜNG 100% CHO WEB & ANDROID]
│   ├── settings/                              # troop_settings.json, stage_settings.json, tactic_settings.json
│   └── battles/                               # battle_10101.json (Slice-01 Đại Chiến Bạch Đằng 1288), ...
│
└── shaders/                                   # [VIẾT MỚI THUẦN GODOT 4.7 SHADING LANGUAGE]
    └── *.gdshader                             # hit_flash.gdshader, water_flow.gdshader, fog_of_war.gdshader, ...
```

> [!IMPORTANT] **Ghi chú Kỹ thuật Trung thực về Khả năng Tương thích với Godot 4.7 (`gl_compatibility`):**
> 1. **Không nạp trực tiếp `.fsh / .vsh / .tcsh / .tesh`:** 159 tệp trong `Assets/Shaders/` là mã nguồn shader **Cocos2d-x OpenGL ES** (dùng biến nội bộ `CC_Texture0`, `CC_Time`,...). Godot 4.7 **không biên dịch được các tệp này**; chúng chỉ dùng làm tài liệu đọc hiểu thuật toán để viết mới tệp **`.gdshader`** (`shader_type canvas_item;`) đặt tại `res://shaders/`.
> 2. **Không nạp trực tiếp `.bin` (Spine 4.1.21) & `.ktx`:** Dự án chốt kiến trúc **Godot 4.7 Thuần GDScript 2.0 + `gl_compatibility` (Web & Android)** không phụ thuộc GDExtension C++ bên thứ ba. Do đó, các tệp xương nhị phân `.bin` và nén `.ktx` trong `Soldiers/`, `SpineEffects/`, `UI/Avatars/` chỉ đóng vai trò **tư liệu tham chiếu chuyển động/hình ảnh**; bản chạy thực tế trong Godot chỉ đọc các tệp `.png` hợp lệ và chuyển đổi/vẽ mới sang **`SpriteFrames` (`AnimatedSprite2D`), `AtlasTexture` và `CPUParticles2D` thuần Godot 4.7**. Tương tự, thư mục con `Assets/Soldiers/debug_parts/` là tệp cắt thử nghiệm cần được loại bỏ khi dọn dẹp kho tài nguyên.

---

## 2. BẢNG TRA CỨU ÂM THANH THỰC TẾ (`res://Assets/Audio/` — 120 Files)

Mọi tên tệp dưới đây đã được đối chiếu xác thực **tồn tại 100% trên ổ đĩa** trong `Assets/Audio/`:

### 2.1. Âm Thanh Giao Chiến Binh Chủng (Combat SFX)

| Định Danh Hằng Số (`AssetPaths`) | Tên File Âm Thanh Thực Tế | Loại Binh Khí / Đơn Vị | Hoàn Cảnh Kích Hoạt & Phân Kỳ Thời Đại |
| :--- | :--- | :--- | :--- |
| `SFX_SWORD_STRIKE` | `sfx_StrikeIron.wav`, `sfx_strike1.wav` | Đao kiếm cận chiến | Bộ binh đao khiên chém va chạm giáp sắt. |
| `SFX_KNIFE_HIT` | `sfx_knifestrike1.wav`, `sfx_knifestrike2.wav` | Đoản đao, kích ngắn | Khinh binh phục kích đánh lén, phản kích nhanh. |
| `SFX_SHIELD_BLOCK` | `sfx_block1.wav`, `sfx_metal_impact.wav` | Khiên mộc, hộ giáp | Đỡ đòn giảm sát thương cận chiến. |
| `SFX_SPEAR_PIERCE` | `sfx_pierce.wav`, `sfx_lancer1.wav` | Trường giáo, câu liêm | **Bộ Binh Trường Giáo** Đại Việt đâm chặn địch. |
| `SFX_CROSSBOW_SHOOT` | `sfx_crossbow.wav`, `sfx_crossbow2.wav` | Nỏ cứng, Nỏ Liên Châu | Cung nỏ thủ bắn loạt tên chế áp từ thuyền/bờ sông. |
| `SFX_BOW_SHOOT` | `sfx_archery.wav`, `sfx_archery2.wav` | Cung tên | Cung thủ bắn vòng cầu qua vật cản. |
| `SFX_ARROW_HIT` | `sfx_archery4.wav` | Mũi tên trúng đích | Tên găm vào mạn thuyền gỗ hoặc khiên. |
| `SFX_CANNON_FIRE` | `sfx_naval_gun.wav`, `sfx_gunfire.wav` | Súng Thần Cơ, Hỏa pháo | ⚠️ **`Era-gating` (TK XV+):** Chỉ dùng cho màn thời Hồ – Lê Sơ – Tây Sơn; **cấm dùng ở Bạch Đằng 1288**. |
| `SFX_SIEGE_ROCK` | `sfx_trebuchet.wav`, `sfx_rockhit.wav` | Máy bắn đá | Phá công sự, bắn đá uy hiếp chiến thuyền. |
| `SFX_ELEPHANT_STOMP` | `sfx_elephant_move.wav`, `sfx_leg_heavy.wav` | Tượng binh xung kích | Voi chiến dẫm chân rung chuyển mặt đất. |
| `SFX_HORSE_CHARGE` | `sfx_cavalrymove.wav` | Kỵ binh | Tiếng vó ngựa cơ động trên đồng bằng. |

### 2.2. Âm Thanh Thủy Chiến Bạch Đằng (Naval Warfare SFX)

| Định Danh Hằng Số | Tên File Âm Thanh Thực Tế | Hoàn Cảnh Tác Chiến Bạch Đằng 1288 (`stage_id: 10101`) |
| :--- | :--- | :--- |
| `SFX_NAVAL_AMBIENCE` | `sfx_naval.wav` | Âm thanh nền sóng nước cửa sông Bạch Đằng. |
| `SFX_SHIP_CRASH` | `sfx_shiphit.wav`, `sfx_destroy.wav` | Chiến thuyền Đại Nguyên vướng bãi cọc `StakedWater` vỡ đáy ở đầu Vòng 4 (`ApplyAreaEffect`). |
| `SFX_WATER_WAVE` | `sfx_wave.wav` | Tiếng nước thủy triều rút nhanh khi kích hoạt `MapPhase_TideFall`. |
| `SFX_FIRE_BURN` | `sfx_burn.wav`, `sfx_dfire.wav` | Hỏa thuyền và tên lửa thiêu cháy chiến thuyền địch. |

### 2.3. Âm Thanh Sĩ Khí, Quân Hiệu & Giao Diện (Morale & UI SFX)

| Định Danh Hằng Số | Tên File Âm Thanh Thực Tế | Hoàn Cảnh Kích Hoạt |
| :--- | :--- | :--- |
| `SFX_CHAOS_STATE` | `sfx_chaos.wav` | Phát khi đơn vị tụt sĩ khí xuống trạng thái **Hỗn Loạn (`InChaos`)**. |
| `SFX_WAR_HORN` | `sfx_horn.wav`, `sfx_Bugle.wav` | Tiếng tù và hiệu lệnh khai trận hoặc tung tổng phản công. |
| `SFX_TEMPLE_BELL` | `sfx_bell.wav` | Âm thanh điểm nhấn sự kiện lịch sử / đền đài. |
| `SFX_UI_CLICK` | `sfx_click.wav`, `sfx_select.wav`, `sfx_cancel.wav` | Bấm nút lệnh HUD, chọn đạo quân, hủy chọn mục tiêu hoặc bấm `[HOÀN TÁC]`. |
| `SFX_GOLD_DROP` | `sfx_golddrop.wav`, `sfx_rankup.wav`, `sfx_lvup.wav` | Nhận thưởng tổng kết màn chơi, thăng cấp tướng (P3+). |
| `SFX_VICTORY` / `SFX_DEFEAT` | `victory.wav`, `defeat.wav` | Âm hiệu kết thúc trận đánh Thắng / Thua. |
| `BGM_BATTLE_PLACEHOLDER` | `bgm.mp3`, `begin.mp3` | Nhạc nền placeholder phục vụ kiểm thử Audio Bus. |

---

## 3. KIỂM KÊ THƯ MỤC SHADERS THAM CHIẾU (`Assets/Shaders/` — 159 Files)

> [!WARNING] **Đính chính Kỹ thuật Quan trọng:**  
> Các tệp `.fsh` / `.vsh` dưới đây thuộc engine gốc Cocos2d-x, **không thể gán trực tiếp vào `ShaderMaterial` của Godot 4.7**. Đặc biệt, tệp **`base_white.fsh` thực chất chứa hàm nhiễu FBM phủ tuyết trắng địa hình mùa đông (`ToWhite` / `VaryNf`), KHÔNG phải shader Hit Flash!** Khi lập trình trên Godot 4.7, đội ngũ sử dụng các tệp `.gdshader` viết mới hoàn toàn tại `res://shaders/`:

| Tệp Tham Chiếu Trong `Assets/Shaders/` | Bản Chất Thực Tế Trong Mã Gốc | Hướng Triển Khai Chuẩn Trên Godot 4.7 (`gl_compatibility`) |
| :--- | :--- | :--- |
| `river.fsh` / `river.vsh` | Cuộn UV dòng chảy sông ngòi. | Viết mới `res://shaders/water_river.gdshader` (`shader_type canvas_item;`). |
| `sea_foam.fsh` | Tạo viền bọt sóng ven bờ và ghềnh nước. | Viết mới `res://shaders/water_foam.gdshader` cho ô cửa biển & bãi cọc `StakedWater`. |
| `base_rainripples.fsh` | Vòng gợn nước mưa trên bề mặt ẩm. | Tham chiếu công thức vòng sóng thời tiết mưa (nếu bật ở cấu hình High). |
| **`base_white.fsh`** | **Hàm phủ tuyết trắng địa hình mùa đông** *(không phải Hit Flash!)*. | **Không sử dụng cho Hit Flash.** Hiệu ứng chớp trắng 50ms khi trúng đòn dùng `res://shaders/hit_flash.gdshader` gắn tạm thời hoặc `self_modulate` overbright. |
| `dissolveEffect.fsh` / `.vsh` | Tan biến alpha theo ngưỡng noise khi đơn vị bị tiêu diệt. | Viết mới `res://shaders/unit_dissolve.gdshader` gắn tạm lúc chạy hoạt cảnh tan rã. |
| `burningPaper.fsh` / `.vsh` | Cháy sém mép giấy cuộn khi chuyển cảnh. | Viết mới `res://shaders/paper_transition.gdshader` cho màn hình Briefing. |
| `effect_sepia.fsh` | Chỉnh màu nâu cổ điển toàn khung hình. | Dùng `CanvasModulate` hoặc bảng màu gốc của TileSet để tiết kiệm 1 pass đọc `hint_screen_texture` trên Web/Mobile. |

---

## 4. KIỂM KÊ HIỆU ỨNG & MÔ HÌNH BINH SĨ (`SpineEffects/` 427 Files & `Soldiers/` 661 Files)

* **`Assets/SpineEffects/` (427 files):** Gồm các bộ `.bin` (định dạng nhị phân Spine 4.1.21), `.atlas`, `.ktx` và một số `.png` (ví dụ `effect_attackable_area.*`, `effect_buff32.png`, `effect_buff33.png`, `effect_15000.bin`,...). Vì `.bin` và `.ktx` không nạp trực tiếp vào Godot 4.7 thuần GDScript, các hiệu ứng vòng chọn Hex, Sĩ khí, Khống chế và va chạm được dựng mới bằng **`Sprite2D` / `AnimatedSprite2D` (`SpriteFrames`)** và **`CPUParticles2D` Object Pool**.
* **`Assets/Soldiers/` (661 files):** Chứa các tệp `soldier_40101.png/.atlas/.bin` cùng ảnh ghép thử nghiệm (`ashigaru_composite_v2.png`, `composite_spearman_test.png`) và thư mục con `debug_parts/`. Trong giai đoạn prototype nội bộ, chỉ trích cắt từ các sheet `.png` sang `SpriteFrames` 2D của Godot; thư mục `debug_parts/` phải được dọn sạch trước khi đóng bản thử nghiệm.

---

## 5. KIỂM KÊ ĐỒ HỌA GIAO DIỆN (`Assets/UI/` — 989 Files)

Cấu trúc thực tế trên ổ đĩa gồm đúng **7 thư mục con** (không có thư mục `UI/Atlas/*.xml` như mô tả cũ):
* **`UI/Avatars/` (740 files):** Ảnh chân dung đặt tên theo phiên âm Pinyin gồm cả bản `.png` và `.ktx` (ví dụ `AMin.png`, `AnGuoSiHuiQiong.png`). Chỉ sử dụng các tệp `.png` nếu cần gán tạm làm avatar placeholder trong lúc chờ tranh vẽ tướng Đại Việt.
* **`UI/Battle/` (141 files `.png`):** Các biểu tượng chỉ dẫn chiến trường cắt sẵn (`anno_arrow.png`, `anno_capital.png`, `anno_city.png`, khung máu, cờ hiệu, nút điều khiển trận đánh).
* **`UI/BattleAtlas/` (2 files `.png`):** Hai tấm spritesheet tổng hợp `battlegen_hd.png` và `battleres_hd.png` (dùng `AtlasTexture` của Godot để cắt vùng hiển thị nếu cần).
* **`UI/Chapters/` (71 files `.png`):** Các tấm nền minh họa chương chiến dịch (`chapter_1.png`, `chapter_10.png`,...).
* **`UI/Treasures/` (17 files `.png`):** Biểu tượng trang bị/ấn tín cấp đội quân (`equip_team_101.png` $\to$ `equip_team_117.png`).
* **`UI/Gacha/` (9 files `.png`) & `UI/Store/` (9 files `.webp`, `.png`):** Các khung nền giao diện tham chiếu (`luck_draw_*.png`, `purchase_*.webp`) — nằm ngoài phạm vi Slice-01 MVP.

---

## 6. MÃ NGUỒN HELPER ĐƯỜNG DẪN CHUẨN (`res://scripts/core/asset_paths.gd`)

Mọi hằng số dưới đây tuân thủ nghiêm ngặt quy tắc:
1. Nhóm `res://Assets/...` **chỉ trỏ tới các tệp thực sự tồn tại trên ổ đĩa** (ví dụ dùng `sfx_knifestrike1.wav` và `sfx_StrikeIron.wav` cho đao kiếm cận chiến).
2. Nhóm Shader trỏ tới tệp **`.gdshader`** viết mới cho Godot 4.7 tại `res://shaders/`.
3. Nhóm Dữ liệu cấu hình trỏ tới tệp **JSON chữ thường** tại `res://data/`.

```gdscript
# res://scripts/core/asset_paths.gd
class_name AssetPaths
extends RefCounted

# --- AUDIO SFX PLACEHOLDERS (Xác thực tồn tại 100% trong res://Assets/Audio/) ---
const SFX_SWORD_STRIKE: String   = "res://Assets/Audio/sfx_StrikeIron.wav"
const SFX_KNIFE_STRIKE: String   = "res://Assets/Audio/sfx_knifestrike1.wav"
const SFX_SHIELD_BLOCK: String   = "res://Assets/Audio/sfx_block1.wav"
const SFX_SPEAR_PIERCE: String   = "res://Assets/Audio/sfx_pierce.wav"
const SFX_CROSSBOW: String       = "res://Assets/Audio/sfx_crossbow.wav"
const SFX_ARCHERY_SHOOT: String  = "res://Assets/Audio/sfx_archery.wav"
const SFX_ARROW_HIT: String      = "res://Assets/Audio/sfx_archery4.wav"
const SFX_NAVAL_AMBIENCE: String = "res://Assets/Audio/sfx_naval.wav"
const SFX_WATER_WAVE: String     = "res://Assets/Audio/sfx_wave.wav"
const SFX_SHIP_CRASH: String     = "res://Assets/Audio/sfx_shiphit.wav"
const SFX_FIRE_BURN: String      = "res://Assets/Audio/sfx_burn.wav"
const SFX_ELEPHANT_MOVE: String  = "res://Assets/Audio/sfx_elephant_move.wav"
const SFX_CAVALRY_MOVE: String   = "res://Assets/Audio/sfx_cavalrymove.wav"
const SFX_CHAOS: String          = "res://Assets/Audio/sfx_chaos.wav"
const SFX_WAR_HORN: String       = "res://Assets/Audio/sfx_horn.wav"
const SFX_UI_CLICK: String       = "res://Assets/Audio/sfx_click.wav"
const SFX_UI_SELECT: String      = "res://Assets/Audio/sfx_select.wav"
const SFX_VICTORY: String        = "res://Assets/Audio/victory.wav"
const SFX_DEFEAT: String         = "res://Assets/Audio/defeat.wav"

# --- SFX HỎA KHÍ (ERA-GATED: Chỉ nạp cho màn chơi Thế kỷ XV+, khóa ở Bạch Đằng 1288) ---
const SFX_ERA15_NAVAL_GUN: String = "res://Assets/Audio/sfx_naval_gun.wav"
const SFX_ERA15_GUNFIRE: String   = "res://Assets/Audio/sfx_gunfire.wav"

# --- UI PLACEHOLDERS (Xác thực tồn tại trong res://Assets/UI/) ---
const TEX_BATTLE_RES_ATLAS: String = "res://Assets/UI/BattleAtlas/battleres_hd.png"
const TEX_BATTLE_GEN_ATLAS: String = "res://Assets/UI/BattleAtlas/battlegen_hd.png"
const TEX_ANNO_CAPITAL: String     = "res://Assets/UI/Battle/anno_capital.png"

# --- GODOT 4.7 NATIVE SHADERS (.gdshader viết mới, KHÔNG dùng .fsh của Cocos2d-x) ---
const SHADER_HIT_FLASH: String   = "res://shaders/hit_flash.gdshader"
const SHADER_WATER_RIVER: String = "res://shaders/water_river.gdshader"
const SHADER_WATER_FOAM: String  = "res://shaders/water_foam.gdshader"
const SHADER_DISSOLVE: String    = "res://shaders/unit_dissolve.gdshader"

# --- STATIC GAME DATA SCHEMAS (Chữ thường 100% chuẩn Web & Android) ---
const DATA_TROOP_SETTINGS: String  = "res://data/settings/troop_settings.json"
const DATA_STAGE_SETTINGS: String  = "res://data/settings/stage_settings.json"
const DATA_TACTIC_SETTINGS: String = "res://data/settings/tactic_settings.json"
const DATA_BATTLE_10101: String    = "res://data/battles/battle_10101.json"
```

---

## 7. CẢNH BÁO PHÁP LÝ BẢN QUYỀN (IP COMPLIANCE) & LỘ TRÌNH THAY THẾ 100% TÀI SẢN

> [!CAUTION] **Cảnh báo Pháp lý Sở hữu Trí tuệ Bắt buộc (Strict IP & Copyright Policy):**  
> Toàn bộ 2,464 tệp trong thư mục `Assets/` trích xuất từ *Great Conqueror 2: Shogun* là tài sản có bản quyền của bên thứ ba, **chỉ được phép lưu giữ cục bộ trên máy cá nhân của nhà phát triển làm Placeholder tạm thời để nghiên cứu kỹ thuật và kiểm chứng vòng lặp gameplay (Internal R&D / Prototyping)**.  
> - **TUYỆT ĐỐI KHÔNG** đẩy (`git push`) thư mục `Assets/` gốc của Shogun lên bất kỳ kho mã nguồn công khai (Public Repository) nào.  
> - **TUYỆT ĐỐI KHÔNG** sử dụng lại bất kỳ tệp hình ảnh, biểu tượng UI, bản nhạc BGM, hiệu ứng âm thanh SFX hay mã nguồn shader gốc nào của Shogun trong các bản phát hành thử nghiệm công khai (Public Demo) hoặc bản thương mại chính thức (**1.0 Release**).

| Giai đoạn Sản xuất | Trạng thái Tài sản & Giới hạn Sử dụng | Mục tiêu Chuyển đổi & Thay thế Tài sản |
| :--- | :--- | :--- |
| **Giai đoạn Nội bộ MVP (P1 – P2 / Slice-01)** | Chỉ chạy thử nghiệm nội bộ trên máy cá nhân với Placeholder `Assets/` kết hợp `.gdshader` và `res://data/*.json` biên soạn mới. | Kiểm chứng hoàn chỉnh lưới Hex `12×10`, thủy chiến Bạch Đằng 1288, Sĩ khí, AI 5 Evaluators và hiệu năng 60 FPS; dọn sạch thư mục nháp `Assets/Soldiers/debug_parts/`. |
| **Giai đoạn Alpha (P3)** | Thay thế toàn bộ tài sản nhận diện mặt trận chính trước khi playtest diện rộng. | Vẽ mới hoàn toàn TileSet sông núi Việt Nam, bãi cọc gỗ Bạch Đằng, chiến thuyền Đại Việt – Đại Nguyên, tiểu đội `SpriteFrames` 2D và chân dung các danh tướng thời Trần. |
| **Giai đoạn Beta (P4)** | Thay thế toàn bộ Giao diện (UI), Nhạc nền (BGM) & Hiệu ứng hạt. | Thiết kế bộ khung UI mang họa tiết mỹ thuật thời Lý – Trần – Lê; sản xuất nhạc nền nhạc cụ dân tộc độc quyền (đàn tranh, đàn bầu, sáo trúc, trống trận). |
| **Giai đoạn Hoàn Thiện Chính Thức (P5 / 1.0)** | **100% tài sản độc quyền hoặc có giấy phép thương mại hợp pháp của dự án; XÓA SẠCH 100% thư mục `Assets/` của Shogun.** | **Thay thế triệt để 100% toàn bộ Art, Sprites, UI, BGM, SFX và Shaders** sang tài sản hợp pháp mang bản sắc lịch sử Việt Nam — không giữ lại bất kỳ tệp SFX hay shader nào từ Shogun. |
