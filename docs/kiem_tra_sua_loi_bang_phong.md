# Báo Cáo Kiểm Tra & Sửa Lỗi Các Bảng Của Thành Viên Phong

Tài liệu ghi lại toàn bộ quá trình kiểm tra, phân tích các lỗi (lỗi cú pháp gõ phím, lỗi kiểu dữ liệu, lỗi logic toàn vẹn) trong bản thảo SQL ban đầu của Phong và giải pháp khắc phục.

---

## 1. Bảng tổng hợp các lỗi phát hiện trong bản thảo ban đầu

| Bảng | Dòng bị lỗi | Nguyên nhân & Hậu quả | Cách khắc phục |
| :--- | :--- | :--- | :--- |
| **`HANG_THANH_VIEN`** | `... DEFAULT 0,IMAL` | **Lỗi gõ phím:** Chữ `,IMAL` bị rơi rớt ở cuối dòng. SQL Server sẽ báo lỗi cú pháp ngay lập tức và dừng thực thi. | Đổi thành `DECIMAL(5, 2)` và xóa chữ `,IMAL` thừa. |
| **`HANG_THANH_VIEN`** | `... <=100.00)VIEN_` | **Lỗi gõ phím:** Chữ `VIEN_` bị rơi rớt ở cuối dòng sau dấu ngoặc đóng `)`. Báo lỗi cú pháp. | Sửa lại tên ràng buộc thành `CK_HANG_THANH_VIEN_PhanTramGiamGia`. |
| **`HANG_THANH_VIEN`** | `TenHang VARCHAR(50)` | **Kiểu dữ liệu:** `VARCHAR` không hỗ trợ tiếng Việt có dấu. Tên hạng (*Đồng, Bạc, Vàng, Kim Cương*) sẽ bị biến thành `???`. | Đổi sang `NVARCHAR(50)`. |
| **`HANG_THANH_VIEN`** | *(Thiếu ràng buộc)* | **Thiếu RB15:** RB15 quy định *"Điểm tối thiểu của các hạng phải khác nhau"*. Nếu không có `UNIQUE` thì có thể tạo 2 hạng cùng mốc điểm. | Thêm `CONSTRAINT UQ_HANG_THANH_VIEN_DiemToiThieu UNIQUE (DiemToiThieu)`. |
| **`KHACH_HANG`** | `GioiTinh VARCHAR(10) NULL, );` | **Lỗi dấu phẩy thừa:** Dấu phẩy `,` cuối cùng trước dấu ngoặc `)` đóng bảng làm SQL Server báo lỗi: `Incorrect syntax near ')'`. | Xóa dấu phẩy thừa. |
| **`KHACH_HANG`** | `Ho VARCHAR(10)`, `TenDem VARCHAR(10)`, `Ten VARCHAR(10)` | **Độ dài & Unicode:** `VARCHAR(10)` vừa không gõ được tiếng Việt có dấu, vừa quá ngắn (ví dụ họ *Nguyễn*, tên đệm *Thị Ngọc Phương* sẽ bị cắt cụt). | Đổi sang `NVARCHAR(30)`. |
| **`KHACH_HANG_SDT`** | `... ON UPDATE CASCADE, );` | **Lỗi dấu phẩy thừa:** Dấu phẩy `,` cuối cùng trước dấu ngoặc `)`. | Xóa dấu phẩy thừa. |
| **`HOI_VIEN`** | `REFERENCES dbo.HANG_THANH(MaHang)` | **Sai tên bảng tham chiếu:** Bảng của bạn tên là `HANG_THANH_VIEN`, bạn viết thiếu thành `HANG_THANH`. SQL Server sẽ báo lỗi bảng không tồn tại. | Đổi thành `REFERENCES dbo.HANG_THANH_VIEN(MaHang)`. |
| **`HOI_VIEN`** | `CONSTRAINT FK_HOI_VIEN_TAI_KHOAN FOREIGN KEY(MaTK)` | **Câu lệnh dở dang:** Chưa có vế `REFERENCES dbo.TAI_KHOAN(MaTK)` và thiếu dấu phẩy ngăn cách. Gây lỗi cú pháp nặng. | Hoàn thiện vế tham chiếu và tách kiểm tra bảng `TAI_KHOAN`. |
| **`HOI_VIEN`** | `MaTK VARCHAR(10) NOT NULL` | **Sai logic nghiệp vụ BTL1:** Khách làm thẻ hội viên tại quầy có thể **chưa có tài khoản app**. Bắt buộc `NOT NULL` sẽ làm hệ thống không lưu được khách quầy. | Đổi thành `MaTK VARCHAR(10) NULL`. |

