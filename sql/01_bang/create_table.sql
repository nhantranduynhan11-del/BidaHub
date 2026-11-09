USE BidaHub;
GO
-- Xóa bảng cũ theo thứ tự NGƯỢC với khóa ngoại (bảng con trước, bảng cha sau).
DROP TABLE IF EXISTS
    dbo.GIAO_DICH_THANH_TOAN,
    dbo.HOA_DON,
    dbo.CHI_TIET_NHAP,
    dbo.PHIEU_NHAP,
    dbo.KHUYEN_MAI,
    dbo.NHA_CUNG_CAP,
    dbo.DONG_GOI_MON,
    dbo.DOAN_SU_DUNG_BAN,
    dbo.PHIEN_CHOI,
    dbo.MAT_HANG,
    dbo.DANH_MUC,
    dbo.GIU_BAN,
    dbo.PHIEU_DAT_BAN,
    dbo.BAN,
    dbo.KHUNG_GIA,
    dbo.LOAI_BAN,
    dbo.KHU_VUC,
    dbo.HOI_VIEN,
    dbo.KHACH_HANG_SDT,
    dbo.KHACH_HANG,
    dbo.HANG_THANH_VIEN,
    dbo.NV_BAN_THOI_GIAN,
    dbo.NV_TOAN_THOI_GIAN,
    dbo.NHAN_VIEN,
    dbo.DUOC_CAP,
    dbo.VAI_TRO,
    dbo.TAI_KHOAN;
GO

CREATE TABLE dbo.TAI_KHOAN
(
    MaTK            INT IDENTITY(1,1)   NOT NULL,
    TenDangNhap     NVARCHAR(50)        NOT NULL,
    MatKhau         CHAR(64)            NOT NULL,   -- mã băm SHA-256 dạng hex
    Email           NVARCHAR(50)        NOT NULL,
    TrangThai       NVARCHAR(50)        NOT NULL CONSTRAINT DF_TaiKhoan_TrangThai DEFAULT N'Hoạt động',
    NgayTao         DATETIME2(0)        NOT NULL CONSTRAINT DF_TaiKhoan_NgayTao DEFAULT SYSDATETIME(),

    CONSTRAINT PK_TaiKhoan PRIMARY KEY (MaTK),
    CONSTRAINT UQ_TaiKhoan_TenDangNhap UNIQUE (TenDangNhap),   -- RB1
    CONSTRAINT UQ_TaiKhoan_Email UNIQUE (Email),               -- RB1
    CONSTRAINT CK_TaiKhoan_TrangThai CHECK (TrangThai IN (N'Hoạt động', N'Bị khóa')),
    CONSTRAINT CK_TaiKhoan_TenDangNhap CHECK (LEN(TenDangNhap) >= 6 AND TenDangNhap NOT LIKE N'% %'),  -- RB1
    CONSTRAINT CK_TaiKhoan_MatKhauBam CHECK (LEN(MatKhau) = 64
        AND MatKhau COLLATE Latin1_General_BIN NOT LIKE '%[^0-9a-fA-F]%'),                           -- RB1
    CONSTRAINT CK_TaiKhoan_Email CHECK (Email LIKE N'_%@_%._%' AND Email NOT LIKE N'% %'
        AND LEN(Email) - LEN(REPLACE(Email, N'@', N'')) = 1)
);
GO

CREATE TABLE dbo.VAI_TRO
(
    MaVaiTro        INT IDENTITY(1,1)   NOT NULL,
    TenVaiTro       NVARCHAR(50)        NOT NULL,
    MoTa            NVARCHAR(255)       NULL,

    CONSTRAINT PK_VaiTro PRIMARY KEY (MaVaiTro),
    CONSTRAINT UQ_VaiTro_Ten UNIQUE (TenVaiTro),
    CONSTRAINT CK_VaiTro_Ten CHECK (TenVaiTro IN (N'Quản lý', N'Thu ngân', N'Phục vụ', N'Pha chế', N'Thủ kho', N'Hội viên'))
);
GO

CREATE TABLE dbo.DUOC_CAP
(
    MaTK            INT                 NOT NULL,
    MaVaiTro        INT                 NOT NULL,
    NgayCap         DATETIME2(0)        NOT NULL CONSTRAINT DF_DuocCap_NgayCap DEFAULT SYSDATETIME(),

    CONSTRAINT PK_DuocCap PRIMARY KEY (MaTK, MaVaiTro),
    CONSTRAINT FK_DuocCap_TaiKhoan FOREIGN KEY (MaTK) REFERENCES dbo.TAI_KHOAN(MaTK),
    CONSTRAINT FK_DuocCap_VaiTro FOREIGN KEY (MaVaiTro) REFERENCES dbo.VAI_TRO(MaVaiTro)
);
GO

