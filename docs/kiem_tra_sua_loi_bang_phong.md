# Báo Cáo Kiểm Tra & Sửa Lỗi Các Bảng Của Thành Viên Phong

Tài liệu giải thích ngắn gọn các lỗi cú pháp gõ phím trong bản thảo ban đầu của Phong và phiên bản code đã sửa gọn gàng, giữ nguyên 100% logic của bạn.

---

## 1. Các lỗi nhỏ trong bản nháp ban đầu

1. **Bảng `HANG_THANH_VIEN`:**
   * Dòng `... DEFAULT 0,IMAL`: Bị chữ `,IMAL` rơi rớt ở cuối dòng $\rightarrow$ Lỗi cú pháp khi chạy.
   * Dòng `... <=100.00)VIEN_`: Bị chữ `VIEN_` rơi rớt ở cuối dòng $\rightarrow$ Lỗi cú pháp khi chạy.
   * Cột `TenHang`: Đổi sang `NVARCHAR(50)` để gõ được tiếng Việt có dấu (*Đồng, Bạc, Vàng, Kim Cương* không bị biến thành `???`).
   * Thêm `UNIQUE (DiemToiThieu)` theo đúng RB15 (điểm mốc giữa các hạng không được trùng nhau).

2. **Bảng `KHACH_HANG`:**
   * Dòng `GioiTinh VARCHAR(10) NULL,`: Có dấu phẩy `,` ngay trước dấu đóng ngoặc `)` $\rightarrow$ SQL Server báo lỗi: `Incorrect syntax near ')'`.
   * Cột `Ho`, `TenDem`, `Ten`: Đổi sang `NVARCHAR(30)` để lưu được tiếng Việt có dấu và không bị tràn ký tự với các họ tên dài.

3. **Bảng `KHACH_HANG_SDT`:**
   * Dòng `ON UPDATE CASCADE,`: Bị thừa dấu phẩy `,` trước dấu đóng ngoặc `)`.

4. **Bảng `HOI_VIEN`:**
   * Dòng `REFERENCES dbo.HANG_THANH(MaHang)`: Tên bảng thiếu `_VIEN` $\rightarrow$ Đổi thành `dbo.HANG_THANH_VIEN(MaHang)`.
   * Dòng `CONSTRAINT FK_HOI_VIEN_TAI_KHOAN FOREIGN KEY(MaTK)`: Viết dở dang thiếu vế `REFERENCES dbo.TAI_KHOAN(MaTK)`.
   * **Giải quyết lưu ý `--CHECK LAI KIEU DATA CUA MATK SAU` của bạn:** Trong bảng `TAI_KHOAN` của bạn Nhân, cột `MaTK` có kiểu là `INT IDENTITY(1,1)`. Do đó `MaTK` trong bảng `HOI_VIEN` **bắt buộc phải để kiểu `INT`** để khóa ngoại khớp kiểu dữ liệu. Đồng thời để `NULL` để hội viên đăng ký tại quầy không bắt buộc phải có tài khoản app.

---

## 2. Đoạn code hoàn chỉnh, giữ nguyên 100% logic của bạn

```sql
USE BidaHub;
GO

-- 1. BANG HANG_THANH_VIEN
CREATE TABLE dbo.HANG_THANH_VIEN (
    MaHang          VARCHAR(10)     PRIMARY KEY,
    TenHang         NVARCHAR(50)    NOT NULL,
    DiemToiThieu    INT             NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_Diem DEFAULT 0,
    PhanTramGiamGia DECIMAL(5, 2)   NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_PhanTram DEFAULT 0,

    CONSTRAINT UQ_HANG_THANH_VIEN_DiemToiThieu UNIQUE (DiemToiThieu), -- RB15: Diem toi thieu giua cac hang khac nhau
    CONSTRAINT CK_HANG_THANH_VIEN_DiemToiThieu CHECK (DiemToiThieu >= 0),
    CONSTRAINT CK_HANG_THANH_VIEN_PhanTramGiamGia CHECK (PhanTramGiamGia >= 0.00 AND PhanTramGiamGia <= 100.00)
);
GO

-- 2. BANG KHACH_HANG
CREATE TABLE dbo.KHACH_HANG (
    MaKH        VARCHAR(10)     PRIMARY KEY,
    Ho          NVARCHAR(30)    NOT NULL,
    TenDem      NVARCHAR(30)    NULL,
    Ten         NVARCHAR(30)    NOT NULL,
    NgaySinh    DATE            NULL,
    GioiTinh    NVARCHAR(10)    NULL
);
GO

-- 3. BANG KHACH_HANG_SDT
CREATE TABLE dbo.KHACH_HANG_SDT (
    MaKH        VARCHAR(10)     NOT NULL,
    SoDienThoai VARCHAR(15)     NOT NULL,

    CONSTRAINT PK_KHACH_HANG_SDT PRIMARY KEY (MaKH, SoDienThoai),
    CONSTRAINT FK_KHACH_HANG_SDT_KHACH_HANG FOREIGN KEY (MaKH)
        REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE ON UPDATE CASCADE
);
GO

-- 4. BANG HOI_VIEN
CREATE TABLE dbo.HOI_VIEN (
    MaKH        VARCHAR(10)     PRIMARY KEY,
    NgayDangKy  DATE            NOT NULL CONSTRAINT DF_HOI_VIEN_NgayDangKy DEFAULT CAST(GETDATE() AS DATE),
    DiemTichLuy INT             DEFAULT 0,
    MaHang      VARCHAR(10)     NOT NULL,
    MaTK        INT             NULL, -- Kieu INT khop voi TAI_KHOAN.MaTK cua Nhan, cho phep NULL khi chua co app

    CONSTRAINT FK_HOI_VIEN_KHACH_HANG FOREIGN KEY (MaKH)    
        REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_HOI_VIEN_HANG_THANH_VIEN FOREIGN KEY (MaHang)
        REFERENCES dbo.HANG_THANH_VIEN(MaHang),
    CONSTRAINT FK_HOI_VIEN_TAI_KHOAN FOREIGN KEY (MaTK)
        REFERENCES dbo.TAI_KHOAN(MaTK),
    CONSTRAINT CK_HOI_VIEN_DiemTichLuy CHECK (DiemTichLuy >= 0)
);
GO
```