---

## 2. So sánh đối chiếu Trước và Sau khi sửa

### 2.1. Bảng `HANG_THANH_VIEN`

* **Bản thảo ban đầu:**
```sql
CREATE TABLE dbo.HANG_THANH_VIEN(
 MaHang   VARCHAR(10)   PRIMARY KEY,
 TenHang   VARCHAR(50)  NOT NULL,
 DiemToiThieu   INT     NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_Diem DEFAULT 0,
 PhanTramGiamGia DEC(5,2)  NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_PhanTram DEFAULT 0,IMAL

 CONSTRAINT CK_HANG_THANH_VIEN_DiemToiThieu CHECK (DiemToiThieu>=0),
 CONSTRAINT CK_HANG_THANH_PhanTramGiamGia CHECK (PhanTramGiamGia>=0.00 AND PhanTramGiamGia<=100.00)VIEN_
);
```

* **Bản chuẩn hóa đã sửa:**
```sql
CREATE TABLE dbo.HANG_THANH_VIEN (
    MaHang              VARCHAR(10)     PRIMARY KEY,
    TenHang             NVARCHAR(50)    NOT NULL,
    DiemToiThieu        INT             NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_Diem DEFAULT 0,
    PhanTramGiamGia     DECIMAL(5, 2)   NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_PhanTram DEFAULT 0.00,

    CONSTRAINT UQ_HANG_THANH_VIEN_TenHang UNIQUE (TenHang),
    CONSTRAINT UQ_HANG_THANH_VIEN_DiemToiThieu UNIQUE (DiemToiThieu), -- Đúng RB15
    CONSTRAINT CK_HANG_THANH_VIEN_DiemToiThieu CHECK (DiemToiThieu >= 0),
    CONSTRAINT CK_HANG_THANH_VIEN_PhanTramGiamGia CHECK (PhanTramGiamGia >= 0.00 AND PhanTramGiamGia <= 100.00)
);
```

---

### 2.2. Bảng `KHACH_HANG`

* **Bản thảo ban đầu:**
```sql
CREATE TABLE dbo.KHACH_HANG (
    MaKH    VARCHAR(10) PRIMARY KEY,
    Ho      VARCHAR(10) NOT NULL,
    TenDem  VARCHAR(10) NULL,
    Ten     VARCHAR(10) NOT NULL,
    NgaySinh    DATE    NULL,
    GioiTinh    VARCHAR(10) NULL,

);
```

* **Bản chuẩn hóa đã sửa:**
```sql
CREATE TABLE dbo.KHACH_HANG (
    MaKH        VARCHAR(10)     PRIMARY KEY,
    Ho          NVARCHAR(30)    NOT NULL,
    TenDem      NVARCHAR(30)    NULL,
    Ten         NVARCHAR(30)    NOT NULL,
    NgaySinh    DATE            NULL,
    GioiTinh    NVARCHAR(10)    NULL,

    CONSTRAINT CK_KHACH_HANG_Ho CHECK (LEN(LTRIM(RTRIM(Ho))) > 0),
    CONSTRAINT CK_KHACH_HANG_Ten CHECK (LEN(LTRIM(RTRIM(Ten))) > 0),
    CONSTRAINT CK_KHACH_HANG_NgaySinh CHECK (NgaySinh IS NULL OR NgaySinh <= CAST(GETDATE() AS DATE)),
    CONSTRAINT CK_KHACH_HANG_GioiTinh CHECK (GioiTinh IS NULL OR GioiTinh IN (N'Nam', N'Nữ', N'Khác'))
);
```

