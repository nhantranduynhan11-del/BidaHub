-- ============================================================================
-- sql/03_trigger/khang.sql - RB11, RB12, RB13, RB14

USE BidaHub;
GO

-- ============================================================================
--  RB13: TACH KHOAN GIAM THEO HANG VA KHUYEN MAI
-- Chi them cot neu chua ton tai. Khong thay doi TongPhaiTra/TienGiam cu.
-- ============================================================================
IF COL_LENGTH(N'dbo.HOA_DON', N'TienGiamTheoHang') IS NULL
BEGIN
    ALTER TABLE dbo.HOA_DON
    ADD TienGiamTheoHang DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_RB13_HoaDon_TienGiamTheoHang DEFAULT (0) WITH VALUES;
END;
GO
IF COL_LENGTH(N'dbo.HOA_DON', N'TienGiamKhuyenMai') IS NULL
BEGIN
    ALTER TABLE dbo.HOA_DON
    ADD TienGiamKhuyenMai DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_RB13_HoaDon_TienGiamKhuyenMai DEFAULT (0) WITH VALUES;
END;
GO

UPDATE hd
SET TienGiamTheoHang = CASE WHEN hd.MaKM IS NULL THEN hd.TienGiam ELSE 0 END,
    TienGiamKhuyenMai = CASE WHEN hd.MaKM IS NOT NULL THEN hd.TienGiam ELSE 0 END
FROM dbo.HOA_DON AS hd
WHERE hd.TienGiam > 0
  AND hd.TienGiamTheoHang = 0
  AND hd.TienGiamKhuyenMai = 0;
GO

-- CHECK: gia tri KM hop le (theo phan tram hoac so tien).
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_RB13_KM_ThoiHan'
               AND parent_object_id = OBJECT_ID(N'dbo.KHUYEN_MAI'))
    ALTER TABLE dbo.KHUYEN_MAI WITH CHECK
    ADD CONSTRAINT CK_RB13_KM_ThoiHan CHECK (
        NgayBatDau IS NOT NULL AND NgayKetThuc IS NOT NULL
        AND NgayKetThuc >= NgayBatDau
    );
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_RB13_KM_GiaTri'
               AND parent_object_id = OBJECT_ID(N'dbo.KHUYEN_MAI'))
    ALTER TABLE dbo.KHUYEN_MAI WITH CHECK
    ADD CONSTRAINT CK_RB13_KM_GiaTri CHECK (
        (HinhThucGiam = N'Phần trăm' AND GiaTriGiam IS NOT NULL AND GiaTriGiam BETWEEN 0 AND 100)
        OR
        (HinhThucGiam = N'Số tiền' AND GiaTriGiam IS NOT NULL AND GiaTriGiam >= 0)
    );
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_RB13_Hang_PhanTram'
               AND parent_object_id = OBJECT_ID(N'dbo.HANG_THANH_VIEN'))
    ALTER TABLE dbo.HANG_THANH_VIEN WITH CHECK
    ADD CONSTRAINT CK_RB13_Hang_PhanTram CHECK (
        PhanTramGiamGia IS NOT NULL AND PhanTramGiamGia BETWEEN 0 AND 100
    );
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_RB13_HD_PhanBoGiam'
               AND parent_object_id = OBJECT_ID(N'dbo.HOA_DON'))
    ALTER TABLE dbo.HOA_DON WITH CHECK
    ADD CONSTRAINT CK_RB13_HD_PhanBoGiam CHECK (
        TienGioChoi IS NOT NULL AND TienMon IS NOT NULL AND TienGiam IS NOT NULL
        AND TienGioChoi >= 0 AND TienMon >= 0
        AND TienGiamTheoHang >= 0 AND TienGiamKhuyenMai >= 0
        AND TienGiam = TienGiamTheoHang + TienGiamKhuyenMai
        AND TienGiam <= TienGioChoi + TienMon
    );
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_RB14_GD_SoTienDuong'
               AND parent_object_id = OBJECT_ID(N'dbo.GIAO_DICH_THANH_TOAN'))
    ALTER TABLE dbo.GIAO_DICH_THANH_TOAN WITH CHECK
    ADD CONSTRAINT CK_RB14_GD_SoTienDuong CHECK (SoTien IS NOT NULL AND SoTien > 0);
GO

