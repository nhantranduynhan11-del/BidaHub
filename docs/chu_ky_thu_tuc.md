# Chuẩn Quy Ước và Chữ Ký Thủ Tục, Hàm – Hệ Thống BidaHub

Tài liệu thống nhất chữ ký, tham số, kiểu dữ liệu trả về và quy ước mã lỗi của cả **5 thành viên Nhóm 5** (Lớp L10 – BTL2 Hệ Quản Trị Cơ Sở Dữ Liệu).

---

## 1. Quy ước chung

### 1.1. Đặt tên và kiểu khóa
- **Bảng và Cột:** Giữ nguyên tên bảng và cột của BTL1 (`KHACH_HANG`, `MaKH`, `DiemTichLuy`, ...).
- **Khóa chính:** Thống nhất kiểu `INT IDENTITY(1,1)` trên toàn bộ thực thể chính; các bảng lớp con (`NV_TOAN_THOI_GIAN`, `NV_BAN_THOI_GIAN`, `HOI_VIEN`) hoặc khóa ghép (`DUOC_CAP`, `KHACH_HANG_SDT`, `KHUNG_GIA`, `GIU_BAN`, `DOAN_SU_DUNG_BAN`, `DONG_GOI_MON`, `CHI_TIET_NHAP`) dùng khóa ngoại `INT` tương ứng.
- **Thủ tục lưu trữ (Stored Procedure):** Tiền tố `sp_` (ví dụ: `sp_ThemKhachHang`, `sp_TraCuuKhachHang`, `sp_ThongKeDoanhThu`).
- **Hàm người dùng (User-Defined Function):** Tiền tố `fn_` (ví dụ: `fn_DemBanTrong`, `fn_DuBaoSoNgayTonKho`).
- **Trigger:** Tiền tố `trg_<BẢNG>_RB<x>_<NộiDung>` theo chuẩn trong `sql/03_trigger/tao_tat_ca_trigger.sql`.

### 1.2. Phân chia dải mã lỗi nghiệp vụ (`THROW 50xxx` & Mã âm UDF)
- **Thủ tục và Trigger:** Dùng `THROW <mã>, N'<thông báo tiếng Việt>', 1;`. Tầng ứng dụng (`app/db.py`) giữ nguyên văn câu thông báo có mã `>= 50000` để hiển thị cho người dùng:
  - **Nhân (Tài khoản & Nhân sự, RB1–RB3):** `50100 – 50199`
  - **Phong (Khách hàng & Hội viên, RB15):** `50200 – 50299`
  - **Thành (Khu vực, Bàn, Khung giá, Đặt bàn, RB4–RB6):** `50300 – 50399`
  - **Dũng (Danh mục, Mặt hàng, Phiên chơi, RB7–RB10):** `50400 – 50499`
  - **Khang (Nhà cung cấp, Nhập kho, Khuyến mãi, Hóa đơn, Thanh toán, RB11–RB14):** `50500 – 50599`
- **Hàm UDF:** SQL Server không cho phép dùng `THROW` trong hàm, nên hàm trả **mã số âm** (`-1`, `-2`, ...) khi đầu vào hoặc dữ liệu không hợp lệ; tầng ứng dụng tra bảng `MA_AM` trong `app/ma_loi.py` để đổi thành câu thông báo tiếng Việt.
- **Lưu ý gọi thủ tục từ Python (`app/db.py`):** `db.goi_thu_tuc(ten, tham_so, ghi=...)` truyền tham số theo thứ tự vị trí và đọc bảng `SELECT` đầu tiên trả về (không đọc tham số `OUTPUT`), nên thủ tục thêm mới nếu cần trả mã vừa sinh thì `SELECT` dòng kết quả ở cuối thủ tục.

---

## 2. Phần việc Thành viên TRẦN DUY NHÂN (Dải `50100 – 50199`)

