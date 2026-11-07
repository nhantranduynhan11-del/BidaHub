USE BidaHub;
GO

CREATE TABLE DANH_MUC
(
	MaDanhMuc INT IDENTITY(1,1) NOT NULL,
	TenDanhMuc NVARCHAR(50) NOT NULL,
	CONSTRAINT PK_DanhMuc PRIMARY KEY (MaDanhMuc),
	CONSTRAINT UQ_DanhMuc_Ten UNIQUE (TenDanhMuc)
);
GO

CREATE TABLE MAT_HANG
(
	MaMatHang INT IDENTITY(1,1) NOT NULL,
	TenMatHang NVARCHAR(100) NOT NULL,
	DonViTinh NVARCHAR(50) NOT NULL,
	DonGiaNiemYet DECIMAL(18,2) NOT NULL,
	TrangThaiKinhDoanh NVARCHAR(50) NOT NULL CONSTRAINT DF_MatHang_TrangThai DEFAULT N'Đang bán',
	SoLuongTon INT NOT NULL CONSTRAINT DF_MatHang_SoLuongTon DEFAULT 0,
	MaDanhMuc INT NOT NULL,
	CONSTRAINT PK_MatHang PRIMARY KEY (MaMatHang),
	CONSTRAINT FK_MatHang_DanhMuc FOREIGN KEY (MaDanhMuc) REFERENCES DANH_MUC(MaDanhMuc),
	CONSTRAINT CK_MatHang_DonGia CHECK (DonGiaNiemYet > 0),
	CONSTRAINT CK_MatHang_TrangThai CHECK (TrangThaiKinhDoanh IN (N'Đang bán', N'Ngừng bán')),
	CONSTRAINT CK_MatHang_SoLuongTon CHECK (SoLuongTon >= 0) --RB10
);
GO

CREATE TABLE PHIEN_CHOI
(
	MaPhien INT IDENTITY(1,1) NOT NULL,
	GioBatDau DATETIME2(0) NOT NULL CONSTRAINT DF_PhienChoi_GioBatDau DEFAULT SYSDATETIME(),
	GioKetThuc DATETIME2(0) NULL,
	TrangThai NVARCHAR(50) NOT NULL CONSTRAINT DF_PhienChoi_TrangThai DEFAULT N'Đang chơi',
	GhiChu NVARCHAR(255) NULL,
	MaDatBan INT NULL,
	MaNVMoPhien INT NOT NULL,
	MaKH VARCHAR(10) NULL,
	TongThoiGianChoi AS DATEDIFF(SECOND, GioBatDau, GioKetThuc) PERSISTED, 
	CONSTRAINT PK_PhienChoi PRIMARY KEY (MaPhien),
	CONSTRAINT FK_PhienChoi_NhanVien FOREIGN KEY (MaNVMoPhien) REFERENCES NHAN_VIEN(MaNV),
	CONSTRAINT FK_PhienChoi_KhachHang FOREIGN KEY (MaKH) REFERENCES KHACH_HANG(MaKH),
	-- chờ bảng của Thành
	-- CONSTRAINT FK_PhienChoi_PhieuDatBan FOREIGN KEY (MaDatBan) REFERENCES PHIEU_DAT_BAN(MaDatBan),
	CONSTRAINT CK_PhienChoi_TrangThai CHECK (TrangThai IN (N'Đang chơi', N'Đã kết thúc', N'Đã thanh toán')),
	CONSTRAINT CK_PhienChoi_ThoiGian CHECK (GioKetThuc IS NULL OR GioKetThuc > GioBatDau), --RB7
	CONSTRAINT CK_PhienChoi_KetThucTheoTrangThai CHECK ((TrangThai = N'Đang chơi' AND GioKetThuc IS NULL)
														OR (TrangThai <> N'Đang chơi' AND GioKetThuc IS NOT NULL))
);
GO

-- FK 1:1 cho phép NULL 
CREATE UNIQUE INDEX UQ_PhienChoi_MaDatBan ON PHIEN_CHOI(MaDatBan) WHERE MaDatBan IS NOT NULL;
GO

