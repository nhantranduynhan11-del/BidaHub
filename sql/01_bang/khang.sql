USE BidaHub;
GO


-- BANG 1: NHA_CUNG_CAP
IF OBJECT_ID(N'dbo.NHA_CUNG_CAP', N'U') IS NULL
BEGIN
CREATE TABLE NHA_CUNG_CAP
(
    MaNCC INT IDENTITY(1,1) NOT NULL,
    TenNhaCungCap NVARCHAR(150) NOT NULL,
    DiaChi NVARCHAR(255) NULL,
    SoDienThoai NVARCHAR(20) NULL,
    Email NVARCHAR(254) NULL,

    CONSTRAINT PK_NhaCungCap
        PRIMARY KEY (MaNCC),

    CONSTRAINT CK_NhaCungCap_Ten CHECK (LEN(LTRIM(RTRIM(TenNhaCungCap))) > 0),

    CONSTRAINT CK_NhaCungCap_Email
        CHECK (Email IS NULL OR (Email LIKE N'_%@_%._%' AND Email NOT LIKE N'% %' 
        AND LEN(Email) - LEN(REPLACE(Email, N'@', N'')) = 1))
);
END;
GO


-- BANG 2: KHUYEN_MAI

IF OBJECT_ID(N'dbo.KHUYEN_MAI', N'U') IS NULL
BEGIN
CREATE TABLE KHUYEN_MAI
(
    MaKM INT IDENTITY(1,1) NOT NULL,
    TenChuongTrinh NVARCHAR(150) NOT NULL,
    HinhThucGiam NVARCHAR(30) NOT NULL,
    GiaTriGiam DECIMAL(18,2) NOT NULL,
    NgayBatDau DATE NOT NULL,
    NgayKetThuc DATE NOT NULL,

    CONSTRAINT PK_KhuyenMai PRIMARY KEY (MaKM),

    CONSTRAINT CK_KhuyenMai_Ten CHECK (LEN(LTRIM(RTRIM(TenChuongTrinh))) > 0),

    CONSTRAINT CK_KhuyenMai_HinhThuc CHECK (HinhThucGiam IN (N'Phần trăm', N'Số tiền')),

    CONSTRAINT CK_KhuyenMai_GiaTri CHECK (GiaTriGiam >= 0 AND (HinhThucGiam <> N'Phần trăm'
                OR GiaTriGiam <= 100)),

    CONSTRAINT CK_KhuyenMai_Ngay CHECK (NgayKetThuc >= NgayBatDau)
);
END;
GO


-- BANG 3: PHIEU_NHAP

CREATE TABLE PHIEU_NHAP
(
    MaPhieuNhap INT IDENTITY(1,1) NOT NULL,
    NgayNhap DATE NOT NULL,
    GhiChu NVARCHAR(500) NULL,
    MaNCC INT NOT NULL,
    MaNVLap INT NOT NULL,
    TongTien DECIMAL(18,2) NOT NULL CONSTRAINT DF_PhieuNhap_TongTien DEFAULT (0),

    CONSTRAINT PK_PhieuNhap PRIMARY KEY (MaPhieuNhap),

    CONSTRAINT FK_PhieuNhap_NhaCungCap FOREIGN KEY (MaNCC) REFERENCES NHA_CUNG_CAP(MaNCC),

    CONSTRAINT FK_PhieuNhap_NhanVien FOREIGN KEY (MaNVLap) REFERENCES NHAN_VIEN(MaNV),

    CONSTRAINT CK_PhieuNhap_TongTien CHECK (TongTien >= 0)
);
GO


-- BANG 4: CHI_TIET_NHAP

CREATE TABLE CHI_TIET_NHAP
(
    MaPhieuNhap INT NOT NULL,
    MaMatHang INT NOT NULL,
    SoLuongNhap INT NOT NULL,
    DonGiaNhap DECIMAL(18,2) NOT NULL,

    CONSTRAINT PK_ChiTietNhap PRIMARY KEY (MaPhieuNhap, MaMatHang),

    CONSTRAINT FK_ChiTietNhap_PhieuNhap FOREIGN KEY (MaPhieuNhap) REFERENCES PHIEU_NHAP(MaPhieuNhap),
    -- Tam thoi chua tao FK den MAT_HANG
    -- CONSTRAINT FK_ChiTietNhap_MatHang FOREIGN KEY (MaMatHang) REFERENCES MAT_HANG(MaMatHang),
    CONSTRAINT CK_ChiTietNhap_SoLuong CHECK (SoLuongNhap > 0),
    CONSTRAINT CK_ChiTietNhap_DonGia CHECK (DonGiaNhap > 0)
);
GO