### 2.1. Danh mục mã lỗi phụ trách (`50100 – 50199`)
- `50101` (RB1): Vai trò Quản lý chỉ được cấp cho tài khoản của nhân viên có chức vụ Quản lý.
- `50102` (RB1): Vai trò Hội viên chỉ được cấp cho tài khoản của hội viên.
- `50103` (RB1): Vai trò Thu ngân, Phục vụ, Pha chế, Thủ kho chỉ được cấp cho tài khoản của nhân viên.
- `50104` (RB1): Tài khoản gán cho nhân viên đang thuộc một hội viên.
- `50105` (RB1): Nhân viên bị đổi khỏi chức vụ Quản lý khi tài khoản vẫn còn vai trò Quản lý.
- `50106` (RB1): Tài khoản gán cho hội viên đang thuộc một nhân viên.
- `50107` (RB2): Không được khóa, cho nghỉ, đổi chức vụ, gỡ vai trò hoặc xóa quản lý hoạt động cuối cùng của hệ thống.
- `50108` (RB3): Người giám sát phải là nhân viên có chức vụ Quản lý.
- `50109` (RB3): Nhân viên đang giám sát người khác không được đổi khỏi chức vụ Quản lý.
- `50110` (RB3): Quan hệ giám sát không được tạo thành vòng lặp.
- `50111` (RB2): Nhân viên đã nghỉ việc hoặc tài khoản bị khóa không được thực hiện nghiệp vụ (tiếp nhận đặt bàn, mở phiên, ghi gọi món, lập phiếu nhập, lập hóa đơn, xác nhận thanh toán).
- `50112` (RB1): Tài khoản mới gán hoặc bị bỏ lại đang giữ vai trò không hợp với loại chủ tài khoản.
- `50113` (RB1): Không được đổi tên các vai trò chuẩn của hệ thống.

### 2.2. Thủ tục khung ứng dụng (`sql/04_thu_tuc/nhan.sql`)

#### `sp_DanhSachNhanVien`
Thủ tục trang mẫu phục vụ khung ứng dụng (`/nhan-vien/`), liên kết 4 bảng (`NHAN_VIEN`, `TAI_KHOAN`, `NV_TOAN_THOI_GIAN`, `NHAN_VIEN` giám sát), có tìm kiếm, lọc và sắp xếp.
```sql
CREATE OR ALTER PROCEDURE dbo.sp_DanhSachNhanVien
    @TuKhoa    NVARCHAR(50) = NULL,     -- tìm trong họ tên hoặc số điện thoại
    @ChucVu    NVARCHAR(20) = NULL,     -- Quản lý | Thu ngân | Phục vụ | Pha chế | Thủ kho
    @TinhTrang NVARCHAR(20) = NULL,     -- Đang làm | Đã nghỉ
    @SapXep    NVARCHAR(20) = N'MaNV',  -- MaNV | HoTen | NgayVaoLam
    @Giam      BIT = 0                  -- 1: sắp xếp giảm dần, 0: tăng dần
```
- **Bảng kết quả trả về:** `MaNV`, `HoTen`, `ChucVu`, `SoDienThoai`, `NgayVaoLam`, `TinhTrangLamViec`, `Tuoi`, `HinhThuc`, `TenDangNhap`, `TrangThaiTaiKhoan`, `NguoiGiamSat`.

### 2.3. Hàm bổ trợ dùng chung & Triggers (RB1 – RB3, Trigger 1 mục 2.2.1)
- **Hàm bổ trợ:** `dbo.fn_NhanVienDangHoatDong(@MaNV INT) RETURNS BIT` — trả `1` nếu nhân viên đang làm việc và tài khoản đang hoạt động, ngược lại trả `0`.
- **View bổ trợ:** `dbo.v_QuanLyHoatDong` (RB2), `dbo.v_VaiTroSaiChu` (RB1).
- **Triggers RB1 (Trigger 1 mục 2.2.1):** `trg_DUOC_CAP_RB1_KiemTraVaiTro`, `trg_NHAN_VIEN_RB1_TaiKhoan`, `trg_HOI_VIEN_RB1_TaiKhoan`, `trg_VAI_TRO_RB1_KhongDoiTen`.
- **Triggers RB2:** `trg_TAI_KHOAN_RB2_GiuQuanLyCuoi`, `trg_NHAN_VIEN_RB2_GiuQuanLyCuoi`, `trg_DUOC_CAP_RB2_GiuQuanLyCuoi`, cùng nhóm 5 trigger kiểm tra nhân viên tác nghiệp (`trg_PHIEU_DAT_BAN_RB2_NhanVien`, `trg_PHIEN_CHOI_RB2_NhanVien`, `trg_DONG_GOI_MON_RB2_NhanVien`, `trg_PHIEU_NHAP_RB2_NhanVien`, `trg_HOA_DON_RB2_NhanVien`, `trg_GIAO_DICH_THANH_TOAN_RB2_NhanVien`).
- **Triggers RB3:** `trg_NHAN_VIEN_RB3_GiamSat`.

