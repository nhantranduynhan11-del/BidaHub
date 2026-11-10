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
- Nhóm đã thống nhất chuẩn hóa **toàn bộ khóa chính** sang kiểu `INT IDENTITY(1,1)` trong `sql/01_bang/tao_tat_ca_bang.sql`:
  - `NHAN_VIEN.MaNV` (`02_du_lieu/nhan.sql`): `MaNV` từ `1` đến `11` (`1, 2`: Quản lý; `3, 4, 11`: Thu ngân đang làm; `8`: Phục vụ đã nghỉ việc & khóa tài khoản).
  - `KHACH_HANG.MaKH` (`02_du_lieu/phong.sql`): `MaKH` từ `1` đến `10` (`1–5`: Hội viên có app; `6`: Hội viên tại quầy; `7–10`: Khách vãng lai).
- Đã cập nhật cột `MaKH` trong [sql/01_bang/thanh.sql](file:///d:/HK261/BidaHub/sql/01_bang/thanh.sql) từ `VARCHAR(10)` sang `INT` để đồng bộ 100% với `tao_tat_ca_bang.sql` và `02_du_lieu/phong.sql`.

### 2. Thiết kế dữ liệu mẫu trong [sql/02_du_lieu/thanh.sql](file:///d:/HK261/BidaHub/sql/02_du_lieu/thanh.sql)
- **`KHU_VUC` (`MaKhuVuc` 1–5):** 5 khu vực (Phổ thông, Thi đấu, Máy lạnh, Carom & Snooker, Phòng VIP).
- **`LOAI_BAN` (`MaLoaiBan` 1–5):** 5 loại bàn (`Pool 9 bi tiêu chuẩn`, `Pool 9 bi thi đấu`, `Carom 3 băng`, `Carom Libre`, `Snooker 12 feet`).
- **`KHUNG_GIA` (30 dòng = 5 loại bàn × 6 khung giá):**
  - Mỗi loại bàn có `SoThuTuKhung` từ `1` đến `6` phủ kín khung giờ mở cửa `08:00:00` – `23:59:59` cho `Ngày thường` (khung 1, 2, 3), `Cuối tuần` (khung 4, 5) và `Ngày lễ` (khung 6).
  - Không chồng lấn giờ trong cùng `(MaLoaiBan, LoaiNgayApDung)` (đúng RB4, hỗ trợ Dũng viết `DOAN_SU_DUNG_BAN` theo RB8).
- **`BAN` (`MaBan` 1–12):**
  - `MaBan 1–10`: Bàn hoạt động bình thường (`Trống` hoặc `Đã đặt`), phân bổ đều qua 5 khu vực và 5 loại bàn.
  - `MaBan 11`: `Đang bảo trì`, `MaBan 12`: `Ngưng sử dụng` (phục vụ kiểm thử RB5 và RB7).
- **`PHIEU_DAT_BAN` (`MaDatBan` 1–9) & `GIU_BAN` (9 dòng):**
  - `MaDatBan 1, 2, 3` (`Đã chuyển thành phiên`, giữ bàn `1, 4, 7`): Dùng để Dũng liên kết `PHIEN_CHOI.MaDatBan` theo RB6.
  - `MaDatBan 4, 5, 6` (`Đã xác nhận`, giữ bàn `3, 5, 6, 8`): Dùng để kiểm thử `fn_DemBanTrong` (mục 2.4) và RB5 (trong đó phiếu 5 giữ 2 bàn `5` và `6`).
  - `MaDatBan 7` (`Chờ xác nhận`, hội viên `MaKH = 4` đặt qua `Ứng dụng`, `MaNVTiepNhan = NULL`).
  - `MaDatBan 8` (`Đã hủy`) và `MaDatBan 9` (`Không đến`): Đủ 5 trạng thái phiếu đặt bàn để kiểm thử RB6.

### 3. File đã tạo / cập nhật
- Cập nhật [sql/01_bang/thanh.sql](file:///d:/HK261/BidaHub/sql/01_bang/thanh.sql) (`MaKH INT NOT NULL`).
- Tạo mới [sql/02_du_lieu/thanh.sql](file:///d:/HK261/BidaHub/sql/02_du_lieu/thanh.sql).
- Cập nhật [CHANGELOG.md](file:///d:/HK261/BidaHub/CHANGELOG.md).
