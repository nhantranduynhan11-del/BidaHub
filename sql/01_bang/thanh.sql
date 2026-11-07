USE BidaHub;
GO

-- 1. BẢNG KHU_VUC
CREATE TABLE dbo.KHU_VUC
(
    MaKhuVuc    INT IDENTITY(1,1) NOT NULL,
    TenKhuVuc   NVARCHAR(50)      NOT NULL,

    CONSTRAINT PK_KhuVuc PRIMARY KEY (MaKhuVuc),
    CONSTRAINT UQ_KhuVuc_Ten UNIQUE (TenKhuVuc),
    CONSTRAINT CK_KhuVuc_Ten CHECK (LEN(LTRIM(RTRIM(TenKhuVuc))) > 0)
);
GO

-- 2. BẢNG LOAI_BAN
CREATE TABLE dbo.LOAI_BAN
(
    MaLoaiBan   INT IDENTITY(1,1) NOT NULL,
    TenLoai     NVARCHAR(50)      NOT NULL,
    MoTa        NVARCHAR(255)     NULL,

    CONSTRAINT PK_LoaiBan PRIMARY KEY (MaLoaiBan),
    CONSTRAINT UQ_LoaiBan_Ten UNIQUE (TenLoai),
    CONSTRAINT CK_LoaiBan_Ten CHECK (LEN(LTRIM(RTRIM(TenLoai))) > 0)
);
GO

-- 3. BẢNG KHUNG_GIA
CREATE TABLE dbo.KHUNG_GIA
(
    MaLoaiBan       INT           NOT NULL,
    SoThuTuKhung    INT           NOT NULL,
    TenKhung        NVARCHAR(50)  NOT NULL,
    LoaiNgayApDung  NVARCHAR(30)  NOT NULL,
    GioBatDau       TIME(0)       NOT NULL,
    GioKetThuc      TIME(0)       NOT NULL,
    DonGiaMoiGio    DECIMAL(18,2) NOT NULL,

    CONSTRAINT PK_KhungGia PRIMARY KEY (MaLoaiBan, SoThuTuKhung),
    CONSTRAINT FK_KhungGia_LoaiBan FOREIGN KEY (MaLoaiBan)
        REFERENCES dbo.LOAI_BAN(MaLoaiBan),
    CONSTRAINT CK_KhungGia_SoThuTu CHECK (SoThuTuKhung > 0),
    CONSTRAINT CK_KhungGia_LoaiNgay CHECK (LoaiNgayApDung IN (N'Ngày thường', N'Cuối tuần', N'Ngày lễ')),
    CONSTRAINT CK_KhungGia_Gio CHECK (GioKetThuc > GioBatDau), -- RB4: Giờ kết thúc sau giờ bắt đầu
    CONSTRAINT CK_KhungGia_DonGia CHECK (DonGiaMoiGio > 0)      -- RB4: Đơn giá mỗi giờ > 0
);
GO

-- 4. BẢNG BAN
CREATE TABLE dbo.BAN
(
    MaBan           INT IDENTITY(1,1) NOT NULL,
    TenBan          NVARCHAR(50)      NOT NULL,
    SucChuaDeXuat   INT               NOT NULL,
    TrangThai       NVARCHAR(30)      NOT NULL CONSTRAINT DF_Ban_TrangThai DEFAULT N'Trống',
    MaKhuVuc        INT               NOT NULL,
    MaLoaiBan       INT               NOT NULL,

    CONSTRAINT PK_Ban PRIMARY KEY (MaBan),
    CONSTRAINT UQ_Ban_TenBan UNIQUE (TenBan),
    CONSTRAINT FK_Ban_KhuVuc FOREIGN KEY (MaKhuVuc)
        REFERENCES dbo.KHU_VUC(MaKhuVuc),
    CONSTRAINT FK_Ban_LoaiBan FOREIGN KEY (MaLoaiBan)
        REFERENCES dbo.LOAI_BAN(MaLoaiBan),
    CONSTRAINT CK_Ban_SucChua CHECK (SucChuaDeXuat > 0),
    CONSTRAINT CK_Ban_TrangThai CHECK (TrangThai IN (
        N'Trống', N'Đang chơi', N'Đã đặt', N'Đang bảo trì', N'Ngưng sử dụng'
    ))
);
GO

-- 5. BẢNG PHIEU_DAT_BAN
CREATE TABLE dbo.PHIEU_DAT_BAN
(
    MaDatBan            INT IDENTITY(1,1) NOT NULL,
    ThoiDiemLap         DATETIME2(0)      NOT NULL CONSTRAINT DF_PhieuDatBan_ThoiDiemLap DEFAULT SYSDATETIME(),
    GioBatDauDuKien     DATETIME2(0)      NOT NULL,
    GioKetThucDuKien    DATETIME2(0)      NOT NULL,
    SoNguoi             INT               NOT NULL,
    KenhTiepNhan        NVARCHAR(30)      NOT NULL,
    TrangThai           NVARCHAR(30)      NOT NULL CONSTRAINT DF_PhieuDatBan_TrangThai DEFAULT N'Chờ xác nhận',
    GhiChu              NVARCHAR(500)     NULL,
    MaKH                VARCHAR(10)       NOT NULL, -- Khớp với KHACH_HANG.MaKH (VARCHAR(10)) của Phong
    MaNVTiepNhan        INT               NULL,     -- Khớp với NHAN_VIEN.MaNV (INT) của Nhân; NULL khi chờ xác nhận

    CONSTRAINT PK_PhieuDatBan PRIMARY KEY (MaDatBan),
    CONSTRAINT FK_PhieuDatBan_KhachHang FOREIGN KEY (MaKH)
        REFERENCES dbo.KHACH_HANG(MaKH),
    CONSTRAINT FK_PhieuDatBan_NhanVien FOREIGN KEY (MaNVTiepNhan)
        REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_PhieuDatBan_GioDuKien CHECK (GioKetThucDuKien > GioBatDauDuKien), -- RB5
    CONSTRAINT CK_PhieuDatBan_SoNguoi CHECK (SoNguoi > 0),
    CONSTRAINT CK_PhieuDatBan_Kenh CHECK (KenhTiepNhan IN (
        N'Tại quầy', N'Điện thoại', N'Mạng xã hội', N'Ứng dụng'
    )),
    CONSTRAINT CK_PhieuDatBan_TrangThai CHECK (TrangThai IN (
        N'Chờ xác nhận', N'Đã xác nhận', N'Đã hủy', N'Không đến', N'Đã chuyển thành phiên'
    ))
);
GO

-- 6. BẢNG GIU_BAN
CREATE TABLE dbo.GIU_BAN
(
    MaDatBan    INT NOT NULL,
    MaBan       INT NOT NULL,

    CONSTRAINT PK_GiuBan PRIMARY KEY (MaDatBan, MaBan),
    CONSTRAINT FK_GiuBan_PhieuDatBan FOREIGN KEY (MaDatBan)
        REFERENCES dbo.PHIEU_DAT_BAN(MaDatBan),
    CONSTRAINT FK_GiuBan_Ban FOREIGN KEY (MaBan)
        REFERENCES dbo.BAN(MaBan)
);
GO