---

## 3. Phần việc Thành viên ĐÀO HUY PHONG – MSSV 2412628 (Dải `50200 – 50299`)

### 3.1. Danh mục mã lỗi phụ trách (`50200 – 50299`)
- `50202`: Họ khách hàng không được để trống.
- `50203`: Tên khách hàng không được để trống.
- `50204`: Giới tính không hợp lệ (chỉ nhận `'Nam'`, `'Nữ'`, `'Khác'`).
- `50205`: Ngày sinh không được lớn hơn ngày hiện tại.
- `50206`: Tuổi khách hàng không hợp lệ (vượt quá 120 tuổi).
- `50207`: Số điện thoại không hợp lệ (phải gồm đúng 10 chữ số và bắt đầu bằng số 0).
- `50208`: Số điện thoại đã được đăng ký bởi khách hàng khác.
- `50209`: Không tìm thấy khách hàng với mã đã cung cấp.
- `50210`: Không thể xóa khách hàng vì đã có lịch sử phiếu đặt bàn (`PHIEU_DAT_BAN`).
- `50211`: Không thể xóa khách hàng vì đã có lịch sử phiên chơi (`PHIEN_CHOI`).
- `50212`: Không thể xóa hội viên đang có điểm tích lũy (`> 0`) hoặc đã liên kết tài khoản đăng nhập.
- `50216` (RB15): Hóa đơn của khách không phải hội viên không được cộng điểm.
- `50217` (RB15): Điểm cộng phải bằng 1 điểm cho mỗi 10.000 đồng tổng phải trả, hoặc không được sửa điểm cộng của hóa đơn đã thanh toán.
- `50218` (RB15): Không có hạng thành viên nào phù hợp với điểm tích lũy của hội viên.
- `50219` (RB15): Không xóa được hạng thành viên đang có hội viên.

### 3.2. Chữ ký Thủ tục Thêm / Sửa / Xóa trên `KHACH_HANG` (Câu 2.1 – `sql/04_thu_tuc/phong.sql`)

#### 1. `sp_ThemKhachHang`
Thêm khách hàng mới, kiểm tra dữ liệu đầu vào, tự sinh `MaKH` (`IDENTITY`), lưu số điện thoại vào `KHACH_HANG_SDT` (nếu có) và trả bảng kết quả chứa `MaKH` mới ở cuối thủ tục.
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
- **Bảng kết quả trả về:** `MaKH`, `Ho`, `TenDem`, `Ten`, `HoTen`, `NgaySinh`, `GioiTinh`, `SoDienThoai`.

#### 2. `sp_SuaKhachHang`
Cập nhật thông tin hồ sơ khách hàng và đồng bộ số điện thoại.
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
- **Bảng kết quả trả về:** `MaKH`, `Ho`, `TenDem`, `Ten`, `HoTen`, `NgaySinh`, `GioiTinh`, `SoDienThoai`.

#### 3. `sp_XoaKhachHang`
Xóa hồ sơ khách hàng nhập nhầm / chưa phát sinh giao dịch; chặn xóa nếu đã có đặt bàn (`50210`), phiên chơi (`50211`) hoặc hội viên có điểm / tài khoản (`50212`).
```sql
CREATE OR ALTER PROCEDURE dbo.sp_XoaKhachHang
    @MaKH           INT
```
- **Bảng kết quả trả về:** `DaXoa` (`1`), `ThongBao`.

### 3.3. Chữ ký Thủ tục Tra cứu & Thống kê (Câu 2.3 – `sql/04_thu_tuc/phong.sql`)

