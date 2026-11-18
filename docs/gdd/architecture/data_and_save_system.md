# ĐẶC TẢ KIẾN TRÚC DỮ LIỆU, VÒNG LẶP 7 PHA & HỆ THỐNG SAVE/LOAD
## DỰ ÁN: ĐẠI VIỆT CHIẾN KỲ (VIETNAM HISTORY STRATEGY)
### MODULE: DATA ARCHITECTURE, 7-PHASE TURN LOOP, COMMAND UNDO & PERSISTENCE
*(Chuẩn hóa cho Godot 4.7 — Thuần Typed GDScript 2.0, `gl_compatibility`, Web & Android 60 FPS)*

> **Vị trí tài liệu:** `docs/gdd/architecture/data_and_save_system.md`  
> **Trạng thái:** Thiết kế thuần **Typed GDScript 2.0** cho Godot 4.7, chuẩn hóa đường dẫn JSON chữ thường tương thích tuyệt đối với hệ thống tệp phân biệt hoa-thường trên Web/Android, đồng bộ **Vòng lặp Chiến trường 7 Pha**, **Command Pattern (chỉ `MarchCommand` hỗ trợ Undo 5 điều kiện)** và **Save 2 tầng chống Crash / chống Desync RNG & Event**.

---

## 1. Tổng quan Kiến trúc Dữ liệu 3 Tầng (Three-Tier Data Architecture)

Hệ thống quản trị dữ liệu tách biệt rành mạch giữa dữ liệu cấu hình tĩnh (`res://data/` — chỉ đọc), phiên trận đánh đang diễn ra (`user://saves/battle_session.json`), và hồ sơ tiến trình của người chơi (`user://saves/player_profile.json`):

```mermaid
graph TD
    subgraph Tier1["TẦNG 1: DỮ LIỆU CẤU HÌNH TĨNH (READ-ONLY STATIC DATA)"]
        A["res://data/settings/*.json & res://data/battles/*.json\n(troop_settings, stage_settings, tactic_settings, battle_10101)"]
        -->|DataCenter.load_all()| B["Static Data Cache\n(Autoload Read-Only Dictionaries)"]
    end

    subgraph Tier2["TẦNG 2: PHIÊN TRẬN ĐÁNH (BATTLE SESSION STATE)"]
        C["user://saves/battle_session.json\n(HexMap, Units, Round, rng_seed, rng_state, triggered_event_ids)"]
        <-->|Turn Boundary / Pause Auto-Save\nWeb IndexedDB Safe| D["BattleGameController & ScenarioEventManager\n(7-Phase Live Battle Loop)"]
    end

    subgraph Tier3["TẦNG 3: HỒ SƠ NGƯỜI CHƠI (META-PROGRESSION PROFILE)"]
        E["user://saves/player_profile.json & player_profile.bak\n(Chiến dịch đã mở, Sao đạt được, Tướng, Cài đặt)"]
        <-->|BattleSaveManager.save_player_profile()| F["PlayerProfileCache\n(Dual-Backup Persistent Storage)"]
    end
```

> [!NOTE] **Quy ước Đường dẫn Hệ thống Tệp (Web & Android Case-Sensitivity):**
> - Toàn bộ tệp dữ liệu thiết kế mới của dự án đặt trong **`res://data/`** và bắt buộc viết **chữ thường `snake_case` 100%** (`res://data/settings/troop_settings.json`, `res://data/battles/battle_10101.json`,...).
> - Các thư mục tài nguyên đồ họa/âm thanh placeholder sẵn có trên ổ đĩa giữ nguyên đúng phân biệt hoa-thường thực tế là **`res://Assets/...`**.
> - Dữ liệu lưu của người chơi luôn ghi vào **`user://saves/`** (tuyệt đối không ghi vào `res://` vì `res://` bị khóa chỉ-đọc sau khi xuất bản Web/APK).

---

## 2. Đặc tả Schema Dữ liệu Cấu hình Tĩnh (Static JSON Schemas)

### 2.1. Binh chủng (`res://data/settings/troop_settings.json`)
Bổ sung đầy đủ phân nhánh chỉ huy (`command_branch`), miền di chuyển (`domain`), kiểu công/thủ (`attack_mode`, `defense_mode`), tầm nhìn (`vision_range`), giới hạn gộp cờ (`max_stack`), khẩu phần lương (`meal_food`) và điểm cơ động chuẩn chiến thuật (`3–5 MP`):

