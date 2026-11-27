-- ============================================================================
-- sql/99_demo/phong.sql (Phong - MSSV 2412628):
-- Kịch bản demo RB15, thủ tục thêm/sửa/xóa KHACH_HANG (mục 2.1),
-- thủ tục tra cứu/thống kê (mục 2.3) và hàm UDF có con trỏ (mục 2.4).
--
-- Cách chạy:
--   1. Dựng CSDL chuẩn: init.sql -> 01_bang/tao_tat_ca_bang.sql
--      -> 02_du_lieu/nap_tat_ca_du_lieu.sql -> 03_trigger/tao_tat_ca_trigger.sql
--      -> 04_thu_tuc/phong.sql -> 05_ham/phong.sql.
--   2. Chạy toàn bộ file này (hoặc bôi đen từng khối giữa hai dòng GO khi báo cáo).
--   3. Mọi ca có thay đổi dữ liệu đều bọc trong BEGIN TRANSACTION ... ROLLBACK TRANSACTION,
--      chạy lại bao nhiêu lần dữ liệu mẫu vẫn giữ nguyên 100%.
--   4. Cuối file in bảng tổng hợp #KetQuaPhong để đối chiếu nhanh ĐẠT / CẦN KIỂM TRA.
-- ============================================================================

USE BidaHub;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'tempdb..#KetQuaPhong') IS NOT NULL DROP TABLE #KetQuaPhong;
CREATE TABLE #KetQuaPhong
(
    STT      INT IDENTITY(1,1) PRIMARY KEY,
    CaThu    NVARCHAR(160) NOT NULL,
    MaLoi    INT           NULL,
    ThongBao NVARCHAR(4000) NULL,
    KetQua   NVARCHAR(20)  NOT NULL
);
GO

PRINT N'====================================================================';
PRINT N'              KỊCH BẢN DEMO PHẦN VIỆC - ĐÀO HUY PHONG              ';
PRINT N'====================================================================';
GO

-- ============================================================================
-- PHẦN 1: KIỂM THỬ RÀNG BUỘC NGỮ NGHĨA RB15 (ĐIỂM TÍCH LŨY & HẠNG THÀNH VIÊN)
-- ============================================================================
PRINT N'';
PRINT N'===== PHẦN 1: KIỂM THỬ TRIGGER RB15 =====';
GO

-- 1.1. Trigger trg_HOI_VIEN_RB15_CapNhatHang: đổi điểm tích lũy -> tự nâng hạng (ROLLBACK)
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @HangTruoc INT, @HangSau INT;
    SELECT @HangTruoc = MaHang FROM dbo.HOI_VIEN WHERE MaKH = 3; -- Đang 50 điểm, hạng 1 (Đồng)

    UPDATE dbo.HOI_VIEN SET DiemTichLuy = 350 WHERE MaKH = 3;    -- Mốc >= 300 là hạng 3 (Vàng)

    SELECT @HangSau = MaHang FROM dbo.HOI_VIEN WHERE MaKH = 3;

    SELECT hv.MaKH,
           CONCAT_WS(N' ', kh.Ho, kh.TenDem, kh.Ten) AS HoTen,
           @HangTruoc AS MaHangTruoc,
           hv.DiemTichLuy AS DiemMoi,
           hv.MaHang AS MaHangMoi,
           h.TenHang AS TenHangMoi
    FROM dbo.HOI_VIEN AS hv
    JOIN dbo.KHACH_HANG AS kh     ON kh.MaKH = hv.MaKH
    JOIN dbo.HANG_THANH_VIEN AS h ON h.MaHang = hv.MaHang
    WHERE hv.MaKH = 3;

    ROLLBACK TRANSACTION;

    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.1. Tự động nâng hạng hội viên MaKH=3 (Đồng -> Vàng)', NULL,
            CONCAT(N'MaHang đổi từ ', @HangTruoc, N' sang ', @HangSau, N' rồi ROLLBACK'),
            CASE WHEN @HangTruoc = 1 AND @HangSau = 3 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @Ma11 INT = ERROR_NUMBER(), @Loi11 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.1. Tự động nâng hạng hội viên MaKH=3', @Ma11, @Loi11, N'CẦN KIỂM TRA');
