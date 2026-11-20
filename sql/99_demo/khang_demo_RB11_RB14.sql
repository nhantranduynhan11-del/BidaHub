USE BidaHub;
GO

-- ============================================================================
-- BIDAHUB | KỊCH BẢN DEMO RB11 - RB14 + TRIGGER 2 + STORED PROCEDURE
--
-- Cách sử dụng:
--   1. Chạy script tạo bảng, dữ liệu, trigger và procedure trước.
--   2. Chạy TOÀN BỘ file này trong SSMS trên database BidaHub_Test.
--   3. Mỗi bài kiểm thử thay đổi dữ liệu đều nằm trong TRANSACTION và ROLLBACK.
--   4. ĐẠT: Hành vi khớp với kết quả mong đợi.
--      CẦN KIỂM TRA: Xem mã lỗi (MaLoi) và thông báo (ThongBao).
--
-- Yêu cầu dữ liệu mẫu:
--   - Có phiếu nhập và các chi tiết nhập hàng.
--   - Có hóa đơn và phiên chơi đã thanh toán.
--   - Phiên 7 hoặc 8 đã kết thúc nhưng chưa có hóa đơn.
--
-- Nếu dữ liệu mẫu khác với dữ liệu dự kiến, một số bài kiểm thử có thể
-- báo CẦN KIỂM TRA. Kịch bản không tự ý sửa dữ liệu mẫu.
-- ============================================================================
SELECT
    name AS TenTrigger,
    OBJECT_NAME(parent_id) AS Bang,
    is_disabled AS BiVoHieuHoa
FROM sys.triggers
WHERE name LIKE N'trg_RB11_%'
   OR name LIKE N'trg_RB12_%'
   OR name LIKE N'trg_RB13_%'
   OR name LIKE N'trg_RB14_%'
ORDER BY name;
GO

-- ============================================================================
-- RB11-A | CAP NHAT CHI TIET NHAP: TONG TIEN VA TON KHO TU DONG DOI (TRIGGER 2)
-- Mong doi: TongTien bang SUM(SoLuongNhap * DonGiaNhap), SoLuongTon tang 1.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Phieu INT, @Hang INT;
    DECLARE @TongCu DECIMAL(18,2), @TonCu INT, @TonMoi INT;
    SELECT TOP (1) @Phieu = ct.MaPhieuNhap, @Hang = ct.MaMatHang
    FROM dbo.CHI_TIET_NHAP AS ct ORDER BY ct.MaPhieuNhap,ct.MaMatHang;
    IF @Phieu IS NULL THROW 50591, N'Khong co chi tiet nhap de demo.', 1;
    SELECT @TongCu = TongTien FROM dbo.PHIEU_NHAP WHERE MaPhieuNhap = @Phieu;
    SELECT @TonCu = SoLuongTon FROM dbo.MAT_HANG WHERE MaMatHang = @Hang;

    UPDATE dbo.CHI_TIET_NHAP
    SET SoLuongNhap = SoLuongNhap + 1,
        DonGiaNhap = DonGiaNhap + 1000
    WHERE MaPhieuNhap = @Phieu AND MaMatHang = @Hang;

    SELECT @TonMoi = SoLuongTon FROM dbo.MAT_HANG WHERE MaMatHang = @Hang;
    SELECT N'RB11-A - TongTien va TonKho' AS CaThu,
           @Phieu AS MaPhieuNhap, @Hang AS MaMatHang,
           @TongCu AS TongTienTruoc, pn.TongTien AS TongTienSau,
           x.TongTinhLai, @TonCu AS TonTruoc, @TonMoi AS TonSau,
           CASE WHEN pn.TongTien = x.TongTinhLai AND pn.TongTien <> @TongCu
                     AND @TonMoi = @TonCu + 1
                THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua
    FROM dbo.PHIEU_NHAP AS pn
    CROSS APPLY (
        SELECT COALESCE(SUM(CAST(c.SoLuongNhap AS DECIMAL(18,2))*c.DonGiaNhap),0)
               AS TongTinhLai
        FROM dbo.CHI_TIET_NHAP AS c WHERE c.MaPhieuNhap = pn.MaPhieuNhap
    ) AS x
    WHERE pn.MaPhieuNhap = @Phieu;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB11-A - TongTien va TonKho' AS CaThu,
           ERROR_NUMBER() AS MaLoi, @Loi AS ThongBao, N'CAN KIEM TRA' AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB11-B - Ngay nhap o tuong lai
