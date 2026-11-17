# Chuẩn Quy Ước và Chữ Ký Thủ Tục, Hàm – Hệ Thống BidaHub

Tài liệu thống nhất chữ ký, tham số, kiểu dữ liệu và quy ước mã lỗi giữa các thành viên Nhóm 5 (Lớp L10 - BTL2 Hệ Cơ Sở Dữ Liệu).

---

## 1. Quy ước chung

### 1.1. Đặt tên
- **Bảng và Cột:** Giữ nguyên chữ hoa và lạc đà theo cấu trúc CSDL (`KHACH_HANG`, `MaKH`, `DiemTichLuy`, ...).
- **Khóa chính:** Thống nhất toàn hệ thống sử dụng kiểu số nguyên tự sinh `INT IDENTITY(1,1)` (ngoại trừ các bảng phân cấp/chuyên biệt hóa như `HOI_VIEN` dùng chung `MaKH INT` với `KHACH_HANG`).
- **Thủ tục lưu trữ (Stored Procedure):** Bắt đầu bằng tiền tố `sp_` (ví dụ: `sp_ThemKhachHang`, `sp_TraCuuKhachHang`).
- **Hàm người dùng (User-Defined Function):** Bắt đầu bằng tiền tố `fn_` (ví dụ: `fn_XacDinhHangThanhVien`).
- **Trigger:** Bắt đầu bằng tiền tố `trg_` (ví dụ: `trg_HOI_VIEN_RB15_CapNhatHang`).

### 1.2. Phân chia dải mã lỗi nghiệp vụ (THROW 50xxx)
Mỗi thành viên phụ trách một dải mã lỗi độc lập để không bị xung đột khi tích hợp:
- **Nhân (Tài khoản & Nhân sự):** `50100 – 50199`
- **Phong (Khách hàng & Hội viên):** `50200 – 50299`
- **Thành (Khu vực, Bàn, Bảng giá, Đặt bàn):** `50300 – 50399`
- **Dũng (Mặt hàng, Danh mục, Phiên chơi):** `50400 – 50499`
- **Khang (Kho, Nhà cung cấp, Hóa đơn, Thanh toán):** `50500 – 50599`

---

## 2. Phần việc Thành viên ĐÀO HUY PHONG (MSSV: 2412628)

### 2.1. Danh mục mã lỗi phụ trách (Dải 50200 – 50299)
- `50201`: Mã khách hàng đã tồn tại.
- `50202`: Họ khách hàng để trống.
- `50203`: Tên khách hàng để trống.
- `50204`: Giới tính không hợp lệ (chỉ nhận 'Nam', 'Nữ', 'Khác').
- `50205`: Ngày sinh lớn hơn ngày hiện tại (ở tương lai).
- `50206`: Tuổi khách hàng không hợp lệ (> 120 tuổi).
- `50207`: Định dạng số điện thoại không hợp lệ (không phải 10-11 số hoặc không bắt đầu bằng số 0).
- `50208`: Số điện thoại đã được đăng ký bởi khách hàng khác.
- `50209`: Không tìm thấy khách hàng với mã cung cấp.
- `50210`: Chặn xóa khách hàng do đã có phiếu đặt bàn (`PHIEU_DAT_BAN`).
- `50211`: Chặn xóa khách hàng do đã có phiên chơi (`PHIEN_CHOI`).
- `50212`: Chặn xóa khách hàng là hội viên có điểm tích lũy hoặc có tài khoản đăng nhập.
- `50215` (RB15): Điểm tích lũy của hội viên không được là số âm.
- `50216` (RB15): Hóa đơn của khách hàng không phải hội viên không được cộng điểm.
- `50217` (RB15): Điểm cộng trên hóa đơn không khớp với quy tắc 1 điểm cho mỗi 10.000 đồng tổng phải trả, hoặc sửa điểm cộng của hóa đơn đã thanh toán.
- `50218` (RB15): Không tìm thấy hạng thành viên phù hợp với điểm tích lũy của hội viên.
- `50219` (RB15): Không thể xóa hạng thành viên đang có hội viên sử dụng.

---

### 2.2. Chữ ký Thủ tục Thêm / Sửa / Xóa (Câu 2.1)

#### 1. `sp_ThemKhachHang`
Thêm khách hàng mới, validate dữ liệu, tự động sinh mã khách hàng (`INT IDENTITY`), tự động lưu số điện thoại.
```sql
CREATE OR ALTER PROCEDURE dbo.sp_ThemKhachHang
    @Ho             NVARCHAR(30),
    @TenDem         NVARCHAR(30) = NULL,
    @Ten            NVARCHAR(30),
    @NgaySinh       DATE         = NULL,
    @GioiTinh       NVARCHAR(10) = NULL,
    @SoDienThoai    VARCHAR(15)  = NULL,
    @MaKH           INT          = NULL OUTPUT
```
- **Giá trị trả về:** Bảng chứa thông tin khách hàng vừa thêm (`MaKH`, `Ho`, `TenDem`, `Ten`, `HoTen`, `NgaySinh`, `GioiTinh`, `SoDienThoai`).