```json
[
  {
    "id": 40101,
    "code": "dai_viet_spear_infantry",
    "name": "Bộ Binh Trường Giáo",
    "command_branch": "Infantry",
    "domain": "Land",
    "attack_mode": "Piercing",
    "defense_mode": "MediumArmor",
    "min_attack": 30,
    "max_attack": 40,
    "defence": 12,
    "strength": 160,
    "max_stack": 3,
    "mobility": 4,
    "vision_range": 3,
    "min_range": 1,
    "max_range": 1,
    "critical_percent": 5,
    "counter_percent": 100,
    "fond_terrain": "Forest",
    "damage_deepen": 0,
    "damage_resist": 0,
    "features": ["anti_cavalry_brace", "forest_ambush"],
    "cost_coin": 40,
    "cost_food": 50,
    "meal_food": 10,
    "unit_scene": "res://scenes/units/dai_viet_spear_infantry.tscn",
    "attack_sound": "res://Assets/Audio/sfx_pierce.wav"
  }
]
```

### 2.2. Danh mục Màn chơi Chiến dịch (`res://data/settings/stage_settings.json`)
Đồng bộ đầy đủ thông số chuẩn của **Slice-01 Đại Chiến Bạch Đằng 1288 (`stage_id: 10101`)**: `max_rounds = 10`, `enable_economy = false`, phe đối phương `"Đại Nguyên (Quân Nguyên)"` (`"Tran_Nguyen"`), điều kiện Thắng/Thua và thử thách 3 Sao:

```json
[
  {
    "id": 10101,
    "code": "bach_dang_1288",
    "name": "Đại Chiến Bạch Đằng 1288",
    "chapter_id": 1,
    "historical_era": "Tran_Nguyen",
    "modeling_type": "fixture",
    "difficulty_default": "normal",
    "ai_profile": "normal",
    "general_seat": 2,
    "map_width": 12,
    "map_height": 10,
    "max_rounds": 10,
    "enable_economy": false,
    "battle_file": "res://data/battles/battle_10101.json",
    "banned_troop_ids": [],
    "victory_conditions": [
      {
        "type": "DefeatGeneralWhileHoldingArea",
        "target_general_id": 9001,
        "required_area_id": "signal_dock",
        "instant": true,
        "description": "Hạ gục Ô Mã Nhi trong khi giữ vững Bến Hiệu Lệnh (2, 8) -> Thắng ngay lập tức"
      },
      {
        "type": "HoldAreaAndEnemyCasualtyAtMaxRound",
        "required_area_id": "signal_dock",
        "min_enemy_defeated_percent": 75,
        "at_round": 10,
        "description": "Giữ vững Bến Hiệu Lệnh (2, 8) khi hết Vòng 10 và tiêu diệt >= 75% quân địch"
      }
    ],
    "defeat_conditions": [
      { "type": "LoseKeyArea", "area_id": "signal_dock", "description": "Mất Bến Hiệu Lệnh (2, 8) vào tay quân Đại Nguyên" },
      { "type": "GeneralDefeated", "target_general_id": 1001, "description": "Chủ tướng Trần Quốc Tuấn tử trận" },
      { "type": "AllUnitsEliminated", "faction_id": 1, "description": "Toàn bộ lực lượng Đại Việt bị loại khỏi vòng chiến" },
      { "type": "MaxRoundsUnfulfilled", "max_rounds": 10, "description": "Hết Vòng 10 mà chưa đạt điều kiện chiến thắng" }
    ],
    "star_conditions": [
      { "star": 1, "type": "Victory", "description": "Giành chiến thắng màn chơi" },
      { "star": 2, "type": "MaxRoundLimit", "max_rounds": 8, "description": "Giành chiến thắng trong vòng <= 8 lượt" },
      { "star": 3, "type": "CasualtyHpPercentLimit", "max_loss_percent": 20, "description": "Tổng HP tổn thất toàn quân ta <= 20%" }
    ],
    "reward_coins": 500,
    "reward_medals": 10
  }
]
```

### 2.3. Mưu lược & Kỹ năng Tướng (`res://data/settings/tactic_settings.json`)
Bổ sung bắt buộc trường thời gian hồi chiêu **`cooldown`** (tính theo số vòng):

```json
[
  {
    "id": 10001,
    "code": "hich_tuong_si",
    "name": "Hịch Tướng Sĩ",
    "mana_cost": 80,
    "cooldown": 3,
    "buff_ids": [90001],
    "range": 2,
    "target_type": "AllyArea",
    "effect_type": "ClearChaosAndBoostMorale",
    "icon": "res://Assets/UI/Battle/anno_capital.png"
  }
]
```