-- RB11.1: KIỂM TRA PHIẾU NHẬP
-- Điều kiện:
--    1. NgayNhap không được sau ngày hiện tại.
--    2. MaNVLap phải là nhân viên có chức vụ:
--       - 'Thủ kho'
--       - 'Quản lý'

-- Mã lỗi:
--    50511: Ngày nhập không hợp lệ.
--    50512: Nhân viên không có quyền lập phiếu.

CREATE OR ALTER TRIGGER dbo.trg_RB11_KiemTraPhieuNhap
ON dbo.PHIEU_NHAP
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Kiểm tra ngày nhập không ở tương lai
    IF EXISTS (SELECT 1 FROM inserted AS i WHERE CAST(i.NgayNhap AS DATE) > CAST(GETDATE() AS DATE))
    BEGIN
        THROW 50511,
              N'RB11: NgayNhap không được sau ngày hiện tại.', 1;
    END;
    -- 2. Kiểm tra chức vụ nhân viên lập phiếu
    IF EXISTS (SELECT 1 FROM inserted AS i LEFT JOIN dbo.NHAN_VIEN AS nv ON i.MaNVLap = nv.MaNV
        WHERE nv.MaNV IS NULL OR nv.ChucVu IS NULL OR nv.ChucVu NOT IN (N'Thủ kho', N'Quản lý'))
    BEGIN
        THROW 50512,
              N'RB11: MaNVLap phải là Thủ kho hoặc Quản lý.', 1;
    END;
END;
GO

-- RB11.2: TÍNH LẠI TỔNG TIỀN PHIẾU NHẬP
-- Công thức:
--    PHIEU_NHAP.TongTien = SUM(CHI_TIET_NHAP.SoLuongNhap * DonGiaNhap)
-- Khi chi tiết thay đổi, chỉ tính lại các phiếu bị ảnh hưởng.
CREATE OR ALTER TRIGGER dbo.trg_RB11_TinhTongTienNhap
ON dbo.CHI_TIET_NHAP
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH PhieuBiAnhHuong AS (
        SELECT MaPhieuNhap FROM inserted
        UNION
        SELECT MaPhieuNhap FROM deleted
    ),
    TongTienMoi AS (
        SELECT p.MaPhieuNhap, COALESCE( SUM( CAST(ct.SoLuongNhap AS DECIMAL(18,2)) * ct.DonGiaNhap), 0) AS TongTien
        FROM PhieuBiAnhHuong AS p
        LEFT JOIN dbo.CHI_TIET_NHAP AS ct ON p.MaPhieuNhap = ct.MaPhieuNhap GROUP BY p.MaPhieuNhap)
    UPDATE pn
    SET pn.TongTien = t.TongTien FROM dbo.PHIEU_NHAP AS pn INNER JOIN TongTienMoi AS t ON pn.MaPhieuNhap = t.MaPhieuNhap;
END;
GO

-- RB11.3: CẬP NHẬT SỐ LƯỢNG TỒN KHO KHI NHẬP HÀNG
-- Mã lỗi:
--    50513: Thao tác làm tồn kho không hợp lệ

CREATE OR ALTER TRIGGER dbo.trg_RB11_CapNhatTonKho
ON dbo.CHI_TIET_NHAP
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1 số lượng biến động của từng mặt hàng
    DECLARE @BienDong TABLE (MaMatHang INT PRIMARY KEY, SoLuongChenhLech BIGINT NOT NULL);

    INSERT INTO @BienDong (MaMatHang, SoLuongChenhLech)
    SELECT x.MaMatHang, SUM(x.ChenhLech)
    FROM (
        -- cộng số lượng
        SELECT MaMatHang, CAST(SoLuongNhap AS BIGINT) AS ChenhLech
        FROM inserted UNION ALL
        -- trừ số lượng cũ
        SELECT MaMatHang, -CAST(SoLuongNhap AS BIGINT) AS ChenhLech
        FROM deleted
    ) AS x GROUP BY x.MaMatHang HAVING SUM(x.ChenhLech) <> 0;

    -- 2 Kiểm tra tồn kho sau thay đổi
    IF EXISTS (SELECT 1 FROM dbo.MAT_HANG AS mh WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN @BienDong AS bd ON mh.MaMatHang = bd.MaMatHang
        WHERE mh.SoLuongTon IS NULL
           OR CAST(mh.SoLuongTon AS BIGINT) + bd.SoLuongChenhLech < 0
           OR CAST(mh.SoLuongTon AS BIGINT) + bd.SoLuongChenhLech > 2147483647
    )
    BEGIN
        THROW 50513,
              N'RB11: Thao tác nhập hàng làm SoLuongTon không hợp lệ.',1;
    END;
    -- 3 Cập nhật tồn kho theo số lượng chênh lệch
    UPDATE mh
    SET mh.SoLuongTon = mh.SoLuongTon + bd.SoLuongChenhLech FROM dbo.MAT_HANG AS mh
    INNER JOIN @BienDong AS bd ON mh.MaMatHang = bd.MaMatHang;