END CATCH;
GO

-- 1.2. Chặn điểm tích lũy âm bởi CHECK CK_HoiVien_DiemTichLuy. Mong đợi: lỗi 547
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.HOI_VIEN SET DiemTichLuy = -50 WHERE MaKH = 3;
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.2. Chặn cập nhật điểm tích lũy âm (CK_HoiVien_DiemTichLuy)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma12 INT = ERROR_NUMBER(), @Loi12 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.2. Chặn cập nhật điểm tích lũy âm (CK_HoiVien_DiemTichLuy)', @Ma12, @Loi12,
            CASE WHEN @Ma12 = 547 AND @Loi12 LIKE N'%CK_HoiVien_DiemTichLuy%' THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 1.3. Chặn xóa hạng thành viên đang có hội viên (INSTEAD OF DELETE). Mong đợi: lỗi 50219
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.HANG_THANH_VIEN WHERE MaHang = 1; -- Hạng Đồng đang có MaKH 3, 6
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.3. Chặn xóa hạng thành viên đang có hội viên (50219)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma13 INT = ERROR_NUMBER(), @Loi13 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.3. Chặn xóa hạng thành viên đang có hội viên (50219)', @Ma13, @Loi13,
            CASE WHEN @Ma13 = 50219 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 1.4. Thanh toán hóa đơn thật của phiên 7 (hội viên MaKH=4):
--      Lấy đúng TienGioChoi từ DOAN_SU_DUNG_BAN và TienMon từ DONG_GOI_MON (thỏa RB12),
--      lập hóa đơn 'Chưa thanh toán', sau đó thêm GIAO_DICH_THANH_TOAN đủ tiền (RB14) ->
--      trigger RB15 tự ghi DiemCong = FLOOR(TongPhaiTra / 10000) và cộng vào HOI_VIEN.DiemTichLuy.
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @DiemTruoc INT, @DiemSau INT, @DiemCongHD INT, @TrangThaiHD NVARCHAR(30);
    DECLARE @TienGio DECIMAL(18,2), @TienMon DECIMAL(18,2), @GiamHang DECIMAL(18,2), @TongPhaiTra DECIMAL(18,2);
    DECLARE @PhanTramHang DECIMAL(5,2), @MaHDMoi INT, @DiemKyVong INT;

    SELECT @DiemTruoc = hv.DiemTichLuy, @PhanTramHang = h.PhanTramGiamGia
    FROM dbo.HOI_VIEN AS hv
    JOIN dbo.HANG_THANH_VIEN AS h ON h.MaHang = hv.MaHang
    WHERE hv.MaKH = 4;

    SELECT @TienGio = CAST(ROUND(COALESCE(SUM(d.TienGio), 0), 0) AS DECIMAL(18,2))
    FROM dbo.DOAN_SU_DUNG_BAN AS d
    WHERE d.MaPhien = 7;

    SELECT @TienMon = COALESCE(SUM(gm.ThanhTien), 0)
    FROM dbo.DONG_GOI_MON AS gm
    WHERE gm.MaPhien = 7 AND gm.TrangThaiPhucVu <> N'Đã hủy';

    -- Áp dụng giảm theo hạng Bạch Kim (15% trên tiền giờ) đúng quy tắc RB13
    SET @GiamHang = CAST(ROUND(@TienGio * @PhanTramHang / 100.0, 0) AS DECIMAL(18,2));
    SET @TongPhaiTra = @TienGio + @TienMon - @GiamHang;
    SET @DiemKyVong = FLOOR(@TongPhaiTra / 10000.0);

    INSERT INTO dbo.HOA_DON
        (ThoiDiemLap, TienGioChoi, TienMon, TienGiam, TienGiamTheoHang, TienGiamKhuyenMai,
         TongPhaiTra, DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM)
    VALUES
        ('2025-10-24 22:35:00', @TienGio, @TienMon, @GiamHang, @GiamHang, 0,
         @TongPhaiTra, 0, N'Chưa thanh toán', 7, 3, NULL);

    SET @MaHDMoi = SCOPE_IDENTITY();

    INSERT INTO dbo.GIAO_DICH_THANH_TOAN
        (ThoiDiemThanhToan, SoTien, PhuongThuc, MaThamChieu, TrangThai, MaHoaDon, MaNVXacNhan)
    VALUES
        ('2025-10-24 22:36:00', @TongPhaiTra, N'Tiền mặt', NULL, N'Thành công', @MaHDMoi, 3);

    SELECT @DiemCongHD = DiemCong, @TrangThaiHD = TrangThaiThanhToan
    FROM dbo.HOA_DON WHERE MaHoaDon = @MaHDMoi;

    SELECT @DiemSau = DiemTichLuy FROM dbo.HOI_VIEN WHERE MaKH = 4;

    SELECT @MaHDMoi AS MaHoaDon, 7 AS MaPhien, @TienGio AS TienGioChoi, @TienMon AS TienMon,
           @GiamHang AS TienGiamTheoHang, @TongPhaiTra AS TongPhaiTra,
           @TrangThaiHD AS TrangThaiSauGD, @DiemCongHD AS DiemCongTuTinh,
           @DiemTruoc AS DiemHoiVienTruoc, @DiemSau AS DiemHoiVienSau;

    ROLLBACK TRANSACTION;

    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.4. Thanh toán hóa đơn phiên 7 -> tự ghi DiemCong & cộng điểm', NULL,
            CONCAT(N'TongPhaiTra=', @TongPhaiTra, N', DiemCong=', @DiemCongHD, N', DiemTichLuy: ', @DiemTruoc, N' -> ', @DiemSau),
            CASE WHEN @TrangThaiHD = N'Đã thanh toán'
                      AND @DiemCongHD = @DiemKyVong
                      AND @DiemSau = @DiemTruoc + @DiemKyVong
                 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @Ma14 INT = ERROR_NUMBER(), @Loi14 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.4. Thanh toán hóa đơn phiên 7 -> tự ghi DiemCong & cộng điểm', @Ma14, @Loi14, N'CẦN KIỂM TRA');