#### 2. `sp_SuaKhachHang`
Cập nhật thông tin khách hàng và số điện thoại, kiểm tra mã tồn tại và tính hợp lệ.
```sql
CREATE OR ALTER PROCEDURE dbo.sp_SuaKhachHang
    @MaKH           INT,
    @Ho             NVARCHAR(30),
    @TenDem         NVARCHAR(30) = NULL,
    @Ten            NVARCHAR(30),
    @NgaySinh       DATE         = NULL,
    @GioiTinh       NVARCHAR(10) = NULL,
    @SoDienThoai    VARCHAR(15)  = NULL
```
- **Giá trị trả về:** Bảng chứa thông tin khách hàng sau khi cập nhật.

#### 3. `sp_XoaKhachHang`
Xóa hồ sơ khách hàng. Kiểm tra nghiêm ngặt tính toàn vẹn (chặn xóa nếu có phiếu đặt, phiên chơi hoặc hội viên có điểm/tài khoản).
```sql
CREATE OR ALTER PROCEDURE dbo.sp_XoaKhachHang
    @MaKH           INT
```
- **Giá trị trả về:** Bảng `{ DaXoa: 1, ThongBao: N'...' }`.

---

### 2.3. Chữ ký Thủ tục Hiển Thị & Thống Kê (Câu 2.3)

#### 1. `sp_TraCuuKhachHang`
Tra cứu khách hàng từ 4 bảng (`KHACH_HANG`, `KHACH_HANG_SDT`, `HOI_VIEN`, `HANG_THANH_VIEN`), có điều kiện WHERE và sắp xếp ORDER BY.
```sql
CREATE OR ALTER PROCEDURE dbo.sp_TraCuuKhachHang
    @TuKhoa         NVARCHAR(100) = NULL,
    @GioiTinh       NVARCHAR(10)  = NULL,
    @LoaiKhach      NVARCHAR(20)  = NULL, -- 'HoiVien' | 'VangLai' | NULL
    @MaHang         INT           = NULL,
    @SapXepTheo     VARCHAR(20)   = 'Ten', -- 'Ten' | 'MaKH' | 'DiemTichLuy' | 'NgaySinh'
    @HuongSapXep    VARCHAR(5)    = 'ASC'  -- 'ASC' | 'DESC'
```

#### 2. `sp_ThongKeChiTieuKhachHang`
Thống kê chi tiêu của khách hàng có aggregate function (`COUNT`, `SUM`, `AVG`, `MAX`), `GROUP BY`, `HAVING`, `WHERE` và `ORDER BY`.
```sql
CREATE OR ALTER PROCEDURE dbo.sp_ThongKeChiTieuKhachHang
    @TuNgay                 DATE            = NULL,
    @DenNgay                DATE            = NULL,
    @MaHang                 INT             = NULL,
    @SoLuotChoiToiThieu     INT             = 0,
    @TongChiTieuToiThieu    DECIMAL(18, 2)  = 0.00
```

---

### 2.4. Chữ ký Hàm Người Dùng UDF có con trỏ CURSOR (Câu 2.4)

#### 1. `fn_XacDinhHangThanhVien`
Xác định mã hạng phù hợp theo điểm tích lũy bằng CURSOR duyệt bảng `HANG_THANH_VIEN` theo thứ tự điểm giảm dần.
```sql
CREATE OR ALTER FUNCTION dbo.fn_XacDinhHangThanhVien (
    @DiemTichLuy INT
)
RETURNS INT
```

#### 2. `fn_TinhTongChiTieuKhachHang`
Tính tổng số tiền đã thanh toán của một khách hàng bằng CURSOR duyệt qua các hóa đơn đã thanh toán.
```sql
CREATE OR ALTER FUNCTION dbo.fn_TinhTongChiTieuKhachHang (
    @MaKH INT
)
RETURNS DECIMAL(18, 2)
```

---

### 2.5. Danh mục Triggers Phụ Trách (Ràng buộc ngữ nghĩa RB15 & Thuộc tính dẫn xuất)
- `trg_HOI_VIEN_RB15_CapNhatHang` (ON `dbo.HOI_VIEN`, AFTER INSERT, UPDATE):
  Tự động chuẩn hóa và cập nhật `MaHang` phù hợp với `DiemTichLuy`. Kiểm tra điểm không âm (lỗi 50215).
- `trg_HANG_THANH_VIEN_RB15_XoaHang` (ON `dbo.HANG_THANH_VIEN`, INSTEAD OF DELETE):
  Chặn xóa hạng thành viên nếu đang có hội viên thuộc về hạng đó (lỗi 50219).
- `trg_HANG_THANH_VIEN_RB15_DongBoHang` (ON `dbo.HANG_THANH_VIEN`, AFTER UPDATE):
  Tự động đồng bộ lại `MaHang` cho toàn bộ hội viên khi thay đổi mốc điểm tối thiểu `DiemToiThieu`.
- `trg_HOA_DON_RB15_TichDiemHoiVien` (ON `dbo.HOA_DON`, AFTER INSERT, UPDATE):
  Tự động tính thuộc tính dẫn xuất `DiemCong = FLOOR(TongPhaiTra / 10000.0)` và cộng vào `DiemTichLuy` của hội viên khi hóa đơn chuyển sang trạng thái `'Đã thanh toán'`. Chặn hóa đơn của khách không phải hội viên có điểm cộng (lỗi 50216).
- `trg_HOA_DON_RB15_BaoVeDiemCong` (ON `dbo.HOA_DON`, AFTER UPDATE):
  Khóa không cho phép sửa đổi `DiemCong` trên các hóa đơn đã thanh toán (lỗi 50217).
