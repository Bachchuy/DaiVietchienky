import os
import re
import unicodedata

DOCS_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(DOCS_DIR, "TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md")


def gfm_slug(heading_text: str, seen_counts: dict) -> str:
    """Generate exact GitHub Flavored Markdown anchor slug for a heading."""
    # Strip markdown formatting like `code`, **bold**, *italic*, [text](url)
    text = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", heading_text)
    text = text.replace("`", "").replace("*", "")
    text = text.strip().lower()
    # Keep unicode word chars (letters, digits, underscores), spaces, and hyphens
    cleaned = []
    for ch in text:
        cat = unicodedata.category(ch)
        if ch == " " or ch == "-":
            cleaned.append("-")
        elif cat.startswith("L") or cat.startswith("N") or cat.startswith("M") or ch == "_":
            cleaned.append(ch)
        # Other punctuation/emojis/symbols are dropped in GFM
    slug = "".join(cleaned)
    slug = seen_slug = slug
    if slug in seen_counts:
        seen_counts[slug] += 1
        seen_slug = f"{slug}-{seen_counts[slug]}"
    else:
        seen_counts[slug] = 0
    return seen_slug


def rewrite_relative_links(content: str, src_full_path: str) -> str:
    """Rewrite relative markdown links so they remain valid from docs/ root."""
    src_dir = os.path.dirname(src_full_path)

    def _replace(match: re.Match) -> str:
        label = match.group(1)
        target = match.group(2).strip()
        if (
            not target
            or target.startswith("#")
            or target.startswith("http://")
            or target.startswith("https://")
            or target.startswith("mailto:")
            or target.startswith("file://")
            or target.startswith("res://")
            or target.startswith("user://")
        ):
            return match.group(0)

        anchor = ""
        path_part = target
        if "#" in target:
            path_part, anchor_part = target.split("#", 1)
            anchor = "#" + anchor_part

        abs_target = os.path.normpath(os.path.join(src_dir, path_part))
        rel_from_docs = os.path.relpath(abs_target, DOCS_DIR).replace("\\", "/")
        return f"[{label}]({rel_from_docs}{anchor})"

    return re.sub(r"\[([^\]]+)\]\(([^\)]+)\)", _replace, content)