#### 1. `sp_TraCuuKhachHang` (Dùng cho màn hình 3.2)
Liên kết 4 bảng (`KHACH_HANG`, `KHACH_HANG_SDT`, `HOI_VIEN`, `HANG_THANH_VIEN`), có `WHERE` và `ORDER BY`.
```sql
CREATE OR ALTER PROCEDURE dbo.sp_TraCuuKhachHang
    @TuKhoa         NVARCHAR(100) = NULL,
    @GioiTinh       NVARCHAR(10)  = NULL,
    @LoaiKhach      NVARCHAR(20)  = NULL,  -- 'HoiVien' | 'VangLai' | NULL
    @MaHang         INT           = NULL,
    @SapXepTheo     VARCHAR(20)   = 'Ten', -- 'Ten' | 'MaKH' | 'DiemTichLuy' | 'NgaySinh'
    @HuongSapXep    VARCHAR(5)    = 'ASC'  -- 'ASC' | 'DESC'
```
- **Bảng kết quả trả về:** `MaKH`, `Ho`, `TenDem`, `Ten`, `HoTen`, `NgaySinh`, `Tuoi`, `GioiTinh`, `SoDienThoai`, `SoDienThoaiChinh`, `LaHoiVien`, `LoaiKhachHang`, `NgayDangKy`, `DiemTichLuy`, `MaHang`, `TenHang`, `PhanTramGiamGia`.

#### 2. `sp_ThongKeChiTieuKhachHang`
Liên kết 5 bảng (`KHACH_HANG`, `HOI_VIEN`, `HANG_THANH_VIEN`, `PHIEN_CHOI`, `HOA_DON`), dùng `COUNT`, `SUM`, `AVG`, `MAX`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`.
```sql
CREATE OR ALTER PROCEDURE dbo.sp_ThongKeChiTieuKhachHang
    @TuNgay                 DATE            = NULL,
    @DenNgay                DATE            = NULL,
    @MaHang                 INT             = NULL,
    @SoLuotChoiToiThieu     INT             = 0,
    @TongChiTieuToiThieu    DECIMAL(18, 2)  = 0.00