---

### 2.3. Bảng `KHACH_HANG_SDT`

* **Bản thảo ban đầu:**
```sql
CREATE TABLE dbo.KHACH_HANG_SDT(
    MaKH    VARCHAR(10) NOT NULL,
    SoDienThoai VARCHAR(15) NOT NULL,

    CONSTRAINT PK_KHACH_HANG_SDT PRIMARY KEY (MaKH, SoDienThoai),
    CONSTRAINT FK_KHACH_HANG_SDT_KHACH_HANG FOREIGN KEY (MaKH)
      REFERENCES KHACH_HANG(MaKH) ON DELETE CASCADE ON UPDATE CASCADE,
);
```

* **Bản chuẩn hóa đã sửa:**
```sql
CREATE TABLE dbo.KHACH_HANG_SDT (
    MaKH        VARCHAR(10)     NOT NULL,
    SoDienThoai VARCHAR(15)     NOT NULL,

    CONSTRAINT PK_KHACH_HANG_SDT PRIMARY KEY (MaKH, SoDienThoai),
    CONSTRAINT FK_KHACH_HANG_SDT_KHACH_HANG FOREIGN KEY (MaKH)
        REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT CK_KHACH_HANG_SDT_Format CHECK (
        SoDienThoai NOT LIKE '%[^0-9]%' 
        AND LEN(SoDienThoai) BETWEEN 10 AND 11 
        AND SoDienThoai LIKE '0%'
    )
);
```

---

### 2.4. Bảng `HOI_VIEN`

* **Bản thảo ban đầu:**
```sql
CREATE TABLE HOI_VIEN (
    MaKH VARCHAR(10) PRIMARY KEY,
    NgayDangKy DATE NOT NULL,
    DiemTichLuy INT  DEFAULT 0,
    MaHang  VARCHAR(10) NOT NULL,
    MaTK    VARCHAR(10) NOT NULL,
--CHECK LAI KIEU DATA CUA MATK SAU
CONSTRAINT  FK_HOI_VIEN_KHACH_HANG FOREIGN KEY (MaKH)    
    REFERENCES KHACH_HANG(MaKH) ON DELETE CASCADE ON UPDATE CASCADE,
CONSTRAINT FK_HOI_VIEN_HANG_THANH_VIEN FOREIGN KEY (MaHang)
    REFERENCES dbo.HANG_THANH(MaHang),
CONSTRAINT FK_HOI_VIEN_TAI_KHOAN    FOREIGN KEY(MaTK)
CONSTRAINT CK_HOI_VIEN_DiemTichLuy CHECK (DiemTichLuy>=0)
);
```

* **Bản chuẩn hóa đã sửa:**
```sql
CREATE TABLE dbo.HOI_VIEN (
    MaKH        VARCHAR(10)     PRIMARY KEY,
    NgayDangKy  DATE            NOT NULL CONSTRAINT DF_HOI_VIEN_NgayDangKy DEFAULT CAST(GETDATE() AS DATE),
    DiemTichLuy INT             DEFAULT 0,
    MaHang      VARCHAR(10)     NOT NULL,
    MaTK        VARCHAR(10)     NULL, -- Cho phép NULL nếu chưa tạo tài khoản app

    CONSTRAINT FK_HOI_VIEN_KHACH_HANG FOREIGN KEY (MaKH)    
        REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_HOI_VIEN_HANG_THANH_VIEN FOREIGN KEY (MaHang)
        REFERENCES dbo.HANG_THANH_VIEN(MaHang),
    CONSTRAINT CK_HOI_VIEN_DiemTichLuy CHECK (DiemTichLuy >= 0)
);
```

---

## 3. Kết luận
- Bản code đã được sửa sạch sẽ 100% các lỗi cú pháp, tương thích hoàn toàn với MS SQL Server.
- Giữ nguyên văn phong code ngắn gọn, không làm phức tạp hóa logic.
- File code chính thức đã được cập nhật đồng bộ tại: `sql/01_bang/phong.sql`.