CREATE TABLE DOAN_SU_DUNG_BAN
(
	MaPhien INT NOT NULL,
	SoThuTuDoan INT NOT NULL,
	GioBatDauDung DATETIME2(0) NOT NULL,
	GioKetThucDung DATETIME2(0) NULL,
	DonGiaApDung DECIMAL(18,2) NOT NULL,
	MaBan INT NOT NULL,
	MaLoaiBan INT NOT NULL,
	SoThuTuKhung INT NOT NULL,
	ThoiLuong AS DATEDIFF(SECOND, GioBatDauDung, GioKetThucDung) PERSISTED, 
	TienGio AS (DATEDIFF(SECOND, GioBatDauDung, GioKetThucDung) * DonGiaApDung / 3600) PERSISTED, --RB9
	CONSTRAINT PK_DoanSuDungBan PRIMARY KEY (MaPhien, SoThuTuDoan),
	CONSTRAINT FK_DoanSuDungBan_PhienChoi FOREIGN KEY (MaPhien) REFERENCES PHIEN_CHOI(MaPhien),
	-- chờ bảng của Thành
	-- CONSTRAINT FK_DoanSuDungBan_Ban FOREIGN KEY (MaBan) REFERENCES BAN(MaBan),
	-- CONSTRAINT FK_DoanSuDungBan_KhungGia FOREIGN KEY (MaLoaiBan, SoThuTuKhung) REFERENCES KHUNG_GIA(MaLoaiBan, SoThuTuKhung),
	CONSTRAINT CK_DoanSuDungBan_SoThuTu CHECK (SoThuTuDoan > 0),
	CONSTRAINT CK_DoanSuDungBan_ThoiGian CHECK (GioKetThucDung IS NULL OR GioKetThucDung > GioBatDauDung), --RB7
	CONSTRAINT CK_DoanSuDungBan_DonGia CHECK (DonGiaApDung > 0)
);
GO

CREATE TABLE DONG_GOI_MON
(
	MaPhien INT NOT NULL,
	SoThuTuDong INT NOT NULL,
	ThoiDiemGoi DATETIME2(0) NOT NULL CONSTRAINT DF_DongGoiMon_ThoiDiemGoi DEFAULT SYSDATETIME(),
	SoLuong INT NOT NULL,
	DonGiaTaiThoiDiemGoi DECIMAL(18,2) NOT NULL,
	TrangThaiPhucVu NVARCHAR(50) NOT NULL CONSTRAINT DF_DongGoiMon_TrangThai DEFAULT N'Chờ chế biến',
	GhiChu NVARCHAR(255) NULL,
	MaMatHang INT NOT NULL,
	MaNVGhiNhan INT NOT NULL,
	ThanhTien AS (SoLuong * DonGiaTaiThoiDiemGoi) PERSISTED,
	CONSTRAINT PK_DongGoiMon PRIMARY KEY (MaPhien, SoThuTuDong),
	CONSTRAINT FK_DongGoiMon_PhienChoi FOREIGN KEY (MaPhien) REFERENCES PHIEN_CHOI(MaPhien),
	CONSTRAINT FK_DongGoiMon_MatHang FOREIGN KEY (MaMatHang) REFERENCES MAT_HANG(MaMatHang),
	CONSTRAINT FK_DongGoiMon_NhanVien FOREIGN KEY (MaNVGhiNhan) REFERENCES NHAN_VIEN(MaNV),
	CONSTRAINT CK_DongGoiMon_SoThuTu CHECK (SoThuTuDong > 0),
	CONSTRAINT CK_DongGoiMon_SoLuong CHECK (SoLuong > 0), --RB10
	CONSTRAINT CK_DongGoiMon_DonGia CHECK (DonGiaTaiThoiDiemGoi > 0),
	CONSTRAINT CK_DongGoiMon_TrangThai CHECK (TrangThaiPhucVu IN (N'Chờ chế biến', N'Đã phục vụ', N'Đã hủy'))
);
GO
