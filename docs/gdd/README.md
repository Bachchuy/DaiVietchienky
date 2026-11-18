# ĐẠI VIỆT CHIẾN KỲ (DAI VIET CHRONICLES)
## GAME DESIGN DOCUMENT (GDD) — Phiên bản 3.4.1
**Trạng thái:** Baseline Candidate (Đồng bộ Kiểm toán 18/11/2026) — Freeze sau CP4 & Gate P2  
**Công nghệ & Nền tảng:** Godot 4.7 | Thuần GDScript 2.0 (Typed GDScript) | Renderer `gl_compatibility` | Mục tiêu: **Web (HTML5/Wasm) + Android** (Phát triển & kiểm thử trên Windows Desktop) | **60 FPS**  
**Phạm vi sản phẩm:** Historical Military Turn-Based Strategy (Single-player; khởi đầu với **Slice-01: Đại Chiến Bạch Đằng 1288 — `stage_id: 10101`**; tầm nhìn dài hạn: **Từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII — Triều Tây Sơn** theo từng *Era Pack*)

---

## Cấu trúc cây thư mục tài liệu (Document Tree Map)

Để tối ưu hóa việc tra cứu và tiết kiệm token ngữ cảnh khi làm việc với AI/Agent, tài liệu thiết kế được tổ chức thành các module chuyên biệt và liên kết chặt chẽ với danh mục tài nguyên dự án:

```text
docs/
├── build_master_gdd.py                            # [Script đồng bộ xuất bản Master GDD hợp nhất]
├── assets/
│   └── ASSET_CATALOG.md                           # [Sổ tay quản lý 2,464 files trong Assets/ & 85 JSON tham chiếu]
│
└── gdd/
    ├── README.md                                  # [Bản đồ chỉ mục & Điều hướng toàn bộ GDD]
    │
    ├── 00_overview/                               # TỔNG QUAN, QUẢN TRỊ PHIÊN BẢN & QUY ƯỚC
    │   ├── document_control.md                    # Quản lý tài liệu, Tech Stack Godot 4.7, bảng LOCKED vs OPEN
    │   ├── conventions_glossary.md                # 00. Quy ước đọc (MUST/SHOULD/OPEN/Fixture) & Core Glossary
    │   ├── product_summary.md                     # 01. Tóm tắt sản phẩm, logline & lộ trình Era Pack lịch sử
    │   └── CHANGELOG_3.3_to_3.4.md                # Lịch sử tiến hóa 0.1 → 3.4.1, quyết định khóa D-01..D-09 & ánh xạ module
    │
    ├── 01_vision_player/                          # TẦM NHÌN & TRẢI NGHIỆM NGƯỜI CHƠI
    │   ├── vision_pillars.md                      # 02. Tầm nhìn, định vị 7 benchmark & 5 trụ cột thiết kế
    │   └── player_experience.md                   # 03. Chân dung người chơi, hành trình Bạch Đằng, pacing & anti-experience
    │
    ├── 02_gameplay_systems/                       # HỆ THỐNG GAMEPLAY CHIẾN TRƯỜNG
    │   ├── core_loop.md                           # 04. Vòng lặp chính (Core Loop) & Battle Loop 7 pha
    │   ├── game_modes.md                          # 05. Bốn chế độ chơi (Scenario, Conquest, Legion, Domination)
    │   ├── battlefield_rules.md                   # 06. Hex topology, địa hình, ZOC, Seeded RNG combat, morale 4 bậc, thủy chiến
    │   ├── units_commanders.md                    # 07. Binh chủng, vai trò chiến thuật, tướng lĩnh & UniqueSkill
    │   ├── factions_economy.md                    # 08. Thế lực và kinh tế chiến lược (P3 scope)
    │   └── meta_progression.md                    # 09. Tiến trình danh tướng & cân bằng F2P thân thiện (P3/P4+ scope)
    │
    ├── 03_content_presentation/                   # NỘI DUNG, GIAO DIỆN & TRÌNH BÀY
    │   ├── historical_framework.md                # 10. Tính toàn vẹn lịch sử, Evidence grade, ModelingType, Bạch Đằng
    │   ├── ui_ux.md                               # 11. Nguyên tắc UI/UX Map-First, camera, Combat Preview, quy tắc Undo
    │   ├── ai_difficulty.md                       # 12. Triết lý AI công bằng, Scenario Director & 4 mức độ khó
    │   └── audio_visual_narrative.md              # 13. Mỹ thuật 2D cách điệu, âm thanh & dẫn dắt lịch sử
    │
    ├── 04_production_roadmap/                     # SẢN XUẤT, ROADMAP & QUYẾT ĐỊNH MỞ
    │   ├── production_scope_mvp.md                # 14. Tách bạch Slice-01 (P2) & Release MVP Thời Trần (P5), DoD [D-17]
    │   ├── risks_open_decisions.md                # 15. Rủi ro (IP Risk, Web/Mobile 60FPS), quyết định khóa & mở (D-01..D-17)
    │   └── implementation_plan.md                 # 16. Checkpoints CP1–CP5, lộ trình W1–W12, Gates P1–P5 & kiểm thử tự động
    │
    ├── mechanics/                                 # [CHUYÊN SÂU] MICRO-MODULES CƠ CHẾ CHIẾN THUẬT
    │   ├── combat_formulas.md                     # Seeded RNG (80%–100% + Crit), Giáp 100/(100+EffectiveDef), TroopStack & Phản kích
    │   ├── morale_and_status.md                   # 4 bậc Enum Sĩ khí (HIGH/NORMAL/LOW/CHAOS), TrappedLevel & 7 hiệu ứng CC
    │   ├── hex_grid_pathfinding.md                # Lưới Hex Axial, FondTerrain, cơ chế ZoC/CoC (IgnoreZoc/DevoidZoc)
    │   └── battlefield_economy.md                 # (P3 scope; ẩn ở Slice-01) 4 tài nguyên, MealFood, Starvation, cướp lương & chợ
    │
    ├── progression/                               # [CHUYÊN SÂU] TIẾN TRÌNH META & DANH TƯỚNG
    │   └── generals_and_meta_economy.md           # (P3/P4+ scope) 4 trục Tướng, Duyên phận Fetters, Chiêu mộ F2P thân thiện (Ngọc Bích + Pity)
    │
    ├── vfx_sfx/                                   # [CHUYÊN SÂU] VFX, SFX & PHẢN HỒI VA CHẠM (POLISH)
    │   └── vfx_sfx_and_polish.md                  # Trauma Shake, Hit-Stop, Squash & Stretch, GPUParticles2D, Audio Pooling
    │
    ├── ai/                                        # [CHUYÊN SÂU] HỆ THỐNG TRÍ TUỆ NHÂN TẠO MÁY
    │   └── ai_decision_matrix.md                  # Kiến trúc 3 pha: Generators, Evaluators, Utility Scoring & code mẫu GDScript Godot 4.7
    │
    ├── architecture/                              # [CHUYÊN SÂU] KIẾN TRÚC DỮ LIỆU & SAVE/LOAD
    │   └── data_and_save_system.md                # Phân lớp scripts/core & scripts/presentation, JSON schemas, Command Pattern & Save 2 tầng
    │
    ├── ui_ux/                                     # [CHUYÊN SÂU] GIAO DIỆN & KẾT XUẤT ĐỒ HỌA
    │   └── battle_ui_and_rendering.md             # 15 Render Layers, FSM input 5 trạng thái, Combat Preview 2 bước, StrategicZoom 60 FPS
    │
    ├── level_design/                              # [CHUYÊN SÂU] THIẾT KẾ MÀN CHƠI & KỊCH BẢN
    │   └── scenario_scripting_and_events.md       # Triggers, Conditions, Actions, mục tiêu 3 sao & Bộ quy chuẩn kịch bản 5 bước
    │
    └── appendices/                                # PHỤ LỤC TRA CỨU
        ├── appendix_a_benchmark_matrix.md         # Phụ lục A: Feature Reference Matrix (7 benchmark) & Checklist đo lường UX
        ├── appendix_b_sources.md                  # Phụ lục B: Nguồn sử liệu chính sử, khảo cổ Bạch Đằng & benchmark [S1]–[S16]
        └── appendix_c_extended_glossary.md        # Phụ lục C: Bảng giải nghĩa thuật ngữ chuyên sâu mở rộng
```

---

## Bảng mục lục & Tóm tắt nhanh từng module