END CATCH;
GO

-- 1.5. Chặn cộng điểm cho hóa đơn khách không phải hội viên (phiên 5 là khách vãng lai). Mong đợi: lỗi 50216
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.HOA_DON SET DiemCong = 3 WHERE MaPhien = 5;
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.5. Chặn cộng điểm hóa đơn khách vãng lai (50216)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma15 INT = ERROR_NUMBER(), @Loi15 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.5. Chặn cộng điểm hóa đơn khách vãng lai (50216)', @Ma15, @Loi15,
            CASE WHEN @Ma15 = 50216 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 1.6. Chặn sửa điểm cộng của hóa đơn hội viên đã thanh toán (phiên 2 của hội viên MaKH=1). Mong đợi: lỗi 50217
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.HOA_DON SET DiemCong = 999 WHERE MaPhien = 2;
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.6. Chặn sửa điểm cộng của hóa đơn đã thanh toán (50217)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma16 INT = ERROR_NUMBER(), @Loi16 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.6. Chặn sửa điểm cộng của hóa đơn đã thanh toán (50217)', @Ma16, @Loi16,
            CASE WHEN @Ma16 = 50217 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 1.7. Đổi mốc điểm tối thiểu của hạng Đồng lên 60 làm MaKH=6 (39 điểm) không còn hạng phù hợp. Mong đợi: lỗi 50218
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.HANG_THANH_VIEN SET DiemToiThieu = 60 WHERE MaHang = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.7. Chặn đổi mốc điểm làm hội viên mất hạng phù hợp (50218)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma17 INT = ERROR_NUMBER(), @Loi17 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'1.7. Chặn đổi mốc điểm làm hội viên mất hạng phù hợp (50218)', @Ma17, @Loi17,
            CASE WHEN @Ma17 = 50218 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- ============================================================================
-- PHẦN 2: KIỂM THỬ THỦ TỤC THÊM, SỬA, XÓA KHACH_HANG (MỤC 2.1)
-- ============================================================================
PRINT N'';
PRINT N'===== PHẦN 2: KIỂM THỬ THỦ TỤC THÊM, SỬA, XÓA KHACH_HANG =====';
GO