END;
GO
-- RB11.4: NGAN SUA TRUC TIEP TongTien CUA PHIEU NHAP
-- Ma loi 50514.
CREATE OR ALTER TRIGGER dbo.trg_RB11_BaoVeTongTienNhap
ON dbo.PHIEU_NHAP
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        OUTER APPLY (
            SELECT COALESCE(SUM(CAST(ct.SoLuongNhap AS DECIMAL(18,2)) * ct.DonGiaNhap), 0) AS TongTinhLai
            FROM dbo.CHI_TIET_NHAP AS ct
            WHERE ct.MaPhieuNhap = i.MaPhieuNhap
        ) AS t
        WHERE i.TongTien IS NULL OR i.TongTien <> t.TongTinhLai
    )
    BEGIN
        THROW 50514,
              N'RB11: TongTien phieu nhap phai bang tong (SoLuongNhap * DonGiaNhap).', 1;
    END;
END;
GO

-- RB12.1: KIỂM TRA ĐIỀU KIỆN LẬP HÓA ĐƠN
-- Điều kiện:
--     Phiên chơi phải có GioKetThuc
--     Phiên ở trạng thái 'Đã kết thúc' hoặc 'Đã thanh toán'
--     Phiên phải có ít nhất một đoạn sử dụng bàn
--     Tất cả các đoạn sử dụng bàn phải có GioKetThucDung
--     Nhân viên lập hóa đơn phải là Thu ngân hoặc Quản lý
--
-- Mã lỗi:
--    50521: Phiên chơi chưa đủ điều kiện lập hóa đơn
--    50522: Nhân viên không có quyền lập hóa đơn
CREATE OR ALTER TRIGGER dbo.trg_RB12_KiemTraHoaDon
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Kiểm tra trạng thái và thời điểm kết thúc phiên
    IF EXISTS (SELECT 1 FROM inserted AS i LEFT JOIN dbo.PHIEN_CHOI AS p ON i.MaPhien = p.MaPhien
        WHERE p.MaPhien IS NULL OR p.GioKetThuc IS NULL OR p.TrangThai IS NULL OR p.TrangThai NOT IN (N'Đã kết thúc', N'Đã thanh toán'))
    BEGIN
        THROW 50521, N'RB12: MaPhien chưa kết thúc, không thể lập hóa đơn.', 1;
    END;

    --  Kiểm tra phiên phải có đoạn sử dụng bàn và tất cả đoạn đều đã đóng
    IF EXISTS ( SELECT 1 FROM inserted AS i WHERE NOT EXISTS ( SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = i.MaPhien)
        OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = i.MaPhien AND d.GioKetThucDung IS NULL))
    BEGIN
        THROW 50521, N'RB12: MaPhien còn đoạn sử dụng bàn chưa đóng hoặc chưa có đoạn nào.', 1;
    END;

    -- Kiểm tra chức vụ nhân viên lập hóa đơn
    IF EXISTS (SELECT 1 FROM inserted AS i LEFT JOIN dbo.NHAN_VIEN AS nv ON i.MaNVLap = nv.MaNV
        WHERE nv.MaNV IS NULL OR nv.ChucVu IS NULL OR nv.ChucVu NOT IN (N'Thu ngân', N'Quản lý'))
    BEGIN
        THROW 50522, N'RB12: MaNVLap phải có chức vụ Thu ngân hoặc Quản lý.', 1;
    END;
END;
GO
-- RB12.2: KHÔNG CHO THÊM ĐOẠN SỬ DỤNG BÀN SAU KHI LẬP HÓA ĐƠN
-- Mã lỗi:
--    50523: Phiên đã lập hóa đơn
CREATE OR ALTER TRIGGER dbo.trg_RB12_ChanThemDoan
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS i INNER JOIN dbo.HOA_DON AS hd ON i.MaPhien = hd.MaPhien)
    BEGIN
        THROW 50523, N'RB12: MaPhien đã có hóa đơn, không được thêm đoạn sử dụng bàn.',1;
    END;