| Module | Tệp chi tiết | Nội dung chính |
|---|---|---|
| **00. Overview** | [document_control.md](00_overview/document_control.md) | Trạng thái baseline 3.4.1, Tech Stack Godot 4.7 (Thuần GDScript 2.0), bảng LOCKED vs OPEN. |
| | [conventions_glossary.md](00_overview/conventions_glossary.md) | Quy ước MUST/SHOULD/MAY/OPEN/Fixture, thuật ngữ nền tảng (ZOC, Morale 4 bậc, Seeded RNG,...). |
| | [product_summary.md](00_overview/product_summary.md) | Thể loại Hex wargame theo lượt, logline, phạm vi từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (Tây Sơn) theo *Era Pack* và Slice-01. |
| | [CHANGELOG_3.3_to_3.4.md](00_overview/CHANGELOG_3.3_to_3.4.md) | Lịch sử tiến hóa `0.1 → 3.3 → 3.4 → 3.4.1`, giải trình quyết định khóa `D-01..D-03`, `D-06`, `D-09` và bảng ánh xạ tách module. |
| **Mechanics Modules** | [combat_formulas.md](mechanics/combat_formulas.md) | Công thức sát thương **Controlled RNG có Seed tất định (`Seeded RNG`: `80%–100%` + Bạo kích, 100% Deterministic Replay)**, Giáp chuẩn `100 / (100 + EffectiveDef)`, gộp cờ `TroopStack` (1x–3x), hiển thị minh bạch khoảng Min–Max & `% Crit` trên Combat Preview (không có miss đòn ngẫu nhiên) và Phản kích. |
| | [morale_and_status.md](mechanics/morale_and_status.md) | Đặc tả **4 bậc Enum Sĩ khí rời rạc** (`HIGH`, `NORMAL`, `LOW`, `CHAOS` — khóa hành động tạm thời theo lượt rồi tự hồi về `LOW`), bao vây `TrappedLevel` đa cấp, lan truyền `NeighboringDeadMates`. |
| | [hex_grid_pathfinding.md](mechanics/hex_grid_pathfinding.md) | Hệ tọa độ Hex Pointy-topped Axial, địa hình sở trường (`FondTerrain`), cơ chế ZoC/CoC (`IgnoreZoc`, `DevoidZoc`) & định tuyến A*. |
| | [battlefield_economy.md](mechanics/battlefield_economy.md) | **(P3 scope — ẩn trong Slice-01 với `enable_economy = false`)** Kinh tế chiến trường: 4 tài nguyên (`Coin`, `Food`, `Tech`, `Mana`), `OnBeginRound`, `MealFood`, Nạn đói (`Starvation`), cướp lương & giao thương. |
| **Progression & Meta** | [generals_and_meta_economy.md](progression/generals_and_meta_economy.md) | **(P3/P4+ scope)** 4 trục tiến trình Tướng, Duyên phận lịch sử (`Fetters`), chiêu mộ 5 bậc phẩm theo hướng **F2P thân thiện** (tích lũy Ngọc Bích & Lệnh Chiêu Mộ qua thành tựu/3 sao/sự kiện + Pity, không khóa danh tướng lịch sử sau paywall tiền thật) & Shop Quân công. |
| **VFX, SFX & Polish** | [vfx_sfx_and_polish.md](vfx_sfx/vfx_sfx_and_polish.md) | Phản hồi va chạm đầm tay (Trauma shake, Hit-stop, Squash & Stretch), hệ thống hạt `GPUParticles2D` và Audio Pooling. |
| **AI System** | [ai_decision_matrix.md](ai/ai_decision_matrix.md) | Bộ lọc Generators, Evaluators, công thức Utility Scoring và **code mẫu GDScript Godot 4.7**. |
| **Architecture** | [data_and_save_system.md](architecture/data_and_save_system.md) | Kiến trúc phân lớp GDScript (`scripts/core/` & `scripts/presentation/`), JSON schemas, vòng lặp 7 pha Turn/Phase, Command Pattern (`Seeded RNG` replay) và Save 2 tầng. |
| **Asset Catalog** | [ASSET_CATALOG.md](../assets/ASSET_CATALOG.md) | Sổ tay quản lý **2,464 files** thực tế trong `Assets/` (Audio SFX/BGM, Shaders, Buildings, Soldiers, SpineEffects, UI/Avatars) và 85 tệp Data JSON tham chiếu (dùng làm placeholder nội bộ). |
| **UI/UX & Rendering** | [battle_ui_and_rendering.md](ui_ux/battle_ui_and_rendering.md) | 15 Render Layers trên `gl_compatibility`, FSM tương tác 5 trạng thái, Combat Preview 2 bước, `StrategicZoom` duy trì 60 FPS trên Web & Android. |
| **Level Design** | [scenario_scripting_and_events.md](level_design/scenario_scripting_and_events.md) | Hệ thống Triggers, Conditions, Actions, mục tiêu 3 sao và Bộ quy chuẩn thiết kế kịch bản 5 bước (`stage_id: 10101`). |
| **01. Vision & Player** | [vision_pillars.md](01_vision_player/vision_pillars.md) | 5 trụ cột thiết kế, phân vai 7 benchmark (*GC2: Shogun*, *EW7*, *Panzer Corps 2*, *UoC II*, *HoI IV*,...), non-goals. |
| | [player_experience.md](01_vision_player/player_experience.md) | Chân dung người chơi, hành trình nhử giặc vào bãi cọc ngầm trong Slice-01, nhịp độ 10–30p, anti-experience. |
| **02. Gameplay** | [core_loop.md](02_gameplay_systems/core_loop.md) | Core Loop 5 bước, 7 pha Battle Loop, nguyên tắc ngân sách di chuyển và hành động. |
| | [game_modes.md](02_gameplay_systems/game_modes.md) | Scenario (khóa hồ sơ tướng `Preset Loadout`), Conquest, Legion, Domination dùng chung luật chiến trường. |
| | [battlefield_rules.md](02_gameplay_systems/battlefield_rules.md) | Hex map, 8 loại địa hình, ZOC `[D-12]`, combat **Controlled RNG có Seed tất định (`Seeded RNG` — 100% Deterministic Replay, `RoundHalfUp`, giáp `100/(100+EffectiveDef)`, phản kích `[D-11]`)**, flank, **4 bậc Sĩ khí Enum (`HIGH`/`NORMAL`/`LOW`/`CHAOS`) `[D-13]`**, thủy chiến & bãi cọc `StakedWater` `[D-14]`, kỵ binh. |
| | [units_commanders.md](02_gameplay_systems/units_commanders.md) | Thủy quân + 4 nhánh lục quân (Cung/Nỏ, Kỵ, Bộ, Công thành), vai trò tướng, `UniqueSkill` & `CommandProfile`. |
| | [factions_economy.md](02_gameplay_systems/factions_economy.md) | **(P3 scope)** Thế lực, thành lũy, hậu cần trong trận và thị trường giao thương khẩn cấp. |
| | [meta_progression.md](02_gameplay_systems/meta_progression.md) | **(P3/P4+ scope)** Nguyên tắc tiến trình không phá hỏng chiến thuật, 4 trục tướng, duyên phận lịch sử và định hướng F2P thân thiện `[D-07]`. |
| **03. Presentation** | [historical_framework.md](03_content_presentation/historical_framework.md) | `Evidence grade` A/B/C/D, `ModelingType` (fact vs abstraction/What-if), tách biệt hồ sơ Bạch Đằng 938/981/1288. |
| | [ui_ux.md](03_content_presentation/ui_ux.md) | Nguyên tắc Map-First, camera điều hướng, Combat Preview minh bạch, luật 1 lần Undo/lượt. |
| | [ai_difficulty.md](03_content_presentation/ai_difficulty.md) | AI tuân thủ cùng luật & thông tin như người chơi, Scenario Director, 4 mức độ khó. |
| | [audio_visual_narrative.md](03_content_presentation/audio_visual_narrative.md) | Art direction bản đồ cổ cách điệu 2D, âm thanh UI dứt khoát, briefing ngắn gọn. |
| **04. Production** | [production_scope_mvp.md](04_production_roadmap/production_scope_mvp.md) | Milestone `P0–P5`, tách bạch **Slice-01 (Mốc P2 — Bạch Đằng 1288 `12×10` hex, 10 lượt, `SignalDock`)** và **Release MVP (Mốc P5 — Gói Thời Trần 6–8 màn)**, DoD & tiêu chí playtest `[D-17]`. |
| | [risks_open_decisions.md](04_production_roadmap/risks_open_decisions.md) | Rủi ro (gồm IP Risk & hiệu năng Web/Android 60 FPS), tổng hợp quyết định đã khóa (`D-01..D-14`) & bảng quyết định mở (`D-04..D-17`). |
| | [implementation_plan.md](04_production_roadmap/implementation_plan.md) | Checkpoints kỹ thuật `CP1–CP5` ánh xạ `P0–P5`, lộ trình `W1–W12`, Design/Tech Gates `P1–P5` và kiểm thử headless + screenshot. |
| **Appendices** | [appendix_a_benchmark_matrix.md](appendices/appendix_a_benchmark_matrix.md) | Bảng phân tích học hỏi từ 7 game benchmark (gồm *Hearts of Iron IV* & *European War 7*) và Checklist đo lường định lượng UX/Tactical. |
| | [appendix_b_sources.md](appendices/appendix_b_sources.md) | Danh mục nguồn sử liệu chính sử, báo cáo khảo cổ học Bạch Đằng và game tham khảo `[S1]`–`[S16]`. |
| | [appendix_c_extended_glossary.md](appendices/appendix_c_extended_glossary.md) | Giải thích hơn 20 thuật ngữ chuyên sâu (`TroopStack`, `TrappedLevel`, `StakedWater`, `SignalDock`, `StrategicZoom`, `ModelingType`,...). |

