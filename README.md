# Đại Việt Chiến Kỳ (Dai Viet Chronicles)

Dự án game chiến thuật theo lượt quân sự lịch sử Việt Nam (**Turn-Based Hex Wargame**), tái hiện các chiến dịch tiêu biểu từ thời dựng nước & Bắc thuộc đến thế kỷ XVIII (khởi đầu với Vertical Slice **Slice-01: Đại Chiến Bạch Đằng 1288**).

---

## Công Nghệ & Nền Tảng Mục Tiêu

- **Engine:** Godot 4.7
- **Ngôn ngữ:** Thuần GDScript 2.0 (Static Typing)
- **Renderer:** `gl_compatibility` (GL Compatibility)
- **Nền tảng phát hành mục tiêu:** Web (HTML5 / WebAssembly) & Android (phát triển và kiểm thử trên Windows Desktop)
- **Hiệu năng mục tiêu:** 60 FPS ổn định

---

## Cấu Trúc Thư Mục Dự Án

```text
VietNamHistoryStrategy/
├── project.godot                              # Cấu hình dự án Godot 4.7 (GL Compatibility)
├── AGENTS.md                                  # Quy chuẩn kỹ thuật & quy trình kiểm chứng cho AI/Developer
├── README.md                                  # Tổng quan dự án & hướng dẫn sử dụng kho tài liệu
├── .agents/                                   # Cấu hình MCP và bộ Skills hỗ trợ phát triển Godot
├── Assets/                                    # Kho tài nguyên tham chiếu/placeholder cục bộ (Audio, UI, Shaders, Effects)
└── docs/                                      # Hệ thống tài liệu thiết kế (GDD v3.4+)
    ├── gdd/README.md                          # Bản đồ chỉ mục điều hướng 32+ module GDD chuyên biệt
    ├── assets/ASSET_CATALOG.md                # Sổ tay kiểm kê tài nguyên & lộ trình thay thế bản quyền 100%
    ├── build_master_gdd.py                    # Script Python tổng hợp toàn bộ module GDD thành 1 tệp duy nhất
    └── TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md  # Bản Master GDD hợp nhất (dùng cho phản biện & tra cứu tổng thể)
```

---

## Hệ Thống Tài Liệu Thiết Kế (GDD)

1. **Tra cứu theo Module (Khuyên dùng khi lập trình & làm việc với AI Agent):**
   - Xem mục lục phân cây tại [docs/gdd/README.md](docs/gdd/README.md).
2. **Bản Hợp Nhất Toàn Diện (Master GDD):**
   - Xem tại [docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md](docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md).
3. **Đồng bộ lại bản Master GDD sau khi chỉnh sửa các module con:**
   ```powershell
   python docs/build_master_gdd.py
   ```

> **Lưu ý Bản quyền Tài nguyên:** Các tệp trong thư mục `Assets/` hiện chỉ phục vụ mục đích tham chiếu kỹ thuật và thử nghiệm cơ chế gameplay nội bộ ở giai đoạn prototype. Không phân phối thương mại hoặc công khai các tệp placeholder bên thứ ba; toàn bộ mỹ thuật, âm thanh và shader sẽ được thay thế 100% bằng tài sản độc quyền/hợp pháp theo lộ trình tại [docs/assets/ASSET_CATALOG.md](docs/assets/ASSET_CATALOG.md).