-- BANG 5: HOA_DON

CREATE TABLE HOA_DON
(
    MaHoaDon INT IDENTITY(1,1) NOT NULL,
    ThoiDiemLap DATETIME2(0) NOT NULL CONSTRAINT DF_HoaDon_ThoiDiemLap DEFAULT SYSDATETIME(),
    DiemCong INT NOT NULL CONSTRAINT DF_HoaDon_DiemCong DEFAULT (0),
    TrangThaiThanhToan NVARCHAR(30) NOT NULL CONSTRAINT DF_HoaDon_TrangThai DEFAULT N'Chưa thanh toán',
    MaPhien INT NOT NULL,
    MaNVLap INT NOT NULL,
    MaKM INT NULL,

    TienGioChoi DECIMAL(18,2) NOT NULL CONSTRAINT DF_HoaDon_TienGioChoi DEFAULT (0),
    TienMon DECIMAL(18,2) NOT NULL CONSTRAINT DF_HoaDon_TienMon DEFAULT (0),
    TienGiam DECIMAL(18,2) NOT NULL CONSTRAINT DF_HoaDon_TienGiam DEFAULT (0),
    TongPhaiTra DECIMAL(18,2) NOT NULL CONSTRAINT DF_HoaDon_TongPhaiTra DEFAULT (0),
    CONSTRAINT PK_HoaDon PRIMARY KEY (MaHoaDon),
    CONSTRAINT UQ_HoaDon_MaPhien UNIQUE (MaPhien),
    -- Tam thoi chua tao FK den PHIEN_CHOI
    -- CONSTRAINT FK_HoaDon_PhienChoi FOREIGN KEY (MaPhien) REFERENCES PHIEN_CHOI(MaPhien),
    CONSTRAINT FK_HoaDon_NhanVien FOREIGN KEY (MaNVLap) REFERENCES NHAN_VIEN(MaNV),
    CONSTRAINT FK_HoaDon_KhuyenMai FOREIGN KEY (MaKM) REFERENCES KHUYEN_MAI(MaKM),
    CONSTRAINT CK_HoaDon_DiemCong CHECK (DiemCong >= 0),
    CONSTRAINT CK_HoaDon_TrangThai CHECK (TrangThaiThanhToan IN (N'Chưa thanh toán', N'Thanh toán một phần', N'Đã thanh toán')),
    CONSTRAINT CK_HoaDon_Tien CHECK ( TienGioChoi >= 0 AND TienMon >= 0 AND TienGiam >= 0
            AND TongPhaiTra >= 0 AND TienGiam <= TienGioChoi + TienMon)
);
GO


-- BANG 6: GIAO_DICH_THANH_TOAN

CREATE TABLE GIAO_DICH_THANH_TOAN
(
    MaGD INT IDENTITY(1,1) NOT NULL,
    ThoiDiemThanhToan DATETIME2(0) NOT NULL CONSTRAINT DF_GiaoDich_ThoiDiem DEFAULT SYSDATETIME(),
    SoTien DECIMAL(18,2) NOT NULL,
    PhuongThuc NVARCHAR(30) NOT NULL,
    MaThamChieu NVARCHAR(100) NULL,
    TrangThai NVARCHAR(30) NOT NULL,
    MaHoaDon INT NOT NULL,
    MaNVXacNhan INT NOT NULL,

    CONSTRAINT PK_GiaoDich PRIMARY KEY (MaGD),
    CONSTRAINT FK_GiaoDich_HoaDon FOREIGN KEY (MaHoaDon) REFERENCES HOA_DON(MaHoaDon),
    CONSTRAINT FK_GiaoDich_NhanVien FOREIGN KEY (MaNVXacNhan) REFERENCES NHAN_VIEN(MaNV),
    CONSTRAINT CK_GiaoDich_SoTien CHECK (SoTien > 0),
    CONSTRAINT CK_GiaoDich_PhuongThuc CHECK (PhuongThuc IN (N'Tiền mặt', N'Chuyển khoản/QR', N'Ví điện tử')),
    CONSTRAINT CK_GiaoDich_TrangThai CHECK (TrangThai IN (N'Thành công', N'Thất bại'))
);
GO