---

## 3. Kiến trúc Vòng lặp Chiến trường 7 Pha (7-Phase Battle Loop)

Đồng bộ tuyệt đối với [core_loop.md](../02_gameplay_systems/core_loop.md) và [scenario_scripting_and_events.md](../level_design/scenario_scripting_and_events.md):

```mermaid
sequenceDiagram
    autonumber
    actor Actor as Người Chơi / AI
    participant BC as BattleGameController
    participant Evt as ScenarioEventManager
    participant Map as BattleMapState
    participant Sav as BattleSaveManager

    Note over BC,Map: PHA 1: KHỞI TẠO VÒNG ĐẤU (OnBeginRound)
    BC->>Map: Tăng current_round (+1), giảm Cooldown kỹ năng (-1)
    BC->>Map: Nếu enable_economy == true -> Thu hoạch Coin/Food/Tech & trừ meal_food
    BC->>Evt: check_and_execute("OnRoundStart") (VD: Đầu Vòng 4 kích hoạt MapPhase_TideFall)

    loop Qua từng Phe (Player -> Ally -> Enemy -> Neutral)
        Note over BC,Map: PHA 2: KHỞI TẠO LƯỢT PHE (FactionPhaseStart)
        BC->>Map: Hồi phục current_mp = max_mobility, reset has_acted = false, has_used_undo_this_turn = false
        BC->>Evt: check_and_execute("OnFactionTurnStart")
        BC->>Sav: Auto-Save đầu lượt Người chơi (an toàn cho Web IndexedDB)

        loop Chu trình Ra Lệnh Đơn Vị
            Note over Actor,Map: PHA 3: QUAN SÁT & DỰ BÁO (Observation & Preview)
            BC->>Map: Cập nhật Fog of War (AIVisibleMapView) của phe đang đi
            Actor->>BC: Xem tầm đi, ZOC, LOS & Combat Preview 2 bước (hoặc AI gọi plan_turn)

            Note over Actor,Map: PHA 4: GỬI LỆNH (CommandExecution)
            Actor->>BC: Gửi BattleCommand (March / Attack / CastSkill / ApplyTactic / Wait)

            Note over BC,Evt: PHA 5: GIẢI QUYẾT, SỰ KIỆN TỨC THÌ & XÉT THẮNG/THUA NGAY
            BC->>Map: Thực thi lệnh, giải quyết phản kích & cập nhật Fog of War
            BC->>Evt: check_and_execute("OnAfterCommand") (OnEnterCell / GeneralClash / OnUnitDefeated)
            BC->>BC: check_immediate_victory_or_defeat() (Hạ Ô Mã Nhi khi giữ SignalDock -> Thắng ngay!)
        end

        Note over BC,Sav: PHA 6: KẾT THÚC LƯỢT PHE (OnFactionTurnEnd)
        Actor->>BC: Gửi EndTurnCommand
        BC->>Map: Giảm bộ đếm CC & Buff/Debuff (-1 turn: chaos_turns, march_disabled_turns, attack_disabled_turns) của phe vừa kết thúc lượt
        BC->>Sav: Ghi Checkpoint Auto-Save cuối lượt phe
    end

    Note over BC,Map: PHA 7: KẾT THÚC VÒNG & XÉT MỤC TIÊU CUỐI VÒNG (OnEndRound & VictoryCheck)
    BC->>Evt: check_and_execute("OnRoundEnd")
    BC->>BC: check_round_end_victory_or_defeat() (VD: Hết Vòng 10 giữ SignalDock + diệt >= 75% địch)
```

> **Lưu ý thiết kế quan trọng tại Pha 5 & Pha 6:**
> 1. **Xét Thắng / Thua tức thì ở Pha 5:** Ngay khi một lệnh thực thi xong làm thỏa mãn điều kiện kết thúc tức thời (chẳng hạn tiêu diệt Ô Mã Nhi khi `SignalDock (2, 8)` đang thuộc Đại Việt, hoặc để mất `SignalDock (2, 8)` vào tay giặc, hoặc Trần Quốc Tuấn tử trận), `BattleGameController` lập tức dừng vòng lặp và chuyển sang màn hình tổng kết mà không bắt người chơi chờ hết vòng.
> 2. **Giảm thời hạn Khống chế (CC) ở Pha 6 (`OnFactionTurnEnd`):** Hiệu ứng như `march_disabled_turns = 2` hoặc `chaos_turns = 1` gắn lên thuyền địch ở đầu Vòng 4 sẽ khóa trọn vẹn lượt đi của phe địch trong Vòng 4, rồi mới giảm `-1` khi phe địch kết thúc lượt ở Pha 6 (tránh lỗi giảm CC ở đầu vòng làm hiệu ứng 1 lượt bị mất trắng trước khi địch kịp bị khóa!).