-- Mong đợi: Lỗi 50511 từ trigger hoặc lỗi 547 từ CHECK CK_PhieuNhap_NgayNhap tất cả thay đổi đều được ROLLBACK
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @P INT;
    SELECT TOP (1) @P = MaPhieuNhap FROM dbo.PHIEU_NHAP ORDER BY MaPhieuNhap;
    IF @P IS NULL THROW 50591, N'Khong co phieu nhap de demo.', 1;
    UPDATE dbo.PHIEU_NHAP
    SET NgayNhap = DATEADD(DAY, 1, CAST(GETDATE() AS DATE))
    WHERE MaPhieuNhap = @P;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB11-B - Ngay nhap o tuong lai' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB11-B - Ngay nhap o tuong lai' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE
    WHEN ERROR_NUMBER() = 50511 OR (ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_PhieuNhap_NgayNhap%')
    THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua
END CATCH;
GO

-- ============================================================================
-- RB11-C - Sua TongTien truc tiep
-- Mong doi: loi 50514; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @P INT;
    SELECT TOP (1) @P = MaPhieuNhap FROM dbo.PHIEU_NHAP ORDER BY MaPhieuNhap;
    IF @P IS NULL THROW 50591, N'Khong co phieu nhap de demo.', 1;
    UPDATE dbo.PHIEU_NHAP SET TongTien = TongTien + 1000
    WHERE MaPhieuNhap = @P;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB11-C - Sua TongTien truc tiep' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB11-C - Sua TongTien truc tiep' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50514 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB11-D - Nhan vien khong co quyen nhap
-- Mong doi: loi 50512; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @P INT;
    SELECT TOP (1) @P = MaPhieuNhap FROM dbo.PHIEU_NHAP ORDER BY MaPhieuNhap;
    IF @P IS NULL THROW 50591, N'Khong co phieu nhap de demo.', 1;
    -- NV 3 la Thu ngan trong bo du lieu mau.
    UPDATE dbo.PHIEU_NHAP SET MaNVLap = 3 WHERE MaPhieuNhap = @P;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB11-D - Nhan vien khong co quyen nhap' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB11-D - Nhan vien khong co quyen nhap' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50512 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB12-A - Nhan vien lap hoa don sai vai tro
-- Mong doi: loi 50522; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    -- NV 7 la Thu kho, khong duoc lap hoa don.
    UPDATE dbo.HOA_DON SET MaNVLap = 7 WHERE MaHoaDon = 1;
    IF @@ROWCOUNT = 0 THROW 50592, N'Khong co hoa don 1.', 1;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-A - Nhan vien lap hoa don sai vai tro' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-A - Nhan vien lap hoa don sai vai tro' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50522 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB12-B - Tien gio tren hoa don sai
-- Mong doi: loi 50525; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    -- Sua dong thoi TongPhaiTra de khong vi pham CHECK cong thuc truoc trigger.
    UPDATE dbo.HOA_DON
    SET TienGioChoi = TienGioChoi + 1000,
        TongPhaiTra = TongPhaiTra + 1000
    WHERE MaHoaDon = @MaHDTest;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-B - Tien gio tren hoa don sai' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-B - Tien gio tren hoa don sai' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50525 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB12-C - Tien mon tren hoa don sai
-- Mong doi: loi 50526; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    UPDATE dbo.HOA_DON
    SET TienMon = TienMon + 1000,
        TongPhaiTra = TongPhaiTra + 1000
    WHERE MaHoaDon = @MaHDTest;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-C - Tien mon tren hoa don sai' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-C - Tien mon tren hoa don sai' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50526 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB12-D - Sua du lieu gio khi da lap HD
-- Mong doi: loi 50527; tat ca thay doi duoc ROLLBACK.
-- Neu trigger cua thanh vien khac chan truoc, xem MaLoi va thong bao.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    UPDATE dbo.DOAN_SU_DUNG_BAN
    SET DonGiaApDung = DonGiaApDung + 1000
    WHERE MaPhien = @MaPhienTest;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-D - Sua du lieu gio khi da lap HD' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-D - Sua du lieu gio khi da lap HD' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50527 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB12-E - Sua du lieu mon khi da lap HD
-- Mong doi: loi 50528; tat ca thay doi duoc ROLLBACK.
-- Neu trigger cua Dung chan truoc, xem MaLoi va thong bao.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    IF NOT EXISTS (SELECT 1 FROM dbo.DONG_GOI_MON WHERE MaPhien = @MaPhienTest)
        THROW 50597, N'Phien thu khong co dong goi mon.', 1;
    UPDATE TOP (1) dbo.DONG_GOI_MON
    SET SoLuong = SoLuong + 1
    WHERE MaPhien = @MaPhienTest;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-E - Sua du lieu mon khi da lap HD' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB12-E - Sua du lieu mon khi da lap HD' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50528 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB13-A - Khuyen mai het han
-- Mong doi: loi 50531; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    DECLARE @KMHetHan INT;
    SELECT TOP (1) @KMHetHan = MaKM
    FROM dbo.KHUYEN_MAI
    WHERE NgayKetThuc < CAST(DATEADD(MINUTE,5,@KetThuc) AS DATE)
    ORDER BY NgayKetThuc, MaKM;
    IF @KMHetHan IS NULL
        THROW 50593, N'Khong co ma khuyen mai het han trong du lieu mau.', 1;
    UPDATE dbo.HOA_DON SET MaKM = @KMHetHan
    WHERE MaHoaDon = @MaHDTest;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB13-A - Khuyen mai het han' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB13-A - Khuyen mai het han' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50531 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB13-B - Sua thoi han KM da ap dung
-- Mong doi: loi 50532; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @KM INT;
    SELECT TOP (1) @KM = MaKM FROM dbo.HOA_DON
    WHERE MaKM IS NOT NULL ORDER BY MaHoaDon;
    IF @KM IS NULL THROW 50593, N'Khong co hoa don ap dung KM.', 1;
    -- Khoang ngay moi hop le ve thu tu, nhung khong bao phu HD cu.
    UPDATE dbo.KHUYEN_MAI
    SET NgayBatDau = '2024-01-01', NgayKetThuc = '2024-12-31'
    WHERE MaKM = @KM;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB13-B - Sua thoi han KM da ap dung' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB13-B - Sua thoi han KM da ap dung' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50532 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB13-C - Giam khuyen mai nhung khong co MaKM
-- Mong doi: loi 50535; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    -- Cung thay doi TongPhaiTra de van dung CHECK cua HOA_DON.
    UPDATE dbo.HOA_DON
    SET TienGiamKhuyenMai = 1,
        TienGiam = 1,
        TongPhaiTra = TongPhaiTra - 1
    WHERE MaHoaDon = @MaHDTest;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB13-C - Giam khuyen mai nhung khong co MaKM' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB13-C - Giam khuyen mai nhung khong co MaKM' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50535 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB13-D - Giam hang khong hop le
-- Mong doi: loi 50533,50534; tat ca thay doi duoc ROLLBACK.
-- Ma loi 50533 (khong phai hoi vien) hoac 50534 (sai phan tram).
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    UPDATE dbo.HOA_DON
    SET TienGiamTheoHang = 1,
        TienGiam = 1,
        TongPhaiTra = TongPhaiTra - 1
    WHERE MaHoaDon = @MaHDTest;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB13-D - Giam hang khong hop le' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB13-D - Giam hang khong hop le' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50533 OR @MaLoi = 50534 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB14-A - Thanh toan vuot TongPhaiTra
-- Mong doi: loi 50541; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.GIAO_DICH_THANH_TOAN
      (ThoiDiemThanhToan, SoTien, PhuongThuc, MaThamChieu,
       TrangThai, MaHoaDon, MaNVXacNhan)
    VALUES (DATEADD(MINUTE,10,@KetThuc), @Tong + 10000,
            N'Tiền mặt',NULL,N'Thành công',@MaHDTest,3);
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-A - Thanh toan vuot TongPhaiTra' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-A - Thanh toan vuot TongPhaiTra' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50541 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB14-B | THANH TOAN MOT PHAN, SAU DO THANH TOAN DU
-- Mong doi: hoa don chuyen mot phan -> da thanh toan;
--           phien chuyen da ket thuc -> da thanh toan.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;
    -- Tao hoa don CHUA thanh toan cho mot phien da ket thuc, chua co hoa don.
    DECLARE @MaPhienTest INT, @MaHDTest INT;
    DECLARE @KetThuc DATETIME2, @TienGio DECIMAL(18,2),
            @TienMon DECIMAL(18,2), @Tong DECIMAL(18,2);
    SELECT TOP (1)
        @MaPhienTest = p.MaPhien,
        @KetThuc = p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.MaPhien IN (7,8)
      AND p.GioKetThuc IS NOT NULL
      AND p.TrangThai = N'Đã kết thúc'
      AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
      AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = p.MaPhien)
      AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                      WHERE d.MaPhien = p.MaPhien AND d.GioKetThucDung IS NULL)
    ORDER BY CASE WHEN p.MaPhien = 7 THEN 0 ELSE 1 END;
    IF @MaPhienTest IS NULL
        THROW 50595, N'Can phien 7 hoac 8 da ket thuc, chua co hoa don.', 1;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio),0),0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = @MaPhienTest;
    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien),0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = @MaPhienTest
      AND (gm.TrangThaiPhucVu IS NULL OR gm.TrangThaiPhucVu <> N'Đã hủy');
    SET @Tong = @TienGio + @TienMon;
    IF @Tong <= 100000
        THROW 50596, N'Tong tien phien thu phai tren 100000.', 1;

    INSERT INTO dbo.HOA_DON
      (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra,
       DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
      (DATEADD(MINUTE,5,@KetThuc), @TienGio, @TienMon, 0, @Tong,
       0, N'Chưa thanh toán', @MaPhienTest, 3, NULL);
    SET @MaHDTest = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.GIAO_DICH_THANH_TOAN
      (ThoiDiemThanhToan,SoTien,PhuongThuc,MaThamChieu,
       TrangThai,MaHoaDon,MaNVXacNhan)
    VALUES (DATEADD(MINUTE,10,@KetThuc),100000,N'Tiền mặt',NULL,
            N'Thành công',@MaHDTest,3);

    DECLARE @MotPhan BIT = 0, @Du BIT = 0;
    IF EXISTS (
      SELECT 1 FROM dbo.HOA_DON AS hd
      JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = hd.MaPhien
      WHERE hd.MaHoaDon = @MaHDTest
        AND hd.TrangThaiThanhToan = N'Thanh toán một phần'
        AND p.TrangThai = N'Đã kết thúc'
    ) SET @MotPhan = 1;

    INSERT INTO dbo.GIAO_DICH_THANH_TOAN
      (ThoiDiemThanhToan,SoTien,PhuongThuc,MaThamChieu,
       TrangThai,MaHoaDon,MaNVXacNhan)
    VALUES (DATEADD(MINUTE,15,@KetThuc),@Tong-100000,N'Tiền mặt',NULL,
            N'Thành công',@MaHDTest,3);

    IF EXISTS (
      SELECT 1 FROM dbo.HOA_DON AS hd
      JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = hd.MaPhien
      WHERE hd.MaHoaDon = @MaHDTest
        AND hd.TrangThaiThanhToan = N'Đã thanh toán'
        AND p.TrangThai = N'Đã thanh toán'
    ) SET @Du = 1;

    SELECT N'RB14-B - Thanh toan mot phan / du' AS CaThu,
           @Tong AS TongPhaiTra,
           @MotPhan AS DungTrangThaiMotPhan,
           @Du AS DungTrangThaiDaThanhToan,
           CASE WHEN @MotPhan=1 AND @Du=1 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-B - Thanh toan mot phan / du' AS CaThu,
           ERROR_NUMBER() AS MaLoi, @Loi AS ThongBao, N'CAN KIEM TRA' AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB14-C - Sua GD cua hoa don da thanh toan
-- Mong doi: loi 50542; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE TOP(1) dbo.GIAO_DICH_THANH_TOAN
    SET SoTien = SoTien + 1
    WHERE MaHoaDon IN (
       SELECT MaHoaDon FROM dbo.HOA_DON
       WHERE TrangThaiThanhToan = N'Đã thanh toán'
    ) AND TrangThai = N'Thành công';
    IF @@ROWCOUNT = 0 THROW 50592, N'Khong tim thay GD thanh cong cua HD da thanh toan.',1;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-C - Sua GD cua hoa don da thanh toan' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-C - Sua GD cua hoa don da thanh toan' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50542 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB14-D - Sua HD da thanh toan
-- Mong doi: loi 50543; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    -- Doi thoi diem lap nho, khong doi cong thuc tien va ma khuyen mai.
    UPDATE dbo.HOA_DON
    SET ThoiDiemLap = DATEADD(SECOND, 1, ThoiDiemLap)
    WHERE MaHoaDon = 1;
    IF @@ROWCOUNT = 0 THROW 50592, N'Khong co hoa don 1.',1;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-D - Sua HD da thanh toan' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-D - Sua HD da thanh toan' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50543 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB14-E - Xoa doan gio cua phien da thanh toan
-- Mong doi: loi 50545; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    DELETE TOP (1) FROM dbo.DOAN_SU_DUNG_BAN WHERE MaPhien = 1;
    IF @@ROWCOUNT = 0 THROW 50592, N'Phien 1 khong co doan su dung ban.',1;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-E - Xoa doan gio cua phien da thanh toan' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-E - Xoa doan gio cua phien da thanh toan' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50545 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB14-F - Xoa dong mon cua phien da thanh toan
-- Mong doi: loi 50546; tat ca thay doi duoc ROLLBACK.
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    DELETE TOP (1) FROM dbo.DONG_GOI_MON WHERE MaPhien = 1;
    IF @@ROWCOUNT = 0 THROW 50592, N'Phien 1 khong co dong goi mon.',1;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-F - Xoa dong mon cua phien da thanh toan' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-F - Xoa dong mon cua phien da thanh toan' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50546 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- RB14-G - Sua trang thai phien da thanh toan
-- Mong doi: loi 50547; tat ca thay doi duoc ROLLBACK.  
-- ===========================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.PHIEN_CHOI SET TrangThai = N'Đã kết thúc' WHERE MaPhien = 1;
    IF @@ROWCOUNT = 0 THROW 50592, N'Khong co phien 1.',1;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-G - Sua trang thai phien da thanh toan' AS CaThu, CAST(NULL AS INT) AS MaLoi,
           N'Lenh sai khong bi chan' AS ThongBao, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER();
    DECLARE @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'RB14-G - Sua trang thai phien da thanh toan' AS CaThu, @MaLoi AS MaLoi,
           @Loi AS ThongBao,
           CASE WHEN @MaLoi = 50547 THEN N'DAT' ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- PROC-A | THONG KE DOANH THU: DU LIEU MAU THANG 10/2025
-- Demo co SUM, GROUP BY, HAVING, WHERE, ORDER BY tren 3 bang.
-- ============================================================================
EXEC dbo.sp_ThongKeDoanhThu
    @TuNgay = '2025-10-01',
    @DenNgay = '2025-10-31',
    @DoanhThuToiThieu = 0;
GO

-- PROC-B | NHOM NGAY CO DOANH THU >= 500000
EXEC dbo.sp_ThongKeDoanhThu
    @TuNgay = '2025-10-01',
    @DenNgay = '2025-10-31',
    @DoanhThuToiThieu = 500000;
GO

-- PROC-C | NGAY KHONG HOP LE, MONG DOI 50571
BEGIN TRY
    EXEC dbo.sp_ThongKeDoanhThu
        @TuNgay = '2025-10-31',
        @DenNgay = '2025-10-01',
        @DoanhThuToiThieu = 0;
    SELECT N'PROC-C - Ngay sai' AS CaThu, N'KHONG DAT' AS KetQua;
END TRY
BEGIN CATCH
    SELECT N'PROC-C - Ngay sai' AS CaThu,
           ERROR_NUMBER() AS MaLoi, ERROR_MESSAGE() AS ThongBao,
           CASE WHEN ERROR_NUMBER() = 50571 THEN N'DAT'
                ELSE N'CAN KIEM TRA' END AS KetQua;
END CATCH;
GO

-- ============================================================================
-- KIEM TRA DU LIEU KHONG BI THAY DOI SAU DEMO
-- Vi moi test DML deu ROLLBACK, so lieu mau se duoc giu nguyen.
-- ============================================================================
SELECT hd.MaHoaDon, hd.MaPhien, hd.TongPhaiTra, hd.TrangThaiThanhToan,
       pc.TrangThai AS TrangThaiPhien
FROM dbo.HOA_DON AS hd
JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = hd.MaPhien
WHERE hd.MaHoaDon IN (1,2,3,4,5)
ORDER BY hd.MaHoaDon;
GO