-- 2.1. Thêm khách hàng hợp lệ (tự sinh MaKH IDENTITY) rồi ROLLBACK
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @NewMaKH INT;
    EXEC dbo.sp_ThemKhachHang
        @Ho = N'Lý',
        @TenDem = N'Hải',
        @Ten = N'Nam',
        @NgaySinh = '1997-05-15',
        @GioiTinh = N'Nam',
        @SoDienThoai = '0919998877',
        @MaKH = @NewMaKH OUTPUT;

    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.1. sp_ThemKhachHang hợp lệ (sinh MaKH tự động)', NULL,
            CONCAT(N'Sinh MaKH=', @NewMaKH, N' thành công rồi ROLLBACK'),
            CASE WHEN @NewMaKH IS NOT NULL THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @Ma21 INT = ERROR_NUMBER(), @Loi21 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.1. sp_ThemKhachHang hợp lệ', @Ma21, @Loi21, N'CẦN KIỂM TRA');
END CATCH;
GO

-- 2.2. Thêm thất bại: Họ để trống. Mong đợi: lỗi 50202
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_ThemKhachHang @Ho = N'   ', @TenDem = N'Văn', @Ten = N'Bình';
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.2. sp_ThemKhachHang: Họ để trống (50202)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma22 INT = ERROR_NUMBER(), @Loi22 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.2. sp_ThemKhachHang: Họ để trống (50202)', @Ma22, @Loi22,
            CASE WHEN @Ma22 = 50202 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.3. Thêm thất bại: Tên để trống. Mong đợi: lỗi 50203
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_ThemKhachHang @Ho = N'Trịnh', @TenDem = NULL, @Ten = N'';
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.3. sp_ThemKhachHang: Tên để trống (50203)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma23 INT = ERROR_NUMBER(), @Loi23 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.3. sp_ThemKhachHang: Tên để trống (50203)', @Ma23, @Loi23,
            CASE WHEN @Ma23 = 50203 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.4. Thêm thất bại: Giới tính sai. Mong đợi: lỗi 50204
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_ThemKhachHang @Ho = N'Phan', @Ten = N'Thảo', @GioiTinh = N'KhôngRõ';
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.4. sp_ThemKhachHang: Giới tính không hợp lệ (50204)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma24 INT = ERROR_NUMBER(), @Loi24 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.4. sp_ThemKhachHang: Giới tính không hợp lệ (50204)', @Ma24, @Loi24,
            CASE WHEN @Ma24 = 50204 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.5. Thêm thất bại: Ngày sinh ở tương lai. Mong đợi: lỗi 50205
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_ThemKhachHang @Ho = N'Đoàn', @Ten = N'Khánh', @NgaySinh = '2099-01-01';
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.5. sp_ThemKhachHang: Ngày sinh ở tương lai (50205)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma25 INT = ERROR_NUMBER(), @Loi25 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.5. sp_ThemKhachHang: Ngày sinh ở tương lai (50205)', @Ma25, @Loi25,
            CASE WHEN @Ma25 = 50205 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.6. Thêm thất bại: Sai định dạng SĐT. Mong đợi: lỗi 50207
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_ThemKhachHang @Ho = N'Lê', @Ten = N'Toàn', @SoDienThoai = '12345ABC';
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.6. sp_ThemKhachHang: Sai định dạng SĐT (50207)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma26 INT = ERROR_NUMBER(), @Loi26 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.6. sp_ThemKhachHang: Sai định dạng SĐT (50207)', @Ma26, @Loi26,
            CASE WHEN @Ma26 = 50207 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.7. Thêm thất bại: Trùng SĐT của khách khác (0903123456 của MaKH=1). Mong đợi: lỗi 50208
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_ThemKhachHang @Ho = N'Lê', @Ten = N'Toàn', @SoDienThoai = '0903123456';
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.7. sp_ThemKhachHang: Trùng SĐT khách khác (50208)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma27 INT = ERROR_NUMBER(), @Loi27 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.7. sp_ThemKhachHang: Trùng SĐT khách khác (50208)', @Ma27, @Loi27,
            CASE WHEN @Ma27 = 50208 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.8. Sửa khách hàng hợp lệ rồi ROLLBACK
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_SuaKhachHang
        @MaKH = 1,
        @Ho = N'Trần',
        @TenDem = N'Văn',
        @Ten = N'Bình Minh',
        @NgaySinh = '1992-06-15',
        @GioiTinh = N'Nam',
        @SoDienThoai = '0903123456';
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.8. sp_SuaKhachHang hợp lệ trên MaKH=1', NULL, N'Cập nhật thành công rồi ROLLBACK', N'ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma28 INT = ERROR_NUMBER(), @Loi28 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.8. sp_SuaKhachHang hợp lệ', @Ma28, @Loi28, N'CẦN KIỂM TRA');
END CATCH;
GO

