USE BidaHub;
GO

-- ============================================================================
-- 01_bang/phong.sql (Phong): HANG_THANH_VIEN, KHACH_HANG, KHACH_HANG_SDT, HOI_VIEN
-- ============================================================================

-- 1. BANG HANG_THANH_VIEN
CREATE TABLE dbo.HANG_THANH_VIEN (
    MaHang          INT IDENTITY(1,1) NOT NULL,
    TenHang         NVARCHAR(50)      NOT NULL,
    DiemToiThieu    INT               NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_Diem DEFAULT 0,
    PhanTramGiamGia DECIMAL(5, 2)     NOT NULL CONSTRAINT DF_HANG_THANH_VIEN_PhanTram DEFAULT 0,

    CONSTRAINT PK_HANG_THANH_VIEN PRIMARY KEY (MaHang),
    CONSTRAINT UQ_HANG_THANH_VIEN_DiemToiThieu UNIQUE (DiemToiThieu), -- RB15: Diem toi thieu giua cac hang khac nhau
    CONSTRAINT CK_HANG_THANH_VIEN_DiemToiThieu CHECK (DiemToiThieu >= 0),
    CONSTRAINT CK_HANG_THANH_VIEN_PhanTramGiamGia CHECK (PhanTramGiamGia >= 0.00 AND PhanTramGiamGia <= 100.00)
);
GO

-- 2. BANG KHACH_HANG
CREATE TABLE dbo.KHACH_HANG (
    MaKH        INT IDENTITY(1,1) NOT NULL,
    Ho          NVARCHAR(30)      NOT NULL,
    TenDem      NVARCHAR(30)      NULL,
    Ten         NVARCHAR(30)      NOT NULL,
    NgaySinh    DATE              NULL,
    GioiTinh    NVARCHAR(10)      NULL,

    CONSTRAINT PK_KHACH_HANG PRIMARY KEY (MaKH),
    CONSTRAINT CK_KHACH_HANG_GioiTinh CHECK (GioiTinh IS NULL OR GioiTinh IN (N'Nam', N'Nữ', N'Khác'))
);
GO

-- 3. BANG KHACH_HANG_SDT
CREATE TABLE dbo.KHACH_HANG_SDT (
    MaKH        INT          NOT NULL,
    SoDienThoai VARCHAR(10)  NOT NULL,

    CONSTRAINT PK_KHACH_HANG_SDT PRIMARY KEY (MaKH, SoDienThoai),
    CONSTRAINT FK_KHACH_HANG_SDT_KHACH_HANG FOREIGN KEY (MaKH)
        REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE,
    CONSTRAINT CK_KHACH_HANG_SDT_SoDienThoai CHECK (SoDienThoai LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);
GO

-- 4. BANG HOI_VIEN
CREATE TABLE dbo.HOI_VIEN (
    MaKH        INT          NOT NULL,
    NgayDangKy  DATETIME2(0) NOT NULL CONSTRAINT DF_HOI_VIEN_NgayDangKy DEFAULT SYSDATETIME(),
    DiemTichLuy INT          NOT NULL CONSTRAINT DF_HOI_VIEN_Diem DEFAULT 0,
    MaHang      INT          NOT NULL,
    MaTK        INT          NULL, -- Kieu INT khop voi TAI_KHOAN.MaTK cua Nhan, cho phep NULL khi chua co app

    CONSTRAINT PK_HOI_VIEN PRIMARY KEY (MaKH),
    CONSTRAINT FK_HOI_VIEN_KHACH_HANG FOREIGN KEY (MaKH)    
        REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE,
    CONSTRAINT FK_HOI_VIEN_HANG_THANH_VIEN FOREIGN KEY (MaHang)
        REFERENCES dbo.HANG_THANH_VIEN(MaHang),
    CONSTRAINT FK_HOI_VIEN_TAI_KHOAN FOREIGN KEY (MaTK)
        REFERENCES dbo.TAI_KHOAN(MaTK),
    CONSTRAINT CK_HOI_VIEN_DiemTichLuy CHECK (DiemTichLuy >= 0)
);
GO