END;
GO
-- RB12.3: KHÔNG CHO THÊM DÒNG GỌI MÓN SAU KHI LẬP HÓA ĐƠN
-- Mã lỗi:
--    50524: Phiên đã có hóa đơn
CREATE OR ALTER TRIGGER dbo.trg_RB12_ChanThemMon
ON dbo.DONG_GOI_MON
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS i INNER JOIN dbo.HOA_DON AS hd ON i.MaPhien = hd.MaPhien)
    BEGIN
        THROW 50524, N'RB12: MaPhien đã có hóa đơn, không được thêm dòng gọi món.', 1;
    END;
END;
GO
-- RB12.4 - RB12.5: KIỂM TRA TIỀN GIỜ CHƠI VÀ TIỀN MÓN
-- Mã lỗi:
--    50525: Tiền giờ chơi không khớp tổng tiền các đoạn
--    50526: Tiền món không khớp tổng tiền gọi món chưa hủy

CREATE OR ALTER TRIGGER dbo.trg_RB12_KiemTraTienHoaDon
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Kiểm tra tiền giờ chơi
    IF EXISTS (SELECT 1 FROM inserted AS i OUTER APPLY (
            SELECT CAST(ROUND(COALESCE(SUM(d.TienGio), 0), 0) AS DECIMAL(18,2)) AS TongTienGio
            FROM dbo.DOAN_SU_DUNG_BAN AS d
            WHERE d.MaPhien = i.MaPhien
        ) AS tg
        WHERE i.TienGioChoi IS NULL
           OR i.TienGioChoi <> tg.TongTienGio
    )
    BEGIN
        THROW 50525,
              N'RB12: TienGioChoi không khớp tổng tiền giờ đã làm tròn.',
              1;
    END;

    -- 2. Kiểm tra tiền món
    IF EXISTS (SELECT 1 FROM inserted AS i
        OUTER APPLY (SELECT COALESCE(SUM(gm.ThanhTien), 0) AS TongTienMon
            FROM dbo.DONG_GOI_MON AS gm
            WHERE gm.MaPhien = i.MaPhien
              AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy')) AS tm
        WHERE i.TienMon IS NULL
           OR i.TienMon <> tm.TongTienMon
    )
    BEGIN
        THROW 50526,
              N'RB12: TienMon không khớp tổng tiền các món chưa hủy.',
              1;
    END;
END;
GO
-- RB12.5: KHONG DUOC SUA/XOA DU LIEU TIEN GIO KHI DA LAP HOA DON
-- Chi xu ly hoa don CHUA thanh toan; RB14.3 xu ly hoa don da thanh toan.
-- Ma loi 50527.
CREATE OR ALTER TRIGGER dbo.trg_RB12_KhoaTienGioKhiDaLapHD
ON dbo.DOAN_SU_DUNG_BAN
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted AS d
        LEFT JOIN inserted AS i
          ON i.MaPhien = d.MaPhien AND i.SoThuTuDoan = d.SoThuTuDoan
        JOIN dbo.HOA_DON AS hd ON hd.MaPhien = d.MaPhien
        WHERE (hd.TrangThaiThanhToan IS NULL OR hd.TrangThaiThanhToan <> N'Đã thanh toán')
          AND (
              i.MaPhien IS NULL OR EXISTS (
                  SELECT d.TienGio, d.ThoiLuong, d.DonGiaApDung,
                         d.GioBatDauDung, d.GioKetThucDung, d.MaBan,
                         d.MaLoaiBan, d.SoThuTuKhung
                  EXCEPT
                  SELECT i.TienGio, i.ThoiLuong, i.DonGiaApDung,
                         i.GioBatDauDung, i.GioKetThucDung, i.MaBan,
                         i.MaLoaiBan, i.SoThuTuKhung
              )
          )
    )
    OR EXISTS (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS d
          ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
        JOIN dbo.HOA_DON AS hd ON hd.MaPhien = i.MaPhien
        WHERE (hd.TrangThaiThanhToan IS NULL OR hd.TrangThaiThanhToan <> N'Đã thanh toán')
          AND d.MaPhien IS NULL
    )
    BEGIN
        THROW 50527,
              N'RB12: Phien da lap hoa don, khong duoc sua/xoa du lieu tinh tien gio.', 1;
    END;
END;
GO