---

## Quy trình đồng bộ tài liệu Master GDD

Mọi chỉnh sửa thiết kế **BẮT BUỘC** thực hiện trực tiếp trên các tệp module thành phần nằm trong `docs/gdd/` (nguồn chân lý duy nhất — *Single Source of Truth*), không sửa tay trực tiếp lên tệp tổng hợp. Sau khi hoàn tất cập nhật ở các module con, chạy script tổng hợp từ thư mục gốc dự án để tái xuất bản tệp Master GDD phục vụ lưu trữ hoặc gửi phản biện tổng thể:

```powershell
python docs/build_master_gdd.py
```

Script sẽ tự động đọc toàn bộ các module trong `docs/gdd/` cùng `docs/assets/ASSET_CATALOG.md`, lược bỏ thanh điều hướng cục bộ và xuất bản tệp hợp nhất tại `docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md`.

---

## Hướng dẫn cho AI & Agent khi tra cứu

1. **Tra cứu quy tắc chiến đấu, `Seeded RNG` & công thức giáp:** Đọc [combat_formulas.md](mechanics/combat_formulas.md) và [battlefield_rules.md](02_gameplay_systems/battlefield_rules.md).
2. **Tra cứu 4 bậc Sĩ khí Enum, bao vây `TrappedLevel` & `CHAOS`:** Đọc [morale_and_status.md](mechanics/morale_and_status.md).
3. **Tra cứu lưới Hex Axial, địa hình `FondTerrain` & ZoC/CoC:** Đọc [hex_grid_pathfinding.md](mechanics/hex_grid_pathfinding.md).
4. **Tra cứu kinh tế chiến trường & Nạn đói (`Starvation` — P3 scope):** Đọc [battlefield_economy.md](mechanics/battlefield_economy.md) và [factions_economy.md](02_gameplay_systems/factions_economy.md).
5. **Tra cứu tiến trình tướng, duyên phận `Fetters` & F2P thân thiện:** Đọc [generals_and_meta_economy.md](progression/generals_and_meta_economy.md) và [meta_progression.md](02_gameplay_systems/meta_progression.md).
6. **Tra cứu VFX, SFX, rung camera & độ đầm va chạm (Juice):** Đọc [vfx_sfx_and_polish.md](vfx_sfx/vfx_sfx_and_polish.md) và [audio_visual_narrative.md](03_content_presentation/audio_visual_narrative.md).
7. **Tra cứu kiến trúc thuật toán AI (GDScript Godot 4.7):** Đọc [ai_decision_matrix.md](ai/ai_decision_matrix.md) và [ai_difficulty.md](03_content_presentation/ai_difficulty.md).
8. **Tra cứu kiến trúc phân lớp GDScript, dữ liệu JSON & Save/Load:** Đọc [data_and_save_system.md](architecture/data_and_save_system.md).
9. **Tra cứu thiết kế Slice-01 (P2) vs Release MVP Thời Trần (P5):** Chỉ cần đọc [production_scope_mvp.md](04_production_roadmap/production_scope_mvp.md).
10. **Tra cứu quyết định đã khóa / còn mở & quản trị rủi ro:** Đọc [risks_open_decisions.md](04_production_roadmap/risks_open_decisions.md) và [CHANGELOG_3.3_to_3.4.md](00_overview/CHANGELOG_3.3_to_3.4.md).
11. **Tra cứu lộ trình triển khai `CP1–CP5`, `W1–W12` & kiểm thử headless:** Đọc [implementation_plan.md](04_production_roadmap/implementation_plan.md).
12. **Tra cứu nguyên tắc lịch sử, thẩm định & nguồn sử liệu `[S1]–[S16]`:** Đọc [historical_framework.md](03_content_presentation/historical_framework.md) và [appendix_b_sources.md](appendices/appendix_b_sources.md).
13. **Tra cứu UI Map-First, Camera, Render Layers & `StrategicZoom`:** Đọc [ui_ux.md](03_content_presentation/ui_ux.md) và [battle_ui_and_rendering.md](ui_ux/battle_ui_and_rendering.md).
14. **Tra cứu quy chuẩn kịch bản màn chơi & sự kiện `MapPhase_TideFall`:** Đọc [scenario_scripting_and_events.md](level_design/scenario_scripting_and_events.md).
15. **Tra cứu danh mục 2,464 tài nguyên tham chiếu (Audio, Shaders, UI, Data JSONs):** Đọc [ASSET_CATALOG.md](../assets/ASSET_CATALOG.md).
