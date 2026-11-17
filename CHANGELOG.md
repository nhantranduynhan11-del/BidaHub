# CHANGELOG - BIDAHUB (HOÀNG PHẠM TIẾN THÀNH)

Lưu trữ tiến độ, ngữ cảnh công việc và các quyết định kỹ thuật của Thành qua từng phiên làm việc.

---

## [2026-11-07] Khởi tạo Task 1 - Thiết kế 6 bảng của Thành (`01_bang/thanh.sql`)

### 1. Nhiệm vụ thực hiện
- Khảo sát tài liệu `BaoCao_BTL1_BidaHub (1).pdf` và [README.md](file:///d:/HK261/BidaHub/README.md).
- Xác định 6 bảng thuộc trách nhiệm của Thành:
  1. `KHU_VUC`
  2. `LOAI_BAN`
  3. `KHUNG_GIA` (thực thể yếu của `LOAI_BAN`)
  4. `BAN` (tham chiếu `KHU_VUC`, `LOAI_BAN`)
  5. `PHIEU_DAT_BAN` (tham chiếu `KHACH_HANG` của Phong, `NHAN_VIEN` của Nhân)
  6. `GIU_BAN` (bảng liên kết M:N giữa `PHIEU_DAT_BAN` và `BAN`)

### 2. Ràng buộc nghiệp vụ tích hợp trong CREATE TABLE
- `KHUNG_GIA`: `GioKetThuc > GioBatDau` (RB4), `DonGiaMoiGio > 0`, `LoaiNgayApDung` hợp lệ.
- `BAN`: `TrangThai` chuẩn hóa 5 trạng thái theo BTL1 (`Trống`, `Đang chơi`, `Đã đặt`, `Đang bảo trì`, `Ngưng sử dụng`).
- `PHIEU_DAT_BAN`: `GioKetThucDuKien > GioBatDauDuKien` (RB5), `SoNguoi > 0`, `KenhTiepNhan`, `TrangThai`.

### 3. File đã tạo
- [sql/01_bang/thanh.sql](file:///d:/HK261/BidaHub/sql/01_bang/thanh.sql): File kịch bản DDL hoàn chỉnh cho 6 bảng.

---

## [2026-11-10] Hoàn thành Task 2 - Dữ liệu mẫu 6 bảng (`02_du_lieu/thanh.sql`) & Đồng bộ kiểu `MaKH`

### 1. Ngữ cảnh cập nhật từ nhóm (`origin/main`, `origin/nhan/du-lieu`, `origin/phong`)
- Nhóm đã thống nhất chuẩn hóa **toàn bộ khóa chính** sang kiểu `INT IDENTITY(1,1)`:
  - `NHAN_VIEN.MaNV` (`02_du_lieu/nhan.sql`): `MaNV` từ `1` đến `11`.
  - `KHACH_HANG.MaKH` (`02_du_lieu/phong.sql`): `MaKH` từ `1` đến `10`.
- Đã cập nhật cột `MaKH` trong [sql/01_bang/thanh.sql](file:///d:/HK261/BidaHub/sql/01_bang/thanh.sql) từ `VARCHAR(10)` sang `INT` để đồng bộ 100% với `02_du_lieu/phong.sql`.

### 2. Thiết kế dữ liệu mẫu trong [sql/02_du_lieu/thanh.sql](file:///d:/HK261/BidaHub/sql/02_du_lieu/thanh.sql)
- **`KHU_VUC` (`MaKhuVuc` 1–5):** 5 khu vực (Phổ thông, Thi đấu, Máy lạnh, Carom & Snooker, Phòng VIP).
- **`LOAI_BAN` (`MaLoaiBan` 1–5):** 5 loại bàn (`Pool 9 bi tiêu chuẩn`, `Pool 9 bi thi đấu`, `Carom 3 băng`, `Carom Libre`, `Snooker 12 feet`).
- **`KHUNG_GIA` (30 dòng = 5 loại bàn × 6 khung giá):** Đầy đủ các khung giờ mở cửa, không chồng lấn giờ.
- **`BAN` (`MaBan` 1–12):** 10 bàn hoạt động, 1 bàn bảo trì, 1 bàn ngưng sử dụng.
- **`PHIEU_DAT_BAN` (`MaDatBan` 1–9) & `GIU_BAN` (9 dòng):** Đầy đủ các trạng thái để test RB5, RB6, `fn_DemBanTrong`.
- Đã commit và push lên nhánh `thanh` (commit `bce4848` & `ffd6f38`).

---

## [2026-11-17] Hoàn thành Task 3 - Trigger RB4–RB6 (`03_trigger/thanh.sql`)

### 1. Bảng mã lỗi của Thành (`50300–50399`)
- `50301` (**RB4**): Khung giá cùng loại bàn và cùng loại ngày áp dụng bị chồng lấn khoảng giờ (`GioBatDau` – `GioKetThuc`).
- `50302` (**RB5**): Một khách hàng có quá 3 phiếu đặt bàn đang ở trạng thái `Chờ xác nhận`.
- `50303` (**RB5**): Phiếu đặt bàn ở trạng thái `Đã xác nhận` không giữ bàn nào trong `GIU_BAN` (hoặc bị xóa bàn cuối cùng).
- `50304` (**RB5**): Giữ bàn đang ở trạng thái `Đang bảo trì` hoặc `Ngưng sử dụng` (hoặc chuyển bàn đang được giữ bởi phiếu `Đã xác nhận` sang bảo trì/ngưng sử dụng).
- `50305` (**RB5**): Một bàn bị giữ cho hai phiếu `Đã xác nhận` có khoảng giờ dự kiến chồng lấn nhau.
- `50306` (**RB6**): Dùng phiếu ở trạng thái `Đã hủy`, `Không đến`, `Chờ xác nhận` hoặc `Đã chuyển thành phiên` để mở thêm phiên chơi.
- `50307` (**RB6**): Khách hàng (`MaKH`) của phiên chơi khác với khách hàng của phiếu đặt bàn gốc.
- `50308` (**RB6**): Đoạn sử dụng bàn đầu tiên (`SoThuTuDoan = 1`) của phiên chơi xuất phát từ phiếu đặt bàn không dùng bàn đã được giữ trong `GIU_BAN`.

### 2. Danh sách 7 Trigger trong [sql/03_trigger/thanh.sql](file:///d:/HK261/BidaHub/sql/03_trigger/thanh.sql)
1. `trg_KhungGia_RB4` (`AFTER INSERT, UPDATE` trên `KHUNG_GIA`)
2. `trg_PhieuDatBan_RB5_RB6` (`AFTER INSERT, UPDATE` trên `PHIEU_DAT_BAN`)
3. `trg_GiuBan_RB5_ThemSua` (`AFTER INSERT, UPDATE` trên `GIU_BAN`)
4. `trg_GiuBan_RB5_Xoa` (`AFTER DELETE, UPDATE` trên `GIU_BAN`)
5. `trg_Ban_RB5` (`AFTER UPDATE` trên `BAN`)
6. `trg_PhienChoi_RB6` (`AFTER INSERT, UPDATE` trên `PHIEN_CHOI`)
7. `trg_DoanSuDungBan_RB6` (`AFTER INSERT, UPDATE` trên `DOAN_SU_DUNG_BAN`)

### 3. File đã tạo / cập nhật
- Tạo mới [sql/03_trigger/thanh.sql](file:///d:/HK261/BidaHub/sql/03_trigger/thanh.sql).
- Cập nhật [CHANGELOG.md](file:///d:/HK261/BidaHub/CHANGELOG.md).