```

### 3.4. Hàm UDF có con trỏ CURSOR (`sql/05_ham/phong.sql`) & Triggers RB15 (`sql/03_trigger/phong.sql`)
- **Hàm bổ sung:**
  - `dbo.fn_XacDinhHangThanhVien(@DiemTichLuy INT) RETURNS INT` (`NULL` nếu điểm âm hoặc `NULL`).
  - `dbo.fn_TinhTongChiTieuKhachHang(@MaKH INT) RETURNS DECIMAL(18, 2)` (`-1.00` nếu `@MaKH` không tồn tại).
- **Triggers RB15:** `trg_HOI_VIEN_RB15_CapNhatHang`, `trg_HANG_THANH_VIEN_RB15_XoaHang` (`INSTEAD OF DELETE`), `trg_HANG_THANH_VIEN_RB15_DongBoHang`, `trg_HOA_DON_RB15_TichDiemHoiVien`, `trg_HOA_DON_RB15_BaoVeDiemCong`.

---

## 4. Phần việc Thành viên HOÀNG PHẠM TIẾN THÀNH (Dải `50300 – 50399`)

### 4.1. Danh mục mã lỗi phụ trách (`50300 – 50399`)
- `50301` (RB4): Khung giá cùng loại bàn và cùng loại ngày áp dụng bị chồng lấn khoảng giờ.
- `50302` (RB5): Một khách hàng không được có quá 3 phiếu đặt bàn ở trạng thái `'Chờ xác nhận'`.
- `50303` (RB5): Phiếu đặt bàn ở trạng thái `'Đã xác nhận'` phải giữ ít nhất một bàn trong `GIU_BAN`.
- `50304` (RB5): Không được giữ bàn đang ở trạng thái `'Đang bảo trì'` hoặc `'Ngưng sử dụng'`.
- `50305` (RB5): Một bàn không được giữ cho hai phiếu `'Đã xác nhận'` có khoảng giờ dự kiến chồng lấn.
- `50306` (RB6): Chỉ phiếu ở trạng thái `'Đã xác nhận'` mới được chuyển thành phiên chơi; phiếu đã hủy, không đến hoặc đã chuyển không được mở thêm phiên.
- `50307` (RB6): Phiên chơi mở từ phiếu đặt bàn phải thuộc đúng khách hàng của phiếu đó.
- `50308` (RB6): Đoạn sử dụng bàn đầu tiên (`SoThuTuDoan = 1`) của phiên mở từ phiếu đặt bàn phải dùng một trong các bàn đã giữ của phiếu đó.
- `50309` (RB6): Không được xóa bàn đang được dùng ở đoạn đầu của phiên mở từ phiếu đặt bàn.

### 4.2. Chữ ký Hàm Người Dùng UDF có con trỏ CURSOR (Câu 2.4 – `sql/05_ham/thanh.sql`, dùng cho màn hình 3.3)

#### `fn_DemBanTrong`
Đếm số bàn khả dụng thuộc loại bàn `@MaLoaiBan` trong khoảng thời gian dự kiến `[@GioBatDau, @GioKetThuc)`. Sử dụng `CURSOR` duyệt các bàn thuộc loại bàn (bỏ qua bàn `'Đang bảo trì'` và `'Ngưng sử dụng'`), kiểm tra từng bàn không vướng đoạn sử dụng bàn chồng lấn trong `DOAN_SU_DUNG_BAN` và không bị giữ bởi phiếu `'Đã xác nhận'` chồng lấn giờ trong `PHIEU_DAT_BAN` / `GIU_BAN`.
```sql
CREATE OR ALTER FUNCTION dbo.fn_DemBanTrong (
    @MaLoaiBan  INT,
    @GioBatDau  DATETIME2(0),
    @GioKetThuc DATETIME2(0)
)
RETURNS INT
```
- **Giá trị trả về:** Số lượng bàn còn trống (`>= 0`).
- **Mã âm (khai báo trong `MA_AM` của `app/ma_loi.py`):**
  - `-1`: Thời gian không hợp lệ (`@GioBatDau IS NULL`, `@GioKetThuc IS NULL` hoặc `@GioKetThuc <= @GioBatDau`).
  - `-2`: Mã loại bàn `NULL` hoặc không tìm thấy trong `LOAI_BAN`.

### 4.3. Danh mục Triggers Phụ Trách (RB4 – RB6)
- `trg_KHUNG_GIA_RB4_ChongLanGio` (ON `dbo.KHUNG_GIA`, AFTER INSERT, UPDATE): lỗi `50301`.
- `trg_PHIEU_DAT_BAN_RB5_RB6_TrangThai` (ON `dbo.PHIEU_DAT_BAN`, AFTER INSERT, UPDATE): lỗi `50302`, `50303`, `50304`, `50305`, `50306`, `50307`, `50308`.
- `trg_GIU_BAN_RB5_ThemSua` (ON `dbo.GIU_BAN`, AFTER INSERT, UPDATE): lỗi `50304`, `50305`.
- `trg_GIU_BAN_RB5_RB6_Xoa` (ON `dbo.GIU_BAN`, AFTER UPDATE, DELETE): lỗi `50303`, `50309`.
- `trg_BAN_RB5_TrangThai` (ON `dbo.BAN`, AFTER UPDATE): lỗi `50304`.
- `trg_PHIEN_CHOI_RB6_TuPhieuDat` (ON `dbo.PHIEN_CHOI`, AFTER INSERT, UPDATE): lỗi `50306`, `50307`, `50308`, tự chuyển phiếu sang `'Đã chuyển thành phiên'`.
- `trg_DOAN_SU_DUNG_BAN_RB6_BanDauTien` (ON `dbo.DOAN_SU_DUNG_BAN`, AFTER INSERT, UPDATE, DELETE): lỗi `50308`.

---

## 5. Phần việc Thành viên NGUYỄN TIẾN DŨNG (Dải `50400 – 50499`)

### 5.1. Danh mục mã lỗi phụ trách (`50400 – 50499`)
- `50401` (RB10): Chỉ được gọi mặt hàng đang bán.
- `50402` (RB10): Chỉ được ghi dòng gọi món trong phiên đang chơi.
- `50403` (RB10): Đơn giá tại thời điểm gọi phải bằng đơn giá niêm yết của mặt hàng.
- `50404` (RB10): Dòng gọi món mới không được ở trạng thái `'Đã hủy'`.
- `50405` (RB10): Không được xóa dòng gọi món, chỉ được hủy khi còn chờ chế biến.
- `50406` (RB10): Dòng gọi món đã ghi chỉ được đổi trạng thái phục vụ và ghi chú.
- `50407` (RB10): Chỉ được chuyển dòng đang chờ chế biến sang `'Đã phục vụ'` hoặc `'Đã hủy'`.
- `50408` (RB10): Số lượng tồn của mặt hàng không đủ cho dòng gọi món.
- `50471` (RB7): Không được mở đoạn sử dụng trên bàn đang bảo trì hoặc ngưng sử dụng.
- `50472` (RB7): Đoạn sử dụng bàn phải nằm trong khoảng thời gian của phiên.
- `50473` (RB7): Các đoạn sử dụng bàn của cùng một phiên không được chồng lấn.
- `50474` (RB7): Bàn đã thuộc một đoạn sử dụng khác trong khoảng thời gian này.
- `50475` (RB7): Sửa giờ của phiên làm đoạn sử dụng bàn nằm ngoài khoảng thời gian của phiên.
- `50476` (RB7): Bàn đang có đoạn sử dụng mở, không được chuyển sang `'Đang bảo trì'` hoặc `'Ngưng sử dụng'`.
- `50481` (RB8): Khung giá của đoạn phải thuộc đúng loại bàn của bàn được sử dụng.
- `50482` (RB8): Khung giá phải chứa thời điểm bắt đầu đoạn và đúng loại ngày áp dụng (ngày lễ không kiểm tra tự động vì CSDL không có lịch lễ).
- `50483` (RB8): Đoạn không được đi qua thời điểm đổi khung giá.
- `50484` (RB8): Đơn giá áp dụng phải bằng đơn giá mỗi giờ của khung giá.
- `50485` (RB8): Đoạn đã ghi chỉ được cập nhật giờ kết thúc, đơn giá áp dụng đã được chốt.
- `50486` (RB8): Phiên kết thúc phải có ít nhất một đoạn và mọi đoạn sử dụng bàn đã đóng.
- `50487` (RB8): Các đoạn sử dụng bàn phải phủ kín toàn bộ thời gian của phiên.
- *(Lưu ý: Trong bản riêng `03_trigger/dung.sql`, kiểm tra nhân viên mở phiên/ghi món dùng mã `50491`, `50492`; trong bản ghép `03_trigger/tao_tat_ca_trigger.sql` đã thống nhất về mã `50111` của RB2).*

### 5.2. Chữ ký Hàm Người Dùng UDF có con trỏ CURSOR (Câu 2.4 – `sql/05_ham/dung.sql`)

#### `fn_DuBaoSoNgayTonKho`
Dự báo số ngày còn bán được của một mặt hàng = `SoLuongTon` / lượng bán trung bình mỗi ngày. Lượng bán lấy từ `DONG_GOI_MON` (bỏ dòng `'Đã hủy'`) trong `@SoNgayXet` ngày kết thúc tại `@NgayThamChieu`, con trỏ duyệt tổng số lượng bán theo từng ngày.
```sql
CREATE OR ALTER FUNCTION dbo.fn_DuBaoSoNgayTonKho (
    @MaMatHang      INT,
    @SoNgayXet      INT,   -- từ 1 đến 365, gợi ý 7
    @NgayThamChieu  DATE   -- NULL: lấy ngày gọi món mới nhất trong CSDL
)
RETURNS DECIMAL(18,1)
```
- **Giá trị trả về:** Số ngày dự báo (làm tròn 1 chữ số thập phân), `0` khi mặt hàng đã hết tồn.
- **Mã âm (đổi thành thông báo trong `app/ma_loi.py`):**
  - `-1`: Mã mặt hàng `NULL` hoặc không tồn tại.
  - `-2`: Số ngày xét `NULL` hoặc ngoài khoảng `1` đến `365`.
  - `-3`: Mặt hàng đã ngừng bán.
  - `-4`: Không có dòng gọi món nào trong kỳ xét nên không dự báo được.
- **Lưu ý khi gọi:** Hàm UDF phải truyền đủ 3 tham số (ví dụ truyền `NULL` cho `@NgayThamChieu` để tự lấy ngày mới nhất trong CSDL).

### 5.3. Danh mục Triggers Phụ Trách (RB7, RB8, RB9, RB10)
RB9 không cần trigger vì tiền giờ là cột tính toán `DOAN_SU_DUNG_BAN.TienGio` và làm tròn khi lập hóa đơn (RB12).
- `UQ_DoanSuDungBan_BanDangDung` (filtered unique index trên `DOAN_SU_DUNG_BAN(MaBan) WHERE GioKetThucDung IS NULL`, RB7): vi phạm báo lỗi hệ thống `2601`.
- `trg_DOAN_SU_DUNG_BAN_RB7_KiemTra` (ON `dbo.DOAN_SU_DUNG_BAN`, AFTER INSERT, UPDATE): lỗi `50471 – 50474`.
- `trg_DOAN_SU_DUNG_BAN_RB7_TrangThaiBan`, `trg_GIU_BAN_RB7_TrangThaiBan`, `trg_PHIEU_DAT_BAN_RB7_TrangThaiBan`, `trg_BAN_RB7_BaoTriKhiDangChoi`: tự đồng bộ `BAN.TrangThai` và chặn bảo trì khi đang chơi (`50476`).
- `trg_PHIEN_CHOI_RB7_ThoiGian` (ON `dbo.PHIEN_CHOI`, AFTER UPDATE): lỗi `50475`.
- `trg_DOAN_SU_DUNG_BAN_RB8_KhungGia` (lỗi `50481 – 50483`), `trg_DOAN_SU_DUNG_BAN_RB8_ChotDonGia` (lỗi `50484, 50485`).
- `trg_PHIEN_CHOI_RB8_PhuKin`, `trg_DOAN_SU_DUNG_BAN_RB8_PhuKin` (lỗi `50486, 50487`).
- `trg_DONG_GOI_MON_RB10_GoiMon` (`50401 – 50404`), `trg_DONG_GOI_MON_RB10_KhoaSuaXoa` (`50405 – 50407`), `trg_DONG_GOI_MON_RB10_TonKho` (`50408`, tự trừ/hoàn `MAT_HANG.SoLuongTon`).

---

## 6. Phần việc Thành viên PHẠM PHÚC KHANG (Dải `50500 – 50599`)

### 6.1. Danh mục mã lỗi phụ trách (`50500 – 50599`)
- `50512` (RB11): Người lập phiếu nhập phải có chức vụ Thủ kho hoặc Quản lý.
- `50513` (RB11): Thay đổi dòng nhập làm số lượng tồn của mặt hàng âm hoặc vượt giới hạn.
- `50514` (RB11): Tổng tiền phiếu nhập phải bằng tổng số lượng nhân đơn giá của các dòng nhập.
- `50521` (RB12): Chỉ được lập hóa đơn cho phiên đã kết thúc (có đoạn sử dụng bàn và mọi đoạn đã đóng).
- `50522` (RB12): Người lập hóa đơn phải có chức vụ Thu ngân hoặc Quản lý.
- `50523` (RB12): Phiên đã có hóa đơn, không được thêm đoạn sử dụng bàn.
- `50524` (RB12): Phiên đã có hóa đơn, không được thêm dòng gọi món.
- `50525` (RB12): Tiền giờ chơi phải bằng tổng tiền giờ các đoạn sử dụng bàn đã làm tròn.
- `50526` (RB12): Tiền món phải bằng tổng thành tiền các dòng gọi món chưa hủy.
- `50527` (RB12): Phiên đã lập hóa đơn, không được sửa hoặc xóa dữ liệu tính tiền giờ.
- `50528` (RB12): Phiên đã lập hóa đơn, không được sửa hoặc xóa dữ liệu tính tiền món.
- `50531` (RB13): Khuyến mãi không còn hiệu lực tại ngày lập hóa đơn.
- `50532` (RB13): Thời hạn mới của khuyến mãi không còn chứa ngày lập của các hóa đơn đã áp dụng.
- `50533` (RB13): Chỉ hội viên đã đăng ký trước ngày lập hóa đơn mới được giảm theo hạng.
- `50534` (RB13): Tiền giảm theo hạng phải bằng phần trăm giảm của hạng nhân tiền giờ chơi (làm tròn đến đồng).
- `50535` (RB13): Có tiền giảm khuyến mãi thì hóa đơn phải gắn mã khuyến mãi (`MaKM`).
- `50541` (RB14): Tổng các giao dịch thành công vượt quá tổng phải trả của hóa đơn.
- `50542` (RB14): Hóa đơn đã thanh toán, không được thêm, sửa hoặc xóa giao dịch.
- `50543` (RB14): Hóa đơn đã thanh toán, không được sửa hoặc xóa thông tin tiền.
- `50544` (RB14): Chưa thanh toán đủ, không được đánh dấu `'Đã thanh toán'`.
- `50545` (RB14): Phiên đã thanh toán, không được sửa hoặc xóa dữ liệu tính tiền giờ.
- `50546` (RB14): Hóa đơn đã thanh toán, không được sửa hoặc xóa dữ liệu tính tiền món.
- `50547` (RB14): Phiên đã thanh toán không được sửa, và trạng thái `'Đã thanh toán'` của phiên phải khớp với hóa đơn.
- `50571` (`sp_ThongKeDoanhThu`): Khoảng thời gian thống kê không hợp lệ (`@TuNgay IS NULL`, `@DenNgay IS NULL`, `@TuNgay > @DenNgay` hoặc `@DenNgay = '9999-12-31'`).
- `50572` (`sp_ThongKeDoanhThu`): Doanh thu tối thiểu không hợp lệ (`@DoanhThuToiThieu IS NULL` hoặc `< 0`).

### 6.2. Chữ ký Thủ tục Thống kê Doanh thu (Câu 2.3 – `sql/04_thu_tuc/khang.sql`)

#### `sp_ThongKeDoanhThu`
Thống kê doanh thu theo ngày từ các giao dịch thanh toán thành công, liên kết 3 bảng (`GIAO_DICH_THANH_TOAN`, `HOA_DON`, `PHIEN_CHOI`), sử dụng hàm tổng hợp (`COUNT`, `SUM`), `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`.
```sql
CREATE OR ALTER PROCEDURE dbo.sp_ThongKeDoanhThu
    @TuNgay           DATE,
    @DenNgay          DATE,
    @DoanhThuToiThieu DECIMAL(18,2) = 0