CREATE TABLE dbo.NHAN_VIEN
(
    MaNV                INT IDENTITY(1,1)   NOT NULL,
    Ho                  NVARCHAR(50)        NOT NULL,
    TenDem              NVARCHAR(50)        NULL,
    Ten                 NVARCHAR(50)        NOT NULL,
    NgaySinh            DATE                NOT NULL,
    GioiTinh            NVARCHAR(10)        NOT NULL,
    SoNha               NVARCHAR(50)        NOT NULL,
    Duong               NVARCHAR(50)        NOT NULL,
    PhuongXa            NVARCHAR(50)        NOT NULL,
    QuanHuyen           NVARCHAR(50)        NOT NULL,
    TinhThanhPho        NVARCHAR(50)        NOT NULL,
    SoDienThoai         VARCHAR(10)         NOT NULL,
    ChucVu              NVARCHAR(50)        NOT NULL,
    NgayVaoLam          DATE                NOT NULL,
    TinhTrangLamViec    NVARCHAR(50)        NOT NULL CONSTRAINT DF_NhanVien_TinhTrangLamViec DEFAULT N'Đang làm',
    MaTK                INT                 NOT NULL,
    MaNVGiamSat         INT                 NULL,

    CONSTRAINT PK_NhanVien PRIMARY KEY (MaNV),
    CONSTRAINT UQ_NhanVien_MaTK UNIQUE (MaTK),     -- 1 tài khoản chỉ gắn 1 nhân viên (FK 1:1)
    CONSTRAINT FK_NhanVien_TaiKhoan FOREIGN KEY (MaTK) REFERENCES dbo.TAI_KHOAN(MaTK),
    CONSTRAINT FK_NhanVien_GiamSat FOREIGN KEY (MaNVGiamSat) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_NhanVien_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác')),
    CONSTRAINT CK_NhanVien_ChucVu CHECK (ChucVu IN (N'Quản lý', N'Thu ngân', N'Phục vụ', N'Pha chế', N'Thủ kho')),
    CONSTRAINT CK_NhanVien_TinhTrangLamViec CHECK (TinhTrangLamViec IN (N'Đang làm', N'Đã nghỉ')),
    CONSTRAINT CK_NhanVien_SoDienThoai CHECK (SoDienThoai LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_NhanVien_Du18Tuoi CHECK (DATEADD(YEAR, 18, NgaySinh) <= NgayVaoLam),          -- RB3
    CONSTRAINT CK_NhanVien_KhongTuGiamSat CHECK (MaNVGiamSat IS NULL OR MaNVGiamSat <> MaNV)    -- RB3
);
GO

CREATE TABLE dbo.NV_TOAN_THOI_GIAN
(
    MaNV                INT                 NOT NULL,
    LuongCoBanThang     DECIMAL(12,0)       NOT NULL,

    CONSTRAINT PK_NVToanThoiGian PRIMARY KEY (MaNV),
    CONSTRAINT FK_NVToanThoiGian_NhanVien FOREIGN KEY (MaNV) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_NVToanThoiGian_Luong CHECK (LuongCoBanThang > 0)
);
GO

CREATE TABLE dbo.NV_BAN_THOI_GIAN
(
    MaNV                INT                 NOT NULL,
    DonGiaCongGio       DECIMAL(12,0)       NOT NULL,

    CONSTRAINT PK_NVBanThoiGian PRIMARY KEY (MaNV),
    CONSTRAINT FK_NVBanThoiGian_NhanVien FOREIGN KEY (MaNV) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_NVBanThoiGian_DonGia CHECK (DonGiaCongGio > 0)
);
GO

CREATE TABLE dbo.HANG_THANH_VIEN
(
    MaHang              INT IDENTITY(1,1)   NOT NULL,
    TenHang             NVARCHAR(50)        NOT NULL,
    DiemToiThieu        INT                 NOT NULL CONSTRAINT DF_HangThanhVien_DiemToiThieu DEFAULT 0,
    PhanTramGiamGia     DECIMAL(5,2)        NOT NULL CONSTRAINT DF_HangThanhVien_PhanTramGiamGia DEFAULT 0,

    CONSTRAINT PK_HangThanhVien PRIMARY KEY (MaHang),
    CONSTRAINT UQ_HangThanhVien_DiemToiThieu UNIQUE (DiemToiThieu),                          -- RB15
    CONSTRAINT CK_HangThanhVien_DiemToiThieu CHECK (DiemToiThieu >= 0),
    CONSTRAINT CK_HangThanhVien_PhanTramGiamGia CHECK (PhanTramGiamGia BETWEEN 0 AND 100)     -- RB15
);
GO

CREATE TABLE dbo.KHACH_HANG
(
    MaKH                INT IDENTITY(1,1)   NOT NULL,
    Ho                  NVARCHAR(30)        NOT NULL,
    TenDem              NVARCHAR(30)        NULL,
    Ten                 NVARCHAR(30)        NOT NULL,
    NgaySinh            DATE                NULL,
    GioiTinh            NVARCHAR(10)        NULL,

    CONSTRAINT PK_KhachHang PRIMARY KEY (MaKH),
    CONSTRAINT CK_KhachHang_GioiTinh CHECK (GioiTinh IS NULL OR GioiTinh IN (N'Nam', N'Nữ', N'Khác'))
);
GO

CREATE TABLE dbo.KHACH_HANG_SDT
(
    MaKH                INT                 NOT NULL,   -- FK, không phải IDENTITY
    SoDienThoai         VARCHAR(10)         NOT NULL,

    CONSTRAINT PK_KhachHangSDT PRIMARY KEY (MaKH, SoDienThoai),
    CONSTRAINT FK_KhachHangSDT_KhachHang FOREIGN KEY (MaKH)
        REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE,
    CONSTRAINT CK_KhachHangSDT_SoDienThoai CHECK (SoDienThoai LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);
GO

CREATE TABLE dbo.HOI_VIEN
(
    MaKH                INT                 NOT NULL,   -- lớp con của KHACH_HANG: dùng chung mã, không IDENTITY
    NgayDangKy          DATETIME2(0)        NOT NULL CONSTRAINT DF_HoiVien_NgayDangKy DEFAULT SYSDATETIME(),
    DiemTichLuy         INT                 NOT NULL CONSTRAINT DF_HoiVien_DiemTichLuy DEFAULT 0,
    MaHang              INT                 NOT NULL,
    MaTK                INT                 NULL,       -- hội viên đăng ký tại quầy có thể chưa có tài khoản

    CONSTRAINT PK_HoiVien PRIMARY KEY (MaKH),
    CONSTRAINT FK_HoiVien_KhachHang FOREIGN KEY (MaKH)
        REFERENCES dbo.KHACH_HANG(MaKH) ON DELETE CASCADE,
    CONSTRAINT FK_HoiVien_HangThanhVien FOREIGN KEY (MaHang) REFERENCES dbo.HANG_THANH_VIEN(MaHang),
    CONSTRAINT FK_HoiVien_TaiKhoan FOREIGN KEY (MaTK) REFERENCES dbo.TAI_KHOAN(MaTK),
    CONSTRAINT CK_HoiVien_DiemTichLuy CHECK (DiemTichLuy >= 0)
);
GO

-- FK 1:1 cho phép NULL => unique có điều kiện (UNIQUE thường chỉ cho 1 dòng NULL)
CREATE UNIQUE INDEX UQ_HoiVien_MaTK ON dbo.HOI_VIEN(MaTK) WHERE MaTK IS NOT NULL;
GO

CREATE TABLE dbo.KHU_VUC
(
    MaKhuVuc            INT IDENTITY(1,1)   NOT NULL,
    TenKhuVuc           NVARCHAR(50)        NOT NULL,

    CONSTRAINT PK_KhuVuc PRIMARY KEY (MaKhuVuc),
    CONSTRAINT UQ_KhuVuc_Ten UNIQUE (TenKhuVuc),
    CONSTRAINT CK_KhuVuc_Ten CHECK (LEN(LTRIM(RTRIM(TenKhuVuc))) > 0)   -- chặn tên toàn khoảng trắng
);
GO

CREATE TABLE dbo.LOAI_BAN
(
    MaLoaiBan           INT IDENTITY(1,1)   NOT NULL,
    TenLoai             NVARCHAR(50)        NOT NULL,
    MoTa                NVARCHAR(255)       NULL,

    CONSTRAINT PK_LoaiBan PRIMARY KEY (MaLoaiBan),
    CONSTRAINT UQ_LoaiBan_Ten UNIQUE (TenLoai),
    CONSTRAINT CK_LoaiBan_Ten CHECK (LEN(LTRIM(RTRIM(TenLoai))) > 0)
);
GO

CREATE TABLE dbo.KHUNG_GIA
(
    MaLoaiBan           INT                 NOT NULL,
    SoThuTuKhung        INT                 NOT NULL,
    TenKhung            NVARCHAR(50)        NOT NULL,
    LoaiNgayApDung      NVARCHAR(30)        NOT NULL,
    GioBatDau           TIME(0)             NOT NULL,
    GioKetThuc          TIME(0)             NOT NULL,
    DonGiaMoiGio        DECIMAL(18,2)       NOT NULL,

    CONSTRAINT PK_KhungGia PRIMARY KEY (MaLoaiBan, SoThuTuKhung),
    CONSTRAINT FK_KhungGia_LoaiBan FOREIGN KEY (MaLoaiBan) REFERENCES dbo.LOAI_BAN(MaLoaiBan),
    CONSTRAINT CK_KhungGia_SoThuTu CHECK (SoThuTuKhung > 0),
    CONSTRAINT CK_KhungGia_LoaiNgay CHECK (LoaiNgayApDung IN (N'Ngày thường', N'Cuối tuần', N'Ngày lễ')),
    CONSTRAINT CK_KhungGia_Gio CHECK (GioKetThuc > GioBatDau),     -- RB4 (khung qua nửa đêm tách làm 2)
    CONSTRAINT CK_KhungGia_DonGia CHECK (DonGiaMoiGio > 0)         -- RB4
);
GO

CREATE TABLE dbo.BAN
(
    MaBan               INT IDENTITY(1,1)   NOT NULL,
    TenBan              NVARCHAR(50)        NOT NULL,
    SucChuaDeXuat       INT                 NOT NULL,
    TrangThai           NVARCHAR(30)        NOT NULL CONSTRAINT DF_Ban_TrangThai DEFAULT N'Trống',
    MaKhuVuc            INT                 NOT NULL,
    MaLoaiBan           INT                 NOT NULL,

    CONSTRAINT PK_Ban PRIMARY KEY (MaBan),
    CONSTRAINT UQ_Ban_TenBan UNIQUE (TenBan),
    CONSTRAINT FK_Ban_KhuVuc FOREIGN KEY (MaKhuVuc) REFERENCES dbo.KHU_VUC(MaKhuVuc),
    CONSTRAINT FK_Ban_LoaiBan FOREIGN KEY (MaLoaiBan) REFERENCES dbo.LOAI_BAN(MaLoaiBan),
    CONSTRAINT CK_Ban_SucChua CHECK (SucChuaDeXuat > 0),
    CONSTRAINT CK_Ban_TrangThai CHECK (TrangThai IN (N'Trống', N'Đang chơi', N'Đã đặt', N'Đang bảo trì', N'Ngưng sử dụng'))
);
GO

CREATE TABLE dbo.PHIEU_DAT_BAN
(
    MaDatBan            INT IDENTITY(1,1)   NOT NULL,
    ThoiDiemLap         DATETIME2(0)        NOT NULL CONSTRAINT DF_PhieuDatBan_ThoiDiemLap DEFAULT SYSDATETIME(),
    GioBatDauDuKien     DATETIME2(0)        NOT NULL,
    GioKetThucDuKien    DATETIME2(0)        NOT NULL,
    SoNguoi             INT                 NOT NULL,
    KenhTiepNhan        NVARCHAR(30)        NOT NULL,
    TrangThai           NVARCHAR(30)        NOT NULL CONSTRAINT DF_PhieuDatBan_TrangThai DEFAULT N'Chờ xác nhận',
    GhiChu              NVARCHAR(500)       NULL,
    MaKH                INT                 NOT NULL,
    MaNVTiepNhan        INT                 NULL,       -- NULL khi hội viên đặt trên ứng dụng, còn chờ xác nhận

    CONSTRAINT PK_PhieuDatBan PRIMARY KEY (MaDatBan),
    CONSTRAINT FK_PhieuDatBan_KhachHang FOREIGN KEY (MaKH) REFERENCES dbo.KHACH_HANG(MaKH),
    CONSTRAINT FK_PhieuDatBan_NhanVien FOREIGN KEY (MaNVTiepNhan) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_PhieuDatBan_GioDuKien CHECK (GioKetThucDuKien > GioBatDauDuKien),   -- RB5
    CONSTRAINT CK_PhieuDatBan_SoNguoi CHECK (SoNguoi > 0),
    CONSTRAINT CK_PhieuDatBan_Kenh CHECK (KenhTiepNhan IN (N'Tại quầy', N'Điện thoại', N'Mạng xã hội', N'Ứng dụng')),
    CONSTRAINT CK_PhieuDatBan_TrangThai CHECK (TrangThai IN
        (N'Chờ xác nhận', N'Đã xác nhận', N'Đã hủy', N'Không đến', N'Đã chuyển thành phiên'))
);
GO

CREATE TABLE dbo.GIU_BAN
(
    MaDatBan            INT                 NOT NULL,
    MaBan               INT                 NOT NULL,

    CONSTRAINT PK_GiuBan PRIMARY KEY (MaDatBan, MaBan),
    CONSTRAINT FK_GiuBan_PhieuDatBan FOREIGN KEY (MaDatBan) REFERENCES dbo.PHIEU_DAT_BAN(MaDatBan),
    CONSTRAINT FK_GiuBan_Ban FOREIGN KEY (MaBan) REFERENCES dbo.BAN(MaBan)
);
GO

CREATE TABLE dbo.DANH_MUC
(
    MaDanhMuc           INT IDENTITY(1,1)   NOT NULL,
    TenDanhMuc          NVARCHAR(50)        NOT NULL,

    CONSTRAINT PK_DanhMuc PRIMARY KEY (MaDanhMuc),
    CONSTRAINT UQ_DanhMuc_Ten UNIQUE (TenDanhMuc)
);
GO

CREATE TABLE dbo.MAT_HANG
(
    MaMatHang           INT IDENTITY(1,1)   NOT NULL,
    TenMatHang          NVARCHAR(100)       NOT NULL,
    DonViTinh           NVARCHAR(50)        NOT NULL,
    DonGiaNiemYet       DECIMAL(18,2)       NOT NULL,
    TrangThaiKinhDoanh  NVARCHAR(50)        NOT NULL CONSTRAINT DF_MatHang_TrangThai DEFAULT N'Đang bán',
    SoLuongTon          INT                 NOT NULL CONSTRAINT DF_MatHang_SoLuongTon DEFAULT 0,
    MaDanhMuc           INT                 NOT NULL,

    CONSTRAINT PK_MatHang PRIMARY KEY (MaMatHang),
    CONSTRAINT FK_MatHang_DanhMuc FOREIGN KEY (MaDanhMuc) REFERENCES dbo.DANH_MUC(MaDanhMuc),
    CONSTRAINT CK_MatHang_DonGia CHECK (DonGiaNiemYet > 0),
    CONSTRAINT CK_MatHang_TrangThai CHECK (TrangThaiKinhDoanh IN (N'Đang bán', N'Ngừng bán')),
    CONSTRAINT CK_MatHang_SoLuongTon CHECK (SoLuongTon >= 0)       -- RB10
);
GO

CREATE TABLE dbo.PHIEN_CHOI
(
    MaPhien             INT IDENTITY(1,1)   NOT NULL,
    GioBatDau           DATETIME2(0)        NOT NULL CONSTRAINT DF_PhienChoi_GioBatDau DEFAULT SYSDATETIME(),
    GioKetThuc          DATETIME2(0)        NULL,
    TrangThai           NVARCHAR(50)        NOT NULL CONSTRAINT DF_PhienChoi_TrangThai DEFAULT N'Đang chơi',
    GhiChu              NVARCHAR(255)       NULL,
    MaDatBan            INT                 NULL,       -- phiên có thể không xuất phát từ phiếu đặt
    MaNVMoPhien         INT                 NOT NULL,
    MaKH                INT                 NULL,       -- khách vãng lai: NULL
    TongThoiGianChoi    AS DATEDIFF(SECOND, GioBatDau, GioKetThuc) PERSISTED,   -- thuộc tính dẫn xuất (giây)

    CONSTRAINT PK_PhienChoi PRIMARY KEY (MaPhien),
    CONSTRAINT FK_PhienChoi_PhieuDatBan FOREIGN KEY (MaDatBan) REFERENCES dbo.PHIEU_DAT_BAN(MaDatBan),
    CONSTRAINT FK_PhienChoi_NhanVien FOREIGN KEY (MaNVMoPhien) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT FK_PhienChoi_KhachHang FOREIGN KEY (MaKH) REFERENCES dbo.KHACH_HANG(MaKH),
    CONSTRAINT CK_PhienChoi_TrangThai CHECK (TrangThai IN (N'Đang chơi', N'Đã kết thúc', N'Đã thanh toán')),
    CONSTRAINT CK_PhienChoi_ThoiGian CHECK (GioKetThuc IS NULL OR GioKetThuc > GioBatDau),     -- RB7
    CONSTRAINT CK_PhienChoi_KetThucTheoTrangThai CHECK (
           (TrangThai = N'Đang chơi'  AND GioKetThuc IS NULL)
        OR (TrangThai <> N'Đang chơi' AND GioKetThuc IS NOT NULL))
);
GO

-- Một phiếu đặt bàn chuyển thành tối đa một phiên (FK 1:1 cho phép NULL)
CREATE UNIQUE INDEX UQ_PhienChoi_MaDatBan ON dbo.PHIEN_CHOI(MaDatBan) WHERE MaDatBan IS NOT NULL;
GO

CREATE TABLE dbo.DOAN_SU_DUNG_BAN
(
    MaPhien             INT                 NOT NULL,
    SoThuTuDoan         INT                 NOT NULL,
    GioBatDauDung       DATETIME2(0)        NOT NULL,
    GioKetThucDung      DATETIME2(0)        NULL,
    DonGiaApDung        DECIMAL(18,2)       NOT NULL,
    MaBan               INT                 NOT NULL,
    MaLoaiBan           INT                 NOT NULL,
    SoThuTuKhung        INT                 NOT NULL,
    ThoiLuong           AS DATEDIFF(SECOND, GioBatDauDung, GioKetThucDung) PERSISTED,                        -- giây
    TienGio             AS (DATEDIFF(SECOND, GioBatDauDung, GioKetThucDung) * DonGiaApDung / 3600) PERSISTED, -- RB9, chưa làm tròn

    CONSTRAINT PK_DoanSuDungBan PRIMARY KEY (MaPhien, SoThuTuDoan),
    CONSTRAINT FK_DoanSuDungBan_PhienChoi FOREIGN KEY (MaPhien) REFERENCES dbo.PHIEN_CHOI(MaPhien),
    CONSTRAINT FK_DoanSuDungBan_Ban FOREIGN KEY (MaBan) REFERENCES dbo.BAN(MaBan),
    CONSTRAINT FK_DoanSuDungBan_KhungGia FOREIGN KEY (MaLoaiBan, SoThuTuKhung)
        REFERENCES dbo.KHUNG_GIA(MaLoaiBan, SoThuTuKhung),
    CONSTRAINT CK_DoanSuDungBan_SoThuTu CHECK (SoThuTuDoan > 0),
    CONSTRAINT CK_DoanSuDungBan_ThoiGian CHECK (GioKetThucDung IS NULL OR GioKetThucDung > GioBatDauDung),  -- RB7
    CONSTRAINT CK_DoanSuDungBan_DonGia CHECK (DonGiaApDung > 0)
);
GO

CREATE TABLE dbo.DONG_GOI_MON
(
    MaPhien                 INT             NOT NULL,
    SoThuTuDong             INT             NOT NULL,
    ThoiDiemGoi             DATETIME2(0)    NOT NULL CONSTRAINT DF_DongGoiMon_ThoiDiemGoi DEFAULT SYSDATETIME(),
    SoLuong                 INT             NOT NULL,
    DonGiaTaiThoiDiemGoi    DECIMAL(18,2)   NOT NULL,
    TrangThaiPhucVu         NVARCHAR(50)    NOT NULL CONSTRAINT DF_DongGoiMon_TrangThai DEFAULT N'Chờ chế biến',
    GhiChu                  NVARCHAR(255)   NULL,
    MaMatHang               INT             NOT NULL,
    MaNVGhiNhan             INT             NOT NULL,
    ThanhTien               AS (SoLuong * DonGiaTaiThoiDiemGoi) PERSISTED,

    CONSTRAINT PK_DongGoiMon PRIMARY KEY (MaPhien, SoThuTuDong),
    CONSTRAINT FK_DongGoiMon_PhienChoi FOREIGN KEY (MaPhien) REFERENCES dbo.PHIEN_CHOI(MaPhien),
    CONSTRAINT FK_DongGoiMon_MatHang FOREIGN KEY (MaMatHang) REFERENCES dbo.MAT_HANG(MaMatHang),
    CONSTRAINT FK_DongGoiMon_NhanVien FOREIGN KEY (MaNVGhiNhan) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_DongGoiMon_SoThuTu CHECK (SoThuTuDong > 0),
    CONSTRAINT CK_DongGoiMon_SoLuong CHECK (SoLuong > 0),          -- RB10
    CONSTRAINT CK_DongGoiMon_DonGia CHECK (DonGiaTaiThoiDiemGoi > 0),
    CONSTRAINT CK_DongGoiMon_TrangThai CHECK (TrangThaiPhucVu IN (N'Chờ chế biến', N'Đã phục vụ', N'Đã hủy'))
);
GO

CREATE TABLE dbo.NHA_CUNG_CAP
(
    MaNCC               INT IDENTITY(1,1)   NOT NULL,
    TenNhaCungCap       NVARCHAR(150)       NOT NULL,
    DiaChi              NVARCHAR(255)       NULL,
    SoDienThoai         NVARCHAR(20)        NULL,
    Email               NVARCHAR(254)       NULL,

    CONSTRAINT PK_NhaCungCap PRIMARY KEY (MaNCC),
    CONSTRAINT CK_NhaCungCap_Ten CHECK (LEN(LTRIM(RTRIM(TenNhaCungCap))) > 0),
    CONSTRAINT CK_NhaCungCap_Email CHECK (Email IS NULL OR (Email LIKE N'_%@_%._%' AND Email NOT LIKE N'% %'
        AND LEN(Email) - LEN(REPLACE(Email, N'@', N'')) = 1))
);
GO

CREATE TABLE dbo.KHUYEN_MAI
(
    MaKM                INT IDENTITY(1,1)   NOT NULL,
    TenChuongTrinh      NVARCHAR(150)       NOT NULL,
    HinhThucGiam        NVARCHAR(30)        NOT NULL,
    GiaTriGiam          DECIMAL(18,2)       NOT NULL,
    NgayBatDau          DATE                NOT NULL,
    NgayKetThuc         DATE                NOT NULL,

    CONSTRAINT PK_KhuyenMai PRIMARY KEY (MaKM),
    CONSTRAINT CK_KhuyenMai_Ten CHECK (LEN(LTRIM(RTRIM(TenChuongTrinh))) > 0),
    CONSTRAINT CK_KhuyenMai_HinhThuc CHECK (HinhThucGiam IN (N'Phần trăm', N'Số tiền')),
    CONSTRAINT CK_KhuyenMai_GiaTri CHECK (GiaTriGiam >= 0
        AND (HinhThucGiam <> N'Phần trăm' OR GiaTriGiam <= 100)),     -- RB13
    CONSTRAINT CK_KhuyenMai_Ngay CHECK (NgayKetThuc >= NgayBatDau)    -- RB13
);
GO

CREATE TABLE dbo.PHIEU_NHAP
(
    MaPhieuNhap         INT IDENTITY(1,1)   NOT NULL,
    NgayNhap            DATE                NOT NULL,
    GhiChu              NVARCHAR(500)       NULL,
    MaNCC               INT                 NOT NULL,
    MaNVLap             INT                 NOT NULL,
    TongTien            DECIMAL(18,2)       NOT NULL CONSTRAINT DF_PhieuNhap_TongTien DEFAULT 0,   -- trigger cập nhật

    CONSTRAINT PK_PhieuNhap PRIMARY KEY (MaPhieuNhap),
    CONSTRAINT FK_PhieuNhap_NhaCungCap FOREIGN KEY (MaNCC) REFERENCES dbo.NHA_CUNG_CAP(MaNCC),
    CONSTRAINT FK_PhieuNhap_NhanVien FOREIGN KEY (MaNVLap) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_PhieuNhap_TongTien CHECK (TongTien >= 0),
    CONSTRAINT CK_PhieuNhap_NgayNhap CHECK (NgayNhap <= CAST(GETDATE() AS DATE))   -- RB11
);
GO

CREATE TABLE dbo.CHI_TIET_NHAP
(
    MaPhieuNhap         INT                 NOT NULL,
    MaMatHang           INT                 NOT NULL,
    SoLuongNhap         INT                 NOT NULL,
    DonGiaNhap          DECIMAL(18,2)       NOT NULL,

    CONSTRAINT PK_ChiTietNhap PRIMARY KEY (MaPhieuNhap, MaMatHang),
    CONSTRAINT FK_ChiTietNhap_PhieuNhap FOREIGN KEY (MaPhieuNhap) REFERENCES dbo.PHIEU_NHAP(MaPhieuNhap),
    CONSTRAINT FK_ChiTietNhap_MatHang FOREIGN KEY (MaMatHang) REFERENCES dbo.MAT_HANG(MaMatHang),
    CONSTRAINT CK_ChiTietNhap_SoLuong CHECK (SoLuongNhap > 0),     -- RB11
    CONSTRAINT CK_ChiTietNhap_DonGia CHECK (DonGiaNhap > 0)        -- RB11
);
GO

CREATE TABLE dbo.HOA_DON
(
    MaHoaDon            INT IDENTITY(1,1)   NOT NULL,
    ThoiDiemLap         DATETIME2(0)        NOT NULL CONSTRAINT DF_HoaDon_ThoiDiemLap DEFAULT SYSDATETIME(),
    TienGioChoi         DECIMAL(18,2)       NOT NULL CONSTRAINT DF_HoaDon_TienGioChoi DEFAULT 0,
    TienMon             DECIMAL(18,2)       NOT NULL CONSTRAINT DF_HoaDon_TienMon DEFAULT 0,
    TienGiam            DECIMAL(18,2)       NOT NULL CONSTRAINT DF_HoaDon_TienGiam DEFAULT 0,
    TongPhaiTra         DECIMAL(18,2)       NOT NULL CONSTRAINT DF_HoaDon_TongPhaiTra DEFAULT 0,
    DiemCong            INT                 NOT NULL CONSTRAINT DF_HoaDon_DiemCong DEFAULT 0,
    TrangThaiThanhToan  NVARCHAR(30)        NOT NULL CONSTRAINT DF_HoaDon_TrangThai DEFAULT N'Chưa thanh toán',
    MaPhien             INT                 NOT NULL,
    MaNVLap             INT                 NOT NULL,
    MaKM                INT                 NULL,

    CONSTRAINT PK_HoaDon PRIMARY KEY (MaHoaDon),
    CONSTRAINT UQ_HoaDon_MaPhien UNIQUE (MaPhien),                 -- mỗi phiên tối đa 1 hóa đơn (FK 1:1)
    CONSTRAINT FK_HoaDon_PhienChoi FOREIGN KEY (MaPhien) REFERENCES dbo.PHIEN_CHOI(MaPhien),
    CONSTRAINT FK_HoaDon_NhanVien FOREIGN KEY (MaNVLap) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT FK_HoaDon_KhuyenMai FOREIGN KEY (MaKM) REFERENCES dbo.KHUYEN_MAI(MaKM),
    CONSTRAINT CK_HoaDon_DiemCong CHECK (DiemCong >= 0),
    CONSTRAINT CK_HoaDon_TrangThai CHECK (TrangThaiThanhToan IN (N'Chưa thanh toán', N'Thanh toán một phần', N'Đã thanh toán')),
    CONSTRAINT CK_HoaDon_Tien CHECK (TienGioChoi >= 0 AND TienMon >= 0 AND TienGiam >= 0
        AND TienGiam <= TienGioChoi + TienMon),                                        -- RB13
    CONSTRAINT CK_HoaDon_TongPhaiTra CHECK (TongPhaiTra = TienGioChoi + TienMon - TienGiam),
    CONSTRAINT CK_HoaDon_LamTronDong CHECK (TienGioChoi = ROUND(TienGioChoi, 0) AND TienMon = ROUND(TienMon, 0)
        AND TienGiam = ROUND(TienGiam, 0))                                              -- RB9
);
GO

CREATE TABLE dbo.GIAO_DICH_THANH_TOAN
(
    MaGD                INT IDENTITY(1,1)   NOT NULL,
    ThoiDiemThanhToan   DATETIME2(0)        NOT NULL CONSTRAINT DF_GiaoDich_ThoiDiem DEFAULT SYSDATETIME(),
    SoTien              DECIMAL(18,2)       NOT NULL,
    PhuongThuc          NVARCHAR(30)        NOT NULL,
    MaThamChieu         NVARCHAR(100)       NULL,
    TrangThai           NVARCHAR(30)        NOT NULL,
    MaHoaDon            INT                 NOT NULL,
    MaNVXacNhan         INT                 NOT NULL,

    CONSTRAINT PK_GiaoDich PRIMARY KEY (MaGD),
    CONSTRAINT FK_GiaoDich_HoaDon FOREIGN KEY (MaHoaDon) REFERENCES dbo.HOA_DON(MaHoaDon),
    CONSTRAINT FK_GiaoDich_NhanVien FOREIGN KEY (MaNVXacNhan) REFERENCES dbo.NHAN_VIEN(MaNV),
    CONSTRAINT CK_GiaoDich_SoTien CHECK (SoTien > 0),              -- RB14
    CONSTRAINT CK_GiaoDich_PhuongThuc CHECK (PhuongThuc IN (N'Tiền mặt', N'Chuyển khoản/QR', N'Ví điện tử')),
    CONSTRAINT CK_GiaoDich_TrangThai CHECK (TrangThai IN (N'Thành công', N'Thất bại'))
);
GO