-- 2.9. Sửa thất bại: Mã khách hàng không tồn tại. Mong đợi: lỗi 50209
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_SuaKhachHang @MaKH = 9999, @Ho = N'Không', @Ten = N'Tồn Tại';
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.9. sp_SuaKhachHang: Mã khách không tồn tại (50209)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma29 INT = ERROR_NUMBER(), @Loi29 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.9. sp_SuaKhachHang: Mã khách không tồn tại (50209)', @Ma29, @Loi29,
            CASE WHEN @Ma29 = 50209 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.10a. Chặn xóa khách hàng đã có phiếu đặt bàn (MaKH=1 có MaDatBan=1). Mong đợi: lỗi 50210
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_XoaKhachHang @MaKH = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.10a. sp_XoaKhachHang: Chặn khách đã có phiếu đặt bàn (50210)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma210a INT = ERROR_NUMBER(), @Loi210a NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.10a. sp_XoaKhachHang: Chặn khách đã có phiếu đặt bàn (50210)', @Ma210a, @Loi210a,
            CASE WHEN @Ma210a = 50210 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.10b. Chặn xóa khách hàng chưa đặt bàn nhưng đã mở phiên chơi (MaKH=10 mở phiên mới). Mong đợi: lỗi 50211
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.PHIEN_CHOI (GioBatDau, TrangThai, MaNVMoPhien, MaKH)
    VALUES ('2025-10-25 16:00:00', N'Đang chơi', 3, 10);

    EXEC dbo.sp_XoaKhachHang @MaKH = 10;
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.10b. sp_XoaKhachHang: Chặn khách đã có phiên chơi (50211)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma210b INT = ERROR_NUMBER(), @Loi210b NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.10b. sp_XoaKhachHang: Chặn khách đã có phiên chơi (50211)', @Ma210b, @Loi210b,
            CASE WHEN @Ma210b = 50211 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.10c. Chặn xóa hội viên đang có điểm tích lũy > 0 (MaKH=10 chưa có đặt bàn/phiên chơi, đăng ký hội viên 50 điểm). Mong đợi: lỗi 50212
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.HOI_VIEN (MaKH, DiemTichLuy, MaHang, MaTK)
    VALUES (10, 50, 1, NULL);

    EXEC dbo.sp_XoaKhachHang @MaKH = 10;
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.10c. sp_XoaKhachHang: Chặn xóa hội viên đang có điểm (50212)', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @Ma210c INT = ERROR_NUMBER(), @Loi210c NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.10c. sp_XoaKhachHang: Chặn xóa hội viên đang có điểm (50212)', @Ma210c, @Loi210c,
            CASE WHEN @Ma210c = 50212 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- 2.11. Xóa hợp lệ khách hàng chưa phát sinh đặt bàn/phiên chơi (MaKH=10) rồi ROLLBACK
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_XoaKhachHang @MaKH = 10;
    DECLARE @ConTonTai INT = CASE WHEN EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = 10) THEN 1 ELSE 0 END;
    ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.11. sp_XoaKhachHang hợp lệ (MaKH=10 chưa có giao dịch)', NULL,
            N'Xóa thành công trong giao tác rồi ROLLBACK',
            CASE WHEN @ConTonTai = 0 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @Ma211 INT = ERROR_NUMBER(), @Loi211 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT INTO #KetQuaPhong (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'2.11. sp_XoaKhachHang hợp lệ (MaKH=10)', @Ma211, @Loi211, N'CẦN KIỂM TRA');