```
- **Bảng kết quả trả về:** `NgayThanhToan`, `SoGiaoDichThanhCong`, `SoHoaDon`, `SoPhienChoi`, `TongDoanhThu` (sắp xếp `NgayThanhToan DESC`).

### 6.3. Danh mục Triggers Phụ Trách (RB11 – RB14 & Trigger 2 mục 2.2.2)
- **Trigger 2 (mục 2.2.2 – tính thuộc tính dẫn xuất `PHIEU_NHAP.TongTien`):** `trg_CHI_TIET_NHAP_RB11_TinhTongTien` (ON `dbo.CHI_TIET_NHAP`, AFTER INSERT, UPDATE, DELETE).
- **Triggers RB11:** `trg_PHIEU_NHAP_RB11_NguoiLap`, `trg_CHI_TIET_NHAP_RB11_CapNhatTonKho`, `trg_PHIEU_NHAP_RB11_KhoaTongTien`.
- **Triggers RB12:** `trg_HOA_DON_RB12_DieuKienLap`, `trg_DOAN_SU_DUNG_BAN_RB12_ChanThemSauHoaDon`, `trg_DONG_GOI_MON_RB12_ChanThemSauHoaDon`, `trg_HOA_DON_RB12_TienGioTienMon`, `trg_DOAN_SU_DUNG_BAN_RB12_RB14_KhoaTienGio`, `trg_DONG_GOI_MON_RB12_RB14_KhoaTienMon`.
- **Triggers RB13:** `trg_HOA_DON_RB13_KhuyenMaiHieuLuc`, `trg_KHUYEN_MAI_RB13_KhoaThoiHan`, `trg_HOA_DON_RB13_TienGiam`.
- **Triggers RB14:** `trg_GIAO_DICH_THANH_TOAN_RB14_ThanhToan` (tự cập nhật `HOA_DON.TrangThaiThanhToan` và `PHIEN_CHOI.TrangThai`), `trg_HOA_DON_RB14_KhoaHoaDonDaTra`, `trg_PHIEN_CHOI_RB14_KhoaPhienDaTra`.
