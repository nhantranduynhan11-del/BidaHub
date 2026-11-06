-- ============================================================================
-- Hệ thống Quản lý Quán Bida - BidaHub
-- Phần việc thành viên: Đào Huy Phong (MSSV: 2412628)
-- File: sql/01_bang/phong.sql
-- Mô tả: Tạo 4 bảng dữ liệu phụ trách gồm HANG_THANH_VIEN, KHACH_HANG, 
--        KHACH_HANG_SDT, HOI_VIEN. Đã sửa toàn bộ lỗi cú pháp, lỗi gõ phím,
--        chuẩn hóa kiểu dữ liệu NVARCHAR và các ràng buộc toàn vẹn.
-- ============================================================================

USE BidaHub;
GO

-- 1. Bảng HANG_THANH_VIEN (Hạng thành viên)
IF OBJECT_ID('dbo.HANG_THANH_VIEN', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.HANG_THANH_VIEN (
        MaHang              VARCHAR(10)     PRIMARY KEY,
        TenHang             NVARCHAR(50)    NOT NULL,
        DiemToiThieu        INT             NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_Diem DEFAULT 0,
        PhanTramGiamGia     DECIMAL(5, 2)   NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_PhanTram DEFAULT 0.00,

        CONSTRAINT UQ_HANG_THANH_VIEN_TenHang UNIQUE (TenHang),
        CONSTRAINT UQ_HANG_THANH_VIEN_DiemToiThieu UNIQUE (DiemToiThieu), -- RB15: Điểm mốc các hạng phải khác nhau
        CONSTRAINT CK_HANG_THANH_VIEN_DiemToiThieu CHECK (DiemToiThieu >= 0),
        CONSTRAINT CK_HANG_THANH_VIEN_PhanTramGiamGia CHECK (PhanTramGiamGia >= 0.00 AND PhanTramGiamGia <= 100.00)
    );
END
GO

-- 2. Bảng KHACH_HANG (Khách hàng)
IF OBJECT_ID('dbo.KHACH_HANG', 'U') IS NULL
BEGIN
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
END
GO

-- 3. Bảng KHACH_HANG_SDT (Số điện thoại khách hàng - Thuộc tính đa trị)
IF OBJECT_ID('dbo.KHACH_HANG_SDT', 'U') IS NULL
BEGIN
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
END
GO

-- 4. Bảng HOI_VIEN (Hội viên - Chuyên biệt hóa từ KHACH_HANG)
IF OBJECT_ID('dbo.HOI_VIEN', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.HOI_VIEN (
        MaKH        VARCHAR(10)     PRIMARY KEY,
        NgayDangKy  DATE            NOT NULL CONSTRAINT DF_HOI_VIEN_NgayDangKy DEFAULT CAST(GETDATE() AS DATE),
        DiemTichLuy INT             DEFAULT 0,
        MaHang      VARCHAR(10)     NOT NULL,
        MaTK        VARCHAR(10)     NULL, -- Cho phép NULL nếu hội viên đăng ký tại quầy chưa có tài khoản app

        CONSTRAINT FK_HOI_VIEN_KHACH_HANG FOREIGN KEY (MaKH)    
            REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT FK_HOI_VIEN_HANG_THANH_VIEN FOREIGN KEY (MaHang)
            REFERENCES dbo.HANG_THANH_VIEN(MaHang),
        CONSTRAINT CK_HOI_VIEN_DiemTichLuy CHECK (DiemTichLuy >= 0)
    );
END
GO

-- Đảm bảo quan hệ 1:1 tùy chọn với TAI_KHOAN (1 tài khoản chỉ dùng cho tối đa 1 hội viên)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_HOI_VIEN_MaTK' AND object_id = OBJECT_ID('dbo.HOI_VIEN'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_HOI_VIEN_MaTK
        ON dbo.HOI_VIEN(MaTK)
        WHERE MaTK IS NOT NULL;
END
GO

-- Khóa ngoại sang TAI_KHOAN (kết nối với bảng của Nhân khi có)
IF OBJECT_ID('dbo.TAI_KHOAN', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_HOI_VIEN_TAI_KHOAN')
    BEGIN
        ALTER TABLE dbo.HOI_VIEN 
            ADD CONSTRAINT FK_HOI_VIEN_TAI_KHOAN FOREIGN KEY (MaTK) REFERENCES dbo.TAI_KHOAN(MaTK);
    END
END
GO