def read_doc(rel_path: str) -> str:
    full_path = os.path.join(DOCS_DIR, rel_path)
    if not os.path.exists(full_path):
        print(f"Warning: File not found: {full_path}")
        return ""
    with open(full_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove back-to-index navigation lines cleanly without eating unrelated lines
    content = re.sub(
        r"^(?:\*\*Liên kết GDD:\*\*\s*)?\[←\s*Quay lại[^\]]*\]\([^\)]+\)\s*$",
        "",
        content,
        flags=re.MULTILINE,
    )
    # Rewrite remaining relative links to be valid from docs/ directory
    content = rewrite_relative_links(content, full_path)

    # Strip ONLY a leading divider right after the title block, preserving body dividers
    lines = content.strip().splitlines()
    cleaned_lines = []
    in_code_block = False
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code_block = not in_code_block
            cleaned_lines.append(line)
            continue
        if not in_code_block:
            # Drop redundant boilerplate project subtitle inside deep-dive modules
            if idx <= 4 and re.match(r"^#{2,3}\s+(DỰ ÁN:|MODULE:)\s+", stripped, re.IGNORECASE):
                continue
        cleaned_lines.append(line)

    result = "\n".join(cleaned_lines).strip()
    # Collapse 3+ consecutive blank lines and remove leading horizontal rule right after H1
    result = re.sub(r"\n{3,}", "\n\n", result)
    result = re.sub(r"^(#[^\n]+\n+)\s*---\s*\n+", r"\1\n", result)
    return result.strip()


def clean_section(prefix: str, default_title: str, content: str) -> str:
    """Normalize top heading to `## <prefix> <Clean Title>` and demote inner H2+ by 1 level."""
    lines = content.splitlines()
    if not lines:
        return f"## {prefix} {default_title}\n"

    out = []
    title_handled = False
    in_code_block = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code_block = not in_code_block
            out.append(line)
            continue

        if not title_handled and not in_code_block and stripped:
            m = re.match(r"^#{1,3}\s+(.*)$", stripped)
            if m:
                raw_title = m.group(1).strip()
                # Strip legacy leading numbers like "00. ", "14. ", "Phụ lục A: " if duplicated
                raw_title = re.sub(r"^\d{1,2}\.\s+", "", raw_title)
                out.append(f"## {prefix} {raw_title}")
                title_handled = True
                continue
            else:
                out.append(f"## {prefix} {default_title}")
                out.append(line)
                title_handled = True
                continue

        if not in_code_block and stripped.startswith("#"):
            m_sub = re.match(r"^(#{1,5})\s+(.*)$", stripped)
            if m_sub:
                hashes, sub_title = m_sub.group(1), m_sub.group(2)
                # Ensure inner headings sit cleanly beneath `## <prefix>` (at least `###`)
                new_level = min(6, max(3, len(hashes) + 1 if len(hashes) <= 2 else len(hashes)))
                out.append(f"{'#' * new_level} {sub_title}")
                continue

        out.append(line)

    return "\n".join(out).strip()


def build_auto_toc(body_markdown: str) -> str:
    """Generate a 100% verified Table of Contents directly from actual headings."""
    seen_counts = {}
    # Pre-seed slugs for headings that appear before TOC in consultation_guide
    toc_lines = ["## MỤC LỤC TỔNG THỂ (TABLE OF CONTENTS)\n"]

    in_code_block = False
    for line in body_markdown.splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code_block = not in_code_block
            continue
        if in_code_block or not stripped.startswith("#"):
            continue

        m = re.match(r"^(#{1,3})\s+(.*)$", stripped)
        if not m:
            continue
        level = len(m.group(1))
        title = m.group(2).strip()
        slug = gfm_slug(title, seen_counts)

        # Skip the top document H1/H2/H3 banner titles and the TOC heading itself
        if title in (
            "ĐẠI VIỆT CHIẾN KỲ (DAI VIET CHRONICLES)",
            "TÀI LIỆU THIẾT KẾ TOÀN DIỆN & KẾ HOẠCH TRIỂN KHAI SẢN XUẤT",
            "MASTER GAME DESIGN DOCUMENT (GDD) & PRODUCTION BLUEPRINT — PHIÊN BẢN 3.4 (BẢN ĐỒNG BỘ HÓA)",
            "MỤC LỤC TỔNG THỂ (TABLE OF CONTENTS)",
        ):
            continue

        if level == 1:
            toc_lines.append(f"- **[{title}](#{slug})**")
        elif level == 2:
            toc_lines.append(f"  - [{title}](#{slug})")
        elif level == 3 and title.startswith(("1.", "2.", "3.")) and "SỔ TAY THAM VẤN" not in title:
            # Keep TOC concise: include H3 subsections of the Executive Guide
            pass

    return "\n".join(toc_lines) + "\n\n---\n\n"


def main() -> None:
    print("Loading all 33 source documents...")

    # 1. Overview
    doc_control = read_doc(r"gdd\00_overview\document_control.md")
    conventions = read_doc(r"gdd\00_overview\conventions_glossary.md")
    prod_summary = read_doc(r"gdd\00_overview\product_summary.md")
    changelog = read_doc(r"gdd\00_overview\CHANGELOG_3.3_to_3.4.md")

    # 2. Vision & Player
    vision_pillars = read_doc(r"gdd\01_vision_player\vision_pillars.md")
    player_exp = read_doc(r"gdd\01_vision_player\player_experience.md")

    # 3. Gameplay Systems
    core_loop = read_doc(r"gdd\02_gameplay_systems\core_loop.md")
    game_modes = read_doc(r"gdd\02_gameplay_systems\game_modes.md")
    battlefield_rules = read_doc(r"gdd\02_gameplay_systems\battlefield_rules.md")
    units_commanders = read_doc(r"gdd\02_gameplay_systems\units_commanders.md")
    factions_economy = read_doc(r"gdd\02_gameplay_systems\factions_economy.md")
    meta_progression = read_doc(r"gdd\02_gameplay_systems\meta_progression.md")

    # 4. Mechanics Deep Dive
    combat_formulas = read_doc(r"gdd\mechanics\combat_formulas.md")
    morale_status = read_doc(r"gdd\mechanics\morale_and_status.md")
    hex_grid_path = read_doc(r"gdd\mechanics\hex_grid_pathfinding.md")
    battle_economy = read_doc(r"gdd\mechanics\battlefield_economy.md")

    # 5. Progression & Meta Deep Dive
    generals_meta = read_doc(r"gdd\progression\generals_and_meta_economy.md")

    # 6. Level Design & Scripting
    scenario_scripting = read_doc(r"gdd\level_design\scenario_scripting_and_events.md")

    # 7. AI System
    ai_difficulty = read_doc(r"gdd\03_content_presentation\ai_difficulty.md")
    ai_decision_matrix = read_doc(r"gdd\ai\ai_decision_matrix.md")

    # 8. Technical Architecture & Save
    data_save_system = read_doc(r"gdd\architecture\data_and_save_system.md")

    # 9. UI/UX, Rendering & VFX/SFX
    ui_ux_summary = read_doc(r"gdd\03_content_presentation\ui_ux.md")
    battle_ui_rendering = read_doc(r"gdd\ui_ux\battle_ui_and_rendering.md")
    audio_visual_summary = read_doc(r"gdd\03_content_presentation\audio_visual_narrative.md")
    vfx_sfx_polish = read_doc(r"gdd\vfx_sfx\vfx_sfx_and_polish.md")

    # 10. Historical Framework
    historical_framework = read_doc(r"gdd\03_content_presentation\historical_framework.md")

    # 11. Production Scope, Roadmap & Decisions
    prod_scope_mvp = read_doc(r"gdd\04_production_roadmap\production_scope_mvp.md")
    risks_decisions = read_doc(r"gdd\04_production_roadmap\risks_open_decisions.md")
    implementation_plan = read_doc(r"gdd\04_production_roadmap\implementation_plan.md")

    # 12. Appendices & Assets
    appendix_a = read_doc(r"gdd\appendices\appendix_a_benchmark_matrix.md")
    appendix_b = read_doc(r"gdd\appendices\appendix_b_sources.md")
    appendix_c = read_doc(r"gdd\appendices\appendix_c_extended_glossary.md")
    asset_catalog = read_doc(r"assets\ASSET_CATALOG.md")

    consultation_guide = r"""# ĐẠI VIỆT CHIẾN KỲ (DAI VIET CHRONICLES)
## TÀI LIỆU THIẾT KẾ TOÀN DIỆN & KẾ HOẠCH TRIỂN KHAI SẢN XUẤT
### MASTER GAME DESIGN DOCUMENT (GDD) & PRODUCTION BLUEPRINT — PHIÊN BẢN 3.4 (BẢN ĐỒNG BỘ HÓA)
**Trạng thái tài liệu:** Bản Hợp Nhất Hoàn Chỉnh (Consolidated Master v3.4.1) — Đồng bộ Thiết kế, Công thức Toán học & Kiến trúc Kỹ thuật  
**Ngày cập nhật:** 18/11/2026 | **Động cơ:** Godot 4.7 (Thuần GDScript 2.0 — Static Typing) | **Renderer:** `gl_compatibility` | **Mục tiêu:** Web (HTML5/Wasm) + Android (60 FPS)

---

## PHẦN MỞ ĐẦU: SỔ TAY TỔNG QUAN & CÁC QUYẾT ĐỊNH TRỌNG YẾU (EXECUTIVE GUIDE)

### 1. Tóm Tắt Dự Án Trong 60 Giây (Elevator Pitch)
- **Tên dự án:** Đại Việt Chiến Kỳ (*Dai Viet Chronicles*).
- **Thể loại:** Chiến thuật theo lượt quân sự lịch sử (Turn-Based Hex Wargame).
- **Phạm vi lịch sử:** Từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (Triều Tây Sơn), phát triển cuốn chiếu theo từng *Gói Thời Kỳ (Era Pack)*, mở màn bằng **Slice-01: Đại Chiến Bạch Đằng 1288 (Gói Thời Trần)**.
- **Logline:** Chỉ huy các đạo quân Đại Việt qua những chiến dịch lịch sử hào hùng, làm chủ địa hình sông ngòi rừng núi, vận dụng thời cơ thủy triều, bẫy cọc ngầm, bọc sườn và sĩ khí để biến quyết định chiến thuật thành chiến thắng có thể giải thích.
- **Điểm nhấn tạo khác biệt (Unique Selling Points):**
  1. *Bản sắc quân sự Việt Nam:* Tái hiện cơ chế thủy chiến Bạch Đằng (thủy triều rút ở Vòng 4 làm lộ bãi cọc nhọn đâm thủng chiến thuyền quân Nguyên), thế trận cướp lương "Vườn không nhà trống", tượng binh xung kích và phục kích rừng rậm.
  2. *Controlled RNG Tất Định & Minh Bạch:* Dao động sát thương có kiểm soát (`80%–100%`) kết hợp Bạo kích trên nền `Seeded RandomNumberGenerator` độc lập, đường cong Giáp `100 / (100 + EffectiveDef)`, gộp cờ `TroopStack` (1x–3x) mượt không đứt gãy và `Combat Preview` 2 bước minh bạch.
  3. *Tiến trình Meta & Duyên phận F2P thân thiện:* Hệ thống Duyên phận lịch sử (*Trần Triều Tam Kiệt*, *Hào Khí Mê Linh*, *Hội Thề Lũng Nhai*) cho phép tích lũy Ngọc Bích từ thành tựu/sự kiện để chiêu mộ mọi bậc danh tướng; khóa hồ sơ tướng (`Preset Loadout`) trong *Historical Scenario*.
  4. *Kiến trúc Thuần GDScript 2.0 tối ưu 60 FPS:* Vận hành trên Godot 4.7 (`gl_compatibility`), xuất bản liền mạch lên trình duyệt Web (Wasm) và thiết bị di động Android với *Strategic Zoom* và Object Pooling.

---

### 2. Bảng Tổng Hợp Trạng Thái Quyết Định Thiết Kế & Kỹ Thuật (`D-01` đến `D-17`)

| Mã ID | Nội Dung Quyết Định | Trạng Thái | Phương Án Đã Chốt / Định Hướng Thực Thi |
| :---: | :--- | :---: | :--- |
| **D-01** | Thể loại cốt lõi (Turn-based Hex Wargame vs RTS) | **LOCKED** | Chốt Turn-based Hex Wargame trên lưới Pointy-topped Axial `(q, r)`. |
| **D-02** | Tách bạch cân bằng Lịch sử vs Tiến trình Meta | **LOCKED** | *Historical Scenario* khóa `Preset Loadout`; tiến trình Meta áp dụng cho *Conquest/Legion/Domination*. |
| **D-03** | Chiến lược sản xuất cuốn chiếu theo Vertical Slice | **LOCKED** | Hoàn thiện & kiểm chứng **Slice-01 (Bạch Đằng 1288)** trước khi mở rộng các *Era Pack*. |
| **D-06** | Nền tảng mục tiêu phát hành | **LOCKED** | **Web (HTML5/Wasm) + Android** (phát triển & kiểm thử trên Windows Desktop), mục tiêu 60 FPS. |
| **D-07** | Định hướng Thương mại hóa & Chính sách Gacha | **LOCKED** | Không Gacha ở MVP/Slice-01; giai đoạn mở rộng áp dụng **F2P thân thiện** (tích Ngọc Bích từ thành tựu/sự kiện để mở mọi phẩm tướng, không khóa paywall tướng lịch sử). |
| **D-09** | Ngôn ngữ lập trình & Kiến trúc Engine | **LOCKED** | **Godot 4.7 + Thuần GDScript 2.0 (Static Typing)** thay cho C# .NET để đảm bảo tương thích 100% WebAssembly & Android. |
| **D-10** | Trình kết xuất đồ họa (Renderer) | **LOCKED** | `gl_compatibility` kết hợp `CPUParticles2D` pooling, Local Hit-Stop và Strategic Zoom (`< 0.65x`). |
| **D-11** | Thứ tự Công – Phản kích & Giới hạn phản kích | **LOCKED** | Công đánh trước – Thủ còn sống phản kích sau (`75%` sát thương), tối đa **1 lần phản kích/vòng**, bắt buộc thỏa tầm & LOS. |
| **D-12** | Quy tắc dừng ZoC, CoC & Hình học Flank | **LOCKED** | Bước vào ZoC tiêu hết `remaining_mp`; CoC Thành trì nhân `2x` chi phí địa hình; Flank kích hoạt ở góc $120^\circ$ hoặc $180^\circ$. |
| **D-13** | Mô hình Sĩ khí & Trạng thái chạm đáy (`CHAOS`) | **LOCKED** | **4 bậc Enum rời rạc** (`HIGH`, `NORMAL`, `LOW`, `CHAOS`); `CHAOS` khóa hành động theo số lượt rồi tự hồi về `LOW`. |
| **D-14** | Cơ chế Thủy triều rút & Bãi cọc Bạch Đằng (`StakedWater`) | **LOCKED** | Triều rút đầu **Vòng 4**: lộ bãi cọc, thuyền địch trên bãi cọc mất `35% MaxHP`, dính `MarchDisabled` (2 lượt) & `CHAOS` (1 lượt). |
| **D-15** | Hệ quả khi Tướng chỉ huy bị loại khỏi vòng chiến | **LOCKED** | Mất `UniqueSkill` gắn với đạo quân đó và gây chấn động `-1 bậc` Sĩ khí đồng minh trong bán kính 2 hex (riêng Chủ soái tử trận sẽ xử thua nếu kịch bản quy định). |
| **D-16** | Cơ chế kiểm soát `SignalDock` & Chống Turtling ở Slice-01 | **LOCKED** | Thắng ngay khi hạ Ô Mã Nhi và giữ vững `SignalDock` (cho phép đạt 2 Sao `<= 8 lượt`), hoặc giữ `SignalDock` hết Vòng 10 kèm diệt `>= 75%` quân địch; ẩn Kinh tế sang P3. |
| **D-04** | Kiến trúc Bản đồ chế độ Chinh Phục (Conquest Map) | **OPEN (Trước P3)** | Đang cân nhắc giữa bản đồ Lưới Hex dọc Bắc–Nam (`120 × 240 hex`) và bản đồ Node/Tỉnh thành liên kết sa bàn trận đánh. |
| **D-05** | Độ sâu Kinh tế & Ngoại giao trong Conquest | **OPEN (Trước P3)** | Mặc định ưu tiên mô phỏng gọn (4 tài nguyên `Coin, Food, Tech, Mana` + giao thương/tuyển quân cốt lõi). |
| **D-08** | Quy trình Thẩm định Sử liệu cho từng Era Pack | **OPEN (Trước P2)** | Áp dụng Evidence Grade A–D & gắn nhãn `abstraction/fixture`; rà soát hồ sơ Bạch Đằng 1288 với nguồn chính sử `[S12]–[S16]`. |
| **D-17** | Ngưỡng nghiệm thu Playtest thực tế cho Slice-01 | **OPEN (Trước P2)** | Tối thiểu 5 người chơi ngoài dev; `>= 4/5` nắm rõ điều kiện thắng/thua và giải thích được bước ngoặt chiến thuật. |

---
"""

    body_parts = [
        "# CHƯƠNG I: QUẢN LÝ DỰ ÁN, QUY ƯỚC & TỔNG QUAN SẢN PHẨM\n\n",
        clean_section("1.1.", "Quản lý tài liệu (Document Control)", doc_control),
        "\n\n---\n\n",
        clean_section("1.2.", "Quy ước đọc tài liệu và thuật ngữ", conventions),
        "\n\n---\n\n",
        clean_section("1.3.", "Tóm tắt sản phẩm", prod_summary),
        "\n\n---\n\n",
        clean_section("1.4.", "Lịch sử phiên bản & Nhật ký đồng bộ (Changelog)", changelog),
        "\n\n---\n\n",
        "# CHƯƠNG II: TẦM NHÌN, ĐỊNH VỊ & TRẢI NGHIỆM NGƯỜI CHƠI\n\n",
        clean_section("2.1.", "Tầm nhìn, định vị và trụ cột thiết kế", vision_pillars),
        "\n\n---\n\n",
        clean_section("2.2.", "Người chơi và trải nghiệm mục tiêu", player_exp),
        "\n\n---\n\n",
        "# CHƯƠNG III: HỆ THỐNG GAMEPLAY & VÒNG LẶP TRẬN ĐÁNH\n\n",
        clean_section("3.1.", "Core Loop và cấu trúc lượt", core_loop),
        "\n\n---\n\n",
        clean_section("3.2.", "Các chế độ chơi (Game Modes)", game_modes),
        "\n\n---\n\n",
        clean_section("3.3.", "Hệ thống quy tắc chiến trường", battlefield_rules),
        "\n\n---\n\n",
        clean_section("3.4.", "Tướng lĩnh, binh chủng và quân đội", units_commanders),
        "\n\n---\n\n",
        clean_section("3.5.", "Thế lực và kinh tế chiến lược", factions_economy),
        "\n\n---\n\n",
        clean_section("3.6.", "Tiến trình Meta và nguyên tắc cân bằng", meta_progression),
        "\n\n---\n\n",
        "# CHƯƠNG IV: ĐẶC TẢ CHI TIẾT CƠ CHẾ CHIẾN THUẬT (TACTICAL MECHANICS DEEP-DIVE)\n\n",
        clean_section("4.1.", "Đặc tả công thức chiến đấu & Tính toán sát thương", combat_formulas),
        "\n\n---\n\n",
        clean_section("4.2.", "Đặc tả hệ thống Sĩ khí & Hiệu ứng trạng thái", morale_status),
        "\n\n---\n\n",
        clean_section("4.3.", "Đặc tả hệ thống Lưới Hex, Địa hình, LOS & Vùng khống chế", hex_grid_path),
        "\n\n---\n\n",
        clean_section("4.4.", "Kinh tế chiến trường & Hậu cần trong trận (P3 Scope)", battle_economy),
        "\n\n---\n\n",
        "# CHƯƠNG V: TIẾN TRÌNH META, DANH TƯỚNG & KINH TẾ NGOẠI TRẬN\n\n",
        clean_section("5.1.", "Hệ thống Tướng, Duyên phận, Bảo vật & Kinh tế Meta", generals_meta),
        "\n\n---\n\n",
        "# CHƯƠNG VI: THIẾT KẾ MÀN CHƠI & DỰNG KỊCH BẢN (LEVEL DESIGN & SCRIPTING)\n\n",
        clean_section("6.1.", "Đặc tả thiết kế màn chơi, Hệ thống sự kiện & Kịch bản Slice-01", scenario_scripting),
        "\n\n---\n\n",
        "# CHƯƠNG VII: HỆ THỐNG TRÍ TUỆ NHÂN TẠO (AI SYSTEM & DECISION MATRIX)\n\n",
        clean_section("7.1.", "Triết lý AI và 4 cấp độ khó", ai_difficulty),
        "\n\n---\n\n",
        clean_section("7.2.", "Đặc tả kiến trúc ra quyết định của AI máy (Utility AI)", ai_decision_matrix),
        "\n\n---\n\n",
        "# CHƯƠNG VIII: KIẾN TRÚC KỸ THUẬT, DỮ LIỆU & SAVE/LOAD\n\n",
        clean_section("8.1.", "Đặc tả kiến trúc dữ liệu, Vòng lặp trận đánh & Hệ thống Save/Load", data_save_system),
        "\n\n---\n\n",
        "# CHƯƠNG IX: GIAO DIỆN, KẾT XUẤT ĐỒ HỌA & PHẢN HỒI VA CHẠM (UI/UX, RENDERING & JUICE)\n\n",
        clean_section("9.1.", "Nguyên tắc UI/UX và khả năng tiếp cận", ui_ux_summary),
        "\n\n---\n\n",
        clean_section("9.2.", "Đặc tả giao diện chiến trường, Render Layers & Input FSM", battle_ui_rendering),
        "\n\n---\n\n",
        clean_section("9.3.", "Định hướng mỹ thuật, âm thanh và tường thuật", audio_visual_summary),
        "\n\n---\n\n",
        clean_section("9.4.", "Hệ thống VFX, SFX & Đánh bóng phản hồi (Game Feel)", vfx_sfx_polish),
        "\n\n---\n\n",
        "# CHƯƠNG X: KHUNG NGHIÊN CỨU & THẨM ĐỊNH LỊCH SỬ\n\n",
        clean_section("10.1.", "Nội dung lịch sử, quy trình thẩm định & Hồ sơ Bạch Đằng", historical_framework),
        "\n\n---\n\n",
        "# CHƯƠNG XI: KẾ HOẠCH SẢN XUẤT, ROADMAP & QUẢN TRỊ RỦI RO\n\n",
        clean_section("11.1.", "Phạm vi sản xuất Slice-01, Release MVP và tiêu chí nghiệm thu", prod_scope_mvp),
        "\n\n---\n\n",
        clean_section("11.2.", "Quản trị rủi ro, giả định và danh mục quyết định", risks_decisions),
        "\n\n---\n\n",
        clean_section("11.3.", "Kế hoạch triển khai, Checkpoints CP1–CP5 & Design Gates", implementation_plan),
        "\n\n---\n\n",
        "# CHƯƠNG XII: PHỤ LỤC & SỔ TAY QUẢN LÝ TÀI NGUYÊN\n\n",
        clean_section("12.1.", "Phụ lục A. Feature Reference Matrix", appendix_a),
        "\n\n---\n\n",
        clean_section("12.2.", "Phụ lục B. Nguồn tư liệu lịch sử và game tham khảo", appendix_b),
        "\n\n---\n\n",
        clean_section("12.3.", "Phụ lục C. Bảng thuật ngữ mở rộng (Extended Glossary)", appendix_c),
        "\n\n---\n\n",
        clean_section("12.4.", "Phụ lục D. Sổ tay quản lý tài nguyên (Asset Catalog)", asset_catalog),
        "\n",
    ]

    full_body = "".join(body_parts)
    toc = build_auto_toc(consultation_guide + "\n" + full_body)
    full_text = consultation_guide + "\n" + toc + full_body

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(full_text)

    size_kb = os.path.getsize(OUTPUT_FILE) / 1024
    line_count = len(full_text.splitlines())
    print(f"Master GDD compiled successfully to: {OUTPUT_FILE}")
    print(f"Total size: {size_kb:.2f} KB | Total lines: {line_count}")


if __name__ == "__main__":
    main()