-- RB12.6: KHONG DUOC SUA/XOA DU LIEU TIEN MON KHI DA LAP HOA DON
-- Cho phep doi trang thai phuc vu NEU khong thay doi trang thai 'Da huy'.
-- Chi xu ly hoa don chua thanh toan; RB14.4 xu ly hoa don da thanh toan.
-- Ma loi 50528.
CREATE OR ALTER TRIGGER dbo.trg_RB12_KhoaTienMonKhiDaLapHD
ON dbo.DONG_GOI_MON
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted AS d
        LEFT JOIN inserted AS i
          ON i.MaPhien = d.MaPhien AND i.SoThuTuDong = d.SoThuTuDong
        JOIN dbo.HOA_DON AS hd ON hd.MaPhien = d.MaPhien
        WHERE (hd.TrangThaiThanhToan IS NULL OR hd.TrangThaiThanhToan <> N'Đã thanh toán')
          AND (
              i.MaPhien IS NULL OR EXISTS (
                  SELECT d.SoLuong, d.DonGiaTaiThoiDiemGoi, d.ThanhTien,
                         d.MaMatHang,
                         CASE WHEN d.TrangThaiPhucVu = N'Đã hủy' THEN 1 ELSE 0 END
                  EXCEPT
                  SELECT i.SoLuong, i.DonGiaTaiThoiDiemGoi, i.ThanhTien,
                         i.MaMatHang,
                         CASE WHEN i.TrangThaiPhucVu = N'Đã hủy' THEN 1 ELSE 0 END
              )
          )
    )
    OR EXISTS (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS d
          ON d.MaPhien = i.MaPhien AND d.SoThuTuDong = i.SoThuTuDong
        JOIN dbo.HOA_DON AS hd ON hd.MaPhien = i.MaPhien
        WHERE (hd.TrangThaiThanhToan IS NULL OR hd.TrangThaiThanhToan <> N'Đã thanh toán')
          AND d.MaPhien IS NULL
    )
    BEGIN
        THROW 50528,
              N'RB12: Phien da lap hoa don, khong duoc sua/xoa du lieu tinh tien mon.', 1;
    END;
END;
GO

-- RB13.1: KIỂM TRA THỜI HẠN ÁP DỤNG KHUYẾN MÃI
CREATE OR ALTER TRIGGER dbo.trg_RB13_KiemTraKhuyenMai
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS i LEFT JOIN dbo.KHUYEN_MAI AS km ON i.MaKM = km.MaKM
        WHERE i.MaKM IS NOT NULL
          AND (km.MaKM IS NULL 
          OR i.ThoiDiemLap IS NULL 
          OR CAST(i.ThoiDiemLap AS DATE) < km.NgayBatDau 
          OR CAST(i.ThoiDiemLap AS DATE) > km.NgayKetThuc
          )
    )
    BEGIN
        THROW 50531,
              N'RB13: MaKM không có hiệu lực tại ThoiDiemLap của hóa đơn.',
              1;
    END;
END;
GO

-- RB13.2: BẢO VỆ THỜI HẠN KHUYẾN MÃI ĐÃ ÁP DỤNG
CREATE OR ALTER TRIGGER dbo.trg_RB13_BaoVeThoiHanKhuyenMai
ON dbo.KHUYEN_MAI
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted AS km INNER JOIN dbo.HOA_DON AS hd ON hd.MaKM = km.MaKM
        WHERE hd.ThoiDiemLap IS NULL
           OR CAST(hd.ThoiDiemLap AS DATE) < km.NgayBatDau
           OR CAST(hd.ThoiDiemLap AS DATE) > km.NgayKetThuc
    )
    BEGIN
        THROW 50532,
              N'RB13: Thời hạn MaKM mới không hợp lệ với hóa đơn đã áp dụng.',
              1;
    END;