---

## 4. Kiến trúc Mẫu Thiết kế Lệnh & Quy tắc Undo (Command Pattern)

Mọi thao tác chiến thuật được đóng gói thành lớp kế thừa `BattleCommand` phục vụ ghi nhật ký trận đánh (Replay tất định) và kiểm soát chặt quyền hoàn tác:
- **Tuyệt đối XÓA `AttackCommand.undo()`:** Các lệnh `AttackCommand`, `CastSkillCommand`, `ApplyTacticCommand`, `WaitCommand`, `EndTurnCommand` tiêu thụ số ngẫu nhiên chiến đấu hoặc chốt trạng thái lượt nên **không thể hoàn tác (`can_undo() == false`)**.
- **Chỉ duy nhất `MarchCommand` hỗ trợ `can_undo()` & `undo()`**, và bắt buộc lưu đủ các cờ trạng thái phát sinh trong bước đi để kiểm định **5 điều kiện cho phép Undo** (khớp GDD §11.4):
  1. Đơn vị chưa thực hiện hành động chính (`not unit.has_acted`).
  2. Chưa làm lộ thêm bất kỳ ô sương mù hay đơn vị địch ẩn nào (`revealed_fog_cells.is_empty()`).
  3. Chưa bước vào vùng kiểm soát ZOC của địch (`not entered_enemy_zoc`).
  4. Chưa kích hoạt bẫy hoặc sự kiện ô bản đồ (`not triggered_cell_event`).
  5. Đơn vị chưa dùng quyền Undo trong lượt hiện tại (`not unit.has_used_undo_this_turn`).

```mermaid
classDiagram
    class BattleCommand {
        <<abstract>>
        +int command_id
        +int faction_id
        +execute(ctx: BattleContext)* bool
        +can_undo(ctx: BattleContext) bool
        +undo(ctx: BattleContext) bool
        +to_dict()* Dictionary
    }
    class MarchCommand {
        +int unit_id
        +Vector2i from_hex
        +Vector2i to_hex
        +int mp_consumed
        +int prev_facing
        +Array~Vector2i~ revealed_fog_cells
        +bool entered_enemy_zoc
        +bool triggered_cell_event
        +execute(ctx) bool
        +can_undo(ctx) bool
        +undo(ctx) bool
    }
    class AttackCommand {
        +int attacker_id
        +int target_id
        +execute(ctx) bool
    }
    class CastSkillCommand {
        +int caster_id
        +int skill_id
        +Vector2i target_hex
        +execute(ctx) bool
    }
    class WaitCommand {
        +int unit_id
        +execute(ctx) bool
    }
    class EndTurnCommand {
        +execute(ctx) bool
    }

    BattleCommand <|-- MarchCommand
    BattleCommand <|-- AttackCommand
    BattleCommand <|-- CastSkillCommand
    BattleCommand <|-- WaitCommand
    BattleCommand <|-- EndTurnCommand
```

### Đoạn mã GDScript 2.0 cho `BattleCommand` & `MarchCommand`:
```gdscript
class_name BattleCommand
extends RefCounted

var command_id: int = 0
var faction_id: int = 0


func execute(_ctx: BattleContext) -> bool:
	return false


func can_undo(_ctx: BattleContext) -> bool:
	return false


func undo(_ctx: BattleContext) -> bool:
	return false


func to_dict() -> Dictionary:
	return {"command_id": command_id, "faction_id": faction_id}
```