END CATCH;
GO

-- ============================================================================
-- PHẦN 3: KIỂM THỬ THỦ TỤC TRA CỨU & THỐNG KÊ (MỤC 2.3)
-- ============================================================================
PRINT N'';
PRINT N'===== PHẦN 3: KIỂM THỬ THỦ TỤC TRA CỨU & THỐNG KÊ =====';
GO

-- 3.1. Tra cứu tất cả khách hàng, sắp xếp theo điểm tích lũy giảm dần
EXEC dbo.sp_TraCuuKhachHang @SapXepTheo = 'DiemTichLuy', @HuongSapXep = 'DESC';
GO

-- 3.2. Tra cứu lọc Hội viên hạng Vàng (MaHang = 3)
EXEC dbo.sp_TraCuuKhachHang @LoaiKhach = 'HoiVien', @MaHang = 3;
GO

-- 3.3. Thống kê khách hàng có tổng chi tiêu >= 200.000 VNĐ (GROUP BY + HAVING)
EXEC dbo.sp_ThongKeChiTieuKhachHang @SoLuotChoiToiThieu = 1, @TongChiTieuToiThieu = 200000;
GO

-- ============================================================================
-- PHẦN 4: KIỂM THỬ HÀM TÍNH TOÁN UDF CÓ CON TRỎ CURSOR (MỤC 2.4)
-- ============================================================================
PRINT N'';
PRINT N'===== PHẦN 4: KIỂM THỬ HÀM UDF DÙNG CURSOR =====';
GO

-- 4.1. Hàm fn_XacDinhHangThanhVien
SELECT
    dbo.fn_XacDinhHangThanhVien(0)    AS Hang_0Diem_Mong1,
    dbo.fn_XacDinhHangThanhVien(150)  AS Hang_150Diem_Mong2,
    dbo.fn_XacDinhHangThanhVien(350)  AS Hang_350Diem_Mong3,
    dbo.fn_XacDinhHangThanhVien(750)  AS Hang_750Diem_Mong4,
    dbo.fn_XacDinhHangThanhVien(1250) AS Hang_1250Diem_Mong5,
    dbo.fn_XacDinhHangThanhVien(-10)  AS Hang_Am_MongNULL;
GO

-- 4.2. Hàm fn_TinhTongChiTieuKhachHang
SELECT
    kh.MaKH,
    CONCAT_WS(N' ', kh.Ho, kh.TenDem, kh.Ten) AS HoTen,
    dbo.fn_TinhTongChiTieuKhachHang(kh.MaKH) AS TongChiTieuDaThanhToan
FROM dbo.KHACH_HANG AS kh
ORDER BY kh.MaKH;
GO

-- ============================================================================
-- BẢNG TỔNG HỢP KẾT QUẢ KIỂM THỬ & ĐỐI CHIẾU DỮ LIỆU MẪU KHÔNG BỊ LỆCH
-- ============================================================================
PRINT N'';
PRINT N'===== TỔNG HỢP KẾT QUẢ DEMO PHONG =====';
SELECT STT, CaThu, MaLoi, KetQua, ThongBao FROM #KetQuaPhong ORDER BY STT;

SELECT
    (SELECT COUNT(*) FROM #KetQuaPhong) AS TongSoCa,
    (SELECT COUNT(*) FROM #KetQuaPhong WHERE KetQua = N'ĐẠT') AS SoCaDat,
    (SELECT COUNT(*) FROM dbo.KHACH_HANG) AS SoKhachHangMau_Mong10,
    (SELECT DiemTichLuy FROM dbo.HOI_VIEN WHERE MaKH = 3) AS DiemMaKH3_Mong50,
    (SELECT COUNT(*) FROM dbo.HOA_DON WHERE MaPhien = 7) AS HoaDonPhien7_Mong0;
GO