END;
GO
-- RB13.3: PHAN DINH KHOAN GIAM THEO HANG VA THEO KHUYEN MAI
-- TienGiam = TienGiamTheoHang + TienGiamKhuyenMai
-- * Giam theo hang: chi hoi vien; tinh chinh xac % tren TienGioChoi
-- * Giam KM: phai co MaKM; thoi han kiem tra o RB13.1
-- * Co the ap dung hai loai dong thoi; tong giam khong vuot tien gio + mon
-- Ma loi: 50533, 50534, 50535.
CREATE OR ALTER TRIGGER dbo.trg_RB13_GiamTheoHang
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Khong co hoi vien hop le ma van ghi giam theo hang
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = i.MaPhien
        LEFT JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = p.MaKH
        LEFT JOIN dbo.HANG_THANH_VIEN AS h ON h.MaHang = hv.MaHang
        WHERE i.TienGiamTheoHang > 0
          AND (hv.MaKH IS NULL OR h.MaHang IS NULL
               OR hv.NgayDangKy IS NULL OR hv.NgayDangKy > i.ThoiDiemLap)
    )
    BEGIN
        THROW 50533,
              N'RB13: Chi hoi vien hop le moi duoc giam theo hang.', 1;
    END;

    -- Khong duoc giam theo hang tren TienMon
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = i.MaPhien
        JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = p.MaKH
        JOIN dbo.HANG_THANH_VIEN AS h ON h.MaHang = hv.MaHang
        WHERE i.TienGiamTheoHang > 0
          AND (
              h.PhanTramGiamGia IS NULL
              OR i.TienGiamTheoHang <>
                  CAST(ROUND(i.TienGioChoi * h.PhanTramGiamGia / 100.0, 0) AS DECIMAL(18,2))
          )
    )
    BEGIN
        THROW 50534,
              N'RB13: TienGiamTheoHang phai tinh theo % cua TienGioChoi.', 1;
    END;

    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE TienGiamKhuyenMai > 0 AND MaKM IS NULL
    )
    BEGIN
        THROW 50535,
              N'RB13: Co TienGiamKhuyenMai thi phai gan MaKM.', 1;
    END;
END;
GO

-- RB14.1: KIEM TRA VA CAP NHAT THANH TOAN
CREATE OR ALTER TRIGGER dbo.trg_RB14_KiemTraThanhToan
ON dbo.GIAO_DICH_THANH_TOAN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- Khong thay doi giao dich cua hoa don da thanh toan
    IF EXISTS (SELECT 1
        FROM deleted AS d JOIN dbo.HOA_DON AS hd ON d.MaHoaDon = hd.MaHoaDon
        WHERE hd.TrangThaiThanhToan = N'Đã thanh toán')
    OR EXISTS (SELECT 1 FROM inserted AS i JOIN dbo.HOA_DON AS hd ON i.MaHoaDon = hd.MaHoaDon
        WHERE hd.TrangThaiThanhToan = N'Đã thanh toán')
    BEGIN
        THROW 50542,
              N'RB14: Hóa đơn đã thanh toán, không được thêm, sửa hoặc xóa giao dịch.', 1;
    END;

    -- Xac dinh cac hoa don bi anh huong
    DECLARE @HoaDonBiAnhHuong TABLE (MaHoaDon INT PRIMARY KEY);
    INSERT INTO @HoaDonBiAnhHuong (MaHoaDon)
    SELECT MaHoaDon FROM inserted
    UNION
    SELECT MaHoaDon FROM deleted;
    -- Kiem tra tong giao dich thanh cong khong vuot tong phai tra
    IF EXISTS (SELECT 1
        FROM dbo.HOA_DON AS hd WITH (UPDLOCK, HOLDLOCK) JOIN @HoaDonBiAnhHuong AS a ON hd.MaHoaDon = a.MaHoaDon
        OUTER APPLY (SELECT COALESCE(SUM(gd.SoTien), 0) AS DaTra FROM dbo.GIAO_DICH_THANH_TOAN AS gd WHERE gd.MaHoaDon = hd.MaHoaDon
              AND gd.TrangThai = N'Thành công') AS tt WHERE tt.DaTra > hd.TongPhaiTra)
    BEGIN
        THROW 50541,
              N'RB14: Tổng giao dịch thành công vượt TongPhaiTra.', 1;
    END;
    -- Tu dong cap nhat trang thai hoa don
    UPDATE hd
    SET hd.TrangThaiThanhToan = CASE WHEN tt.DaTra = hd.TongPhaiTra THEN N'Đã thanh toán'
            WHEN tt.DaTra > 0 THEN N'Thanh toán một phần' ELSE N'Chưa thanh toán'
        END
    FROM dbo.HOA_DON AS hd JOIN @HoaDonBiAnhHuong AS a ON hd.MaHoaDon = a.MaHoaDon
    OUTER APPLY (SELECT COALESCE(SUM(gd.SoTien), 0) AS DaTra FROM dbo.GIAO_DICH_THANH_TOAN AS gd
        WHERE gd.MaHoaDon = hd.MaHoaDon AND gd.TrangThai = N'Thành công') AS tt;
    -- Khi hoa don thanh toan du, cap nhat phien choi
    UPDATE p
    SET p.TrangThai = N'Đã thanh toán' FROM dbo.PHIEN_CHOI AS p JOIN dbo.HOA_DON AS hd
        ON hd.MaPhien = p.MaPhien JOIN @HoaDonBiAnhHuong AS a
        ON a.MaHoaDon = hd.MaHoaDon
    WHERE hd.TrangThaiThanhToan = N'Đã thanh toán'
      AND (p.TrangThai IS NULL OR p.TrangThai <> N'Đã thanh toán');