```gdscript
class_name MarchCommand
extends BattleCommand

var unit_id: int
var from_hex: Vector2i
var to_hex: Vector2i
var mp_consumed: int = 0
var prev_facing: int = 0

# 4 nhóm dữ liệu kiểm tra điều kiện cấm Undo (kết hợp cờ trên UnitEntity)
var revealed_fog_cells: Array[Vector2i] = []
var entered_enemy_zoc: bool = false
var triggered_cell_event: bool = false


func _init(p_faction_id: int, p_unit_id: int, p_from: Vector2i, p_to: Vector2i) -> void:
	faction_id = p_faction_id
	unit_id = p_unit_id
	from_hex = p_from
	to_hex = p_to


func execute(ctx: BattleContext) -> bool:
	var unit: UnitEntity = ctx.get_unit(unit_id)
	if unit == null or unit.has_acted:
		return false

	prev_facing = unit.facing
	var move_report: Dictionary = ctx.move_unit_along_valid_path(unit, from_hex, to_hex)
	if not move_report.get("ok", false):
		return false

	mp_consumed = int(move_report.get("mp_cost", 0))
	revealed_fog_cells.assign(move_report.get("revealed_fog_cells", []))
	entered_enemy_zoc = bool(move_report.get("entered_enemy_zoc", false))
	triggered_cell_event = bool(move_report.get("triggered_cell_event", false))
	return true


func can_undo(ctx: BattleContext) -> bool:
	var unit: UnitEntity = ctx.get_unit(unit_id)
	if unit == null:
		return false
	if unit.has_acted:
		return false
	if unit.has_used_undo_this_turn:
		return false
	if not revealed_fog_cells.is_empty():
		return false
	if entered_enemy_zoc:
		return false
	if triggered_cell_event:
		return false
	return true


func undo(ctx: BattleContext) -> bool:
	if not can_undo(ctx):
		return false
	var unit: UnitEntity = ctx.get_unit(unit_id)
	ctx.teleport_unit_without_triggers(unit, from_hex)
	unit.current_mp += mp_consumed
	unit.facing = prev_facing
	unit.has_used_undo_this_turn = true
	return true
```

---

## 5. Hệ thống Lưu trữ 2 Tầng, Chống Desync & Tối ưu Web IndexedDB

### 5.1. Hồ sơ Tiến trình Người chơi (`user://saves/player_profile.json` & `.bak`)
* Lưu trữ danh sách màn chơi đã vượt qua, số sao kỷ lục mỗi màn, danh tướng, bảo vật và cài đặt trợ năng.
* **Cơ chế Sao lưu Kép (`Dual-Backup`):** Trước khi ghi đè `player_profile.json`, hệ thống sao chép bản hợp lệ hiện có sang `player_profile.bak`. Khi khởi động game, nếu file chính bị hỏng dữ liệu (mất nguồn đột ngột), hệ thống tự động khôi phục từ `.bak`.

### 5.2. Phiên Trận đánh Dở dang (`user://saves/battle_session.json`)
Để Resume trận đánh khớp tuyệt đối 100% mà không bị nổ lặp sự kiện hoặc lệch kết quả ngẫu nhiên, `BattleSessionState` bắt buộc tuần tự hóa đầy đủ:
* `version`: Số nguyên phiên bản schema (mặc định `1`) phục vụ nâng cấp tương thích ngược.
* `stage_id`, `current_round`, `current_faction_id`.
* **`rng_seed: int` và `rng_state: int`:** Khôi phục chính xác trạng thái tức thời của `RandomNumberGenerator` đang dùng cho Combat & AI.
* **`triggered_event_ids: Array[String]`:** Danh sách ID các sự kiện kịch bản `once: true` đã kích hoạt (ví dụ `["evt_10101_battle_start", "evt_10101_tide_fall"]`) — nạp lại cho `ScenarioEventManager` khi Resume để sự kiện một lần không bao giờ bị chạy lặp lại!
* `hex_cell_states`: Địa hình hiện tại của từng ô (bảo toàn các ô đã chuyển sang `StakedWater`), phe kiểm soát cứ điểm (`SignalDock`), trạng thái Fog of War đã mở của từng phe.
* `unit_states`: Tọa độ `(q, r)`, `current_hp`, `morale`, `current_mp`, `has_acted`, `has_used_undo_this_turn`, cùng các bộ đếm CC (`chaos_turns`, `march_disabled_turns`, `attack_disabled_turns`).

> [!IMPORTANT] **Quy tắc Nhịp Lưu Tự Động trên Web (IndexedDB) & Android:**  
> Trên bản xuất HTML5/Web của Godot 4.7, mỗi thao tác đóng tệp `user://` kích hoạt đồng bộ hóa hệ thống tệp ảo lên **IndexedDB** của trình duyệt. Nếu ghi file sau từng bước đi lẻ của từng lính sẽ gây khựng khung hình (frame hitch).  
> Vì vậy, `BattleSaveManager.save_battle_session()` **chỉ được gọi tại ranh giới đầu/cuối lượt phe (`FactionPhaseStart` / `OnFactionTurnEnd`) hoặc khi người chơi bấm nút `Pause / Thoát ra Menu`**.