END;
GO
-- RB14.2: KHONG DUOC SUA/XOA HOA DON DA THANH TOAN
-- Bao ve ca hai cot giam moi, khong chi cot tong TienGiam
-- Ma loi 50543, 50544.
CREATE OR ALTER TRIGGER dbo.trg_RB14_BaoVeHoaDon
ON dbo.HOA_DON
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted AS d
        LEFT JOIN inserted AS i ON i.MaHoaDon = d.MaHoaDon
        WHERE d.TrangThaiThanhToan = N'Đã thanh toán'
          AND (
              i.MaHoaDon IS NULL
              OR EXISTS (
                  SELECT d.TienGioChoi, d.TienMon, d.TienGiam,
                         d.TienGiamTheoHang, d.TienGiamKhuyenMai,
                         d.TongPhaiTra, d.MaPhien, d.MaKM, d.ThoiDiemLap,
                         d.TrangThaiThanhToan
                  EXCEPT
                  SELECT i.TienGioChoi, i.TienMon, i.TienGiam,
                         i.TienGiamTheoHang, i.TienGiamKhuyenMai,
                         i.TongPhaiTra, i.MaPhien, i.MaKM, i.ThoiDiemLap,
                         i.TrangThaiThanhToan
              )
          )
    )
    BEGIN
        THROW 50543,
              N'RB14: Hoa don da thanh toan, khong duoc sua/xoa thong tin tien.', 1;
    END;

    -- Khi chinh TongPhaiTra (ke ca hoa don chua thanh toan), khong cho tong thanh cong vuot muc phai tra moi
    IF EXISTS (
        SELECT 1 FROM inserted AS i
        OUTER APPLY (
            SELECT COALESCE(SUM(gd.SoTien), 0) AS DaTra
            FROM dbo.GIAO_DICH_THANH_TOAN AS gd
            WHERE gd.MaHoaDon = i.MaHoaDon AND gd.TrangThai = N'Thành công'
        ) AS tt
        WHERE tt.DaTra > i.TongPhaiTra
    )
    BEGIN
        THROW 50541,
              N'RB14: Tong giao dich thanh cong vuot TongPhaiTra moi.', 1;
    END;

    -- Khong the tu danh dau da thanh toan khi tong thanh cong chua du
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        OUTER APPLY (
            SELECT COALESCE(SUM(gd.SoTien), 0) AS DaTra
            FROM dbo.GIAO_DICH_THANH_TOAN AS gd
            WHERE gd.MaHoaDon = i.MaHoaDon AND gd.TrangThai = N'Thành công'
        ) AS tt
        WHERE i.TrangThaiThanhToan = N'Đã thanh toán'
          AND (i.TongPhaiTra IS NULL OR tt.DaTra <> i.TongPhaiTra)
    )
    BEGIN
        THROW 50544,
              N'RB14: Chua tra du, khong the danh dau Da thanh toan.', 1;
    END;
END;
GO

-- RB14.3: BAO VE TIEN GIO SAU KHI THANH TOAN
CREATE OR ALTER TRIGGER dbo.trg_RB14_KhoaTienGio
ON dbo.DOAN_SU_DUNG_BAN
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted AS d LEFT JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDoan = d.SoThuTuDoan
        JOIN dbo.HOA_DON AS hd ON hd.MaPhien = d.MaPhien WHERE hd.TrangThaiThanhToan = N'Đã thanh toán'
          AND (i.MaPhien IS NULL
              OR EXISTS (
                  SELECT d.TienGio, d.ThoiLuong, d.DonGiaApDung, d.GioBatDauDung,
                         d.GioKetThucDung, d.MaBan, d.MaLoaiBan, d.SoThuTuKhung
                  EXCEPT
                  SELECT i.TienGio, i.ThoiLuong, i.DonGiaApDung, i.GioBatDauDung,
                         i.GioKetThucDung, i.MaBan, i.MaLoaiBan, i.SoThuTuKhung
              )
          )
    )
    OR EXISTS (SELECT 1 FROM inserted AS i LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien
           AND d.SoThuTuDoan = i.SoThuTuDoan JOIN dbo.HOA_DON AS hd ON hd.MaPhien = i.MaPhien
        WHERE hd.TrangThaiThanhToan = N'Đã thanh toán' AND d.MaPhien IS NULL)
    BEGIN
        THROW 50545,
              N'RB14: Không được sửa hoặc xóa dữ liệu tính tiền giờ của phiên đã thanh toán.',
              1;
    END;
END;
GO
-- RB14.4: KHOA DU LIEU TINH TIEN MON SAU THANH TOAN
-- Cho phep doi trang thai phuc vu neu khong doi tinh trang 'Da huy'.
-- Ma loi: 50546.
CREATE OR ALTER TRIGGER dbo.trg_RB14_KhoaTienMon
ON dbo.DONG_GOI_MON
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted AS d
        LEFT JOIN inserted AS i
          ON i.MaPhien = d.MaPhien AND i.SoThuTuDong = d.SoThuTuDong
        JOIN dbo.HOA_DON AS hd ON hd.MaPhien = d.MaPhien
        WHERE hd.TrangThaiThanhToan = N'Đã thanh toán'
          AND (
              i.MaPhien IS NULL OR EXISTS (
                  SELECT d.SoLuong, d.DonGiaTaiThoiDiemGoi, d.ThanhTien,
                         d.MaMatHang,
                         CASE WHEN d.TrangThaiPhucVu = N'Đã hủy' THEN 1 ELSE 0 END
                  EXCEPT
                  SELECT i.SoLuong, i.DonGiaTaiThoiDiemGoi, i.ThanhTien,
                         i.MaMatHang,
                         CASE WHEN i.TrangThaiPhucVu = N'Đã hủy' THEN 1 ELSE 0 END
              )
          )
    )
    OR EXISTS (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS d
          ON d.MaPhien = i.MaPhien AND d.SoThuTuDong = i.SoThuTuDong
        JOIN dbo.HOA_DON AS hd ON hd.MaPhien = i.MaPhien
        WHERE hd.TrangThaiThanhToan = N'Đã thanh toán'
          AND d.MaPhien IS NULL
    )
    BEGIN
        THROW 50546,
              N'RB14: Hoa don da thanh toan, khong duoc sua/xoa du lieu tinh tien mon.', 1;
    END;
END;
GO

-- RB14.5: BAO VE PHIEN DA THANH TOAN
-- Khong sua truc tiep TrangThai tu 'Da thanh toan' sang trang thai khac.
-- Khong sua gio choi, khach hang, tong thoi gian cua phien da chot.
-- Khong danh dau phien Da thanh toan khi hoa don chua thanh toan.
-- Ma loi 50547.
CREATE OR ALTER TRIGGER dbo.trg_RB14_BaoVePhienDaThanhToan
ON dbo.PHIEN_CHOI
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d ON d.MaPhien = i.MaPhien
        LEFT JOIN dbo.HOA_DON AS hd ON hd.MaPhien = i.MaPhien
        WHERE (
            d.TrangThai = N'Đã thanh toán'
            AND (
                i.TrangThai IS NULL OR i.TrangThai <> N'Đã thanh toán'
                OR EXISTS (
                    SELECT d.GioBatDau, d.GioKetThuc, d.MaKH, d.TongThoiGianChoi
                    EXCEPT
                    SELECT i.GioBatDau, i.GioKetThuc, i.MaKH, i.TongThoiGianChoi
                )
            )
        )
        OR (
            hd.TrangThaiThanhToan = N'Đã thanh toán'
            AND (i.TrangThai IS NULL OR i.TrangThai <> N'Đã thanh toán')
        )
        OR (
            i.TrangThai = N'Đã thanh toán'
            AND (hd.MaHoaDon IS NULL
                 OR hd.TrangThaiThanhToan IS NULL
                 OR hd.TrangThaiThanhToan <> N'Đã thanh toán')
        )
    )
    BEGIN
        THROW 50547,
              N'RB14: Phien da thanh toan phai duoc bao ve va khop trang thai hoa don.', 1;
    END;
END;
GO