---

## 6. Mã Nguồn Triển khai Mẫu — `BattleSaveManager` (Typed GDScript 2.0)

```gdscript
class_name BattleSaveManager
extends Node

const SAVE_SCHEMA_VERSION: int = 1
const SAVE_DIR: String = "user://saves"
const SESSION_SAVE_PATH: String = "user://saves/battle_session.json"
const PROFILE_SAVE_PATH: String = "user://saves/player_profile.json"
const PROFILE_BACKUP_PATH: String = "user://saves/player_profile.bak"


static func _ensure_save_dir() -> Error:
	# Bắt buộc tạo thư mục trước khi mở FileAccess.WRITE để tránh crash trên máy cài mới
	var abs_dir: String = ProjectSettings.globalize_path(SAVE_DIR)
	var err: Error = DirAccess.make_dir_recursive_absolute(abs_dir)
	if err != OK:
		push_error("BattleSaveManager: Không thể tạo thư mục lưu '%s' (err=%d)" % [abs_dir, err])
	return err


## Lưu phiên trận đánh tại đầu/cuối lượt phe hoặc khi Pause/Thoát (không gọi sau từng bước lẻ).
static func save_battle_session(
	state_dict: Dictionary,
	rng: RandomNumberGenerator,
	triggered_event_ids: Array[String]
) -> bool:
	if _ensure_save_dir() != OK:
		return false

	var payload: Dictionary = state_dict.duplicate(true)
	payload["version"] = SAVE_SCHEMA_VERSION
	payload["rng_seed"] = str(rng.seed)     # Lưu chuỗi để không mất độ chính xác uint64 trong JSON
	payload["rng_state"] = str(rng.state)
	payload["triggered_event_ids"] = triggered_event_ids.duplicate()

	var json_text: String = JSON.stringify(payload, "\t")
	var file := FileAccess.open(SESSION_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("BattleSaveManager: Mở file '%s' thất bại (err=%d)" % [
			SESSION_SAVE_PATH, FileAccess.get_open_error()
		])
		return false

	file.store_string(json_text)
	file.close()
	return true


## Khôi phục phiên trận đánh kèm đúng trạng thái RNG tất định và danh sách sự kiện đã chạy.
static func load_battle_session(
	out_rng: RandomNumberGenerator,
	out_triggered_event_ids: Array[String]
) -> Dictionary:
	if not FileAccess.file_exists(SESSION_SAVE_PATH):
		return {}

	var file := FileAccess.open(SESSION_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("BattleSaveManager: Không thể đọc '%s'" % SESSION_SAVE_PATH)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_error("BattleSaveManager: Dữ liệu JSON phiên trận đánh không hợp lệ.")
		return {}

	var data: Dictionary = parsed as Dictionary
	out_rng.seed = int(String(data.get("rng_seed", "1")))
	out_rng.state = int(String(data.get("rng_state", "1")))

	out_triggered_event_ids.clear()
	var raw_events: Array = data.get("triggered_event_ids", [])
	for evt_id: Variant in raw_events:
		out_triggered_event_ids.append(String(evt_id))

	return data


## Lưu hồ sơ người chơi với cơ chế Dual-Backup an toàn.
static func save_player_profile(profile_data: Dictionary) -> bool:
	if _ensure_save_dir() != OK:
		return false

	var payload: Dictionary = profile_data.duplicate(true)
	payload["version"] = SAVE_SCHEMA_VERSION
	var json_text: String = JSON.stringify(payload, "\t")

	if FileAccess.file_exists(PROFILE_SAVE_PATH):
		var src_abs: String = ProjectSettings.globalize_path(PROFILE_SAVE_PATH)
		var bak_abs: String = ProjectSettings.globalize_path(PROFILE_BACKUP_PATH)
		DirAccess.copy_absolute(src_abs, bak_abs)

	var file := FileAccess.open(PROFILE_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("BattleSaveManager: Ghi hồ sơ thất bại (err=%d)" % FileAccess.get_open_error())
		return false

	file.store_string(json_text)
	file.close()
	return true


## Đọc hồ sơ người chơi, tự động chuyển sang bản sao lưu .bak nếu bản chính lỗi.
static func load_player_profile() -> Dictionary:
	for path: String in [PROFILE_SAVE_PATH, PROFILE_BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			return parsed as Dictionary
		push_warning("BattleSaveManager: File '%s' bị lỗi cú pháp JSON, thử bản dự phòng..." % path)
	return {}
```
