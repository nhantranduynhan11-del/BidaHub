-- sql/99_demo/dung.sql - kịch bản demo RB2 (mở phiên, ghi gọi món), RB7, RB8, RB9, RB10 và fn_DuBaoSoNgayTonKho
--
-- Cách dùng:
--   1. Chạy theo thứ tự: 01_bang, 02_du_lieu, 03_trigger (nhan, phong, thanh, dung, khang), 05_ham.
--   2. Chạy TOÀN BỘ file này; mỗi ca đổi dữ liệu nằm trong TRANSACTION và ROLLBACK nên không làm lệch dữ liệu mẫu.
--   3. Cuối file có bảng tổng hợp: ĐẠT khi mã lỗi đúng như mong đợi, CẦN KIỂM TRA thì xem MaLoi và ThongBao.
--
-- Dữ liệu mẫu dùng trong kịch bản (02_du_lieu/dung.sql):
--   Phiên 1-6 đã thanh toán (phiên 4 chuyển bàn, có hóa đơn), phiên 7-8 đã kết thúc chưa có hóa đơn,
--   phiên 9 (bàn 2) và 10 (bàn 9) đang chơi; bàn 11 đang bảo trì; mặt hàng 4 (Red Bull) còn 3, mặt hàng 9 ngừng bán;
--   nhân viên 8 đã nghỉ và tài khoản bị khóa.

USE BidaHub;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'tempdb..#KetQuaDung') IS NOT NULL DROP TABLE #KetQuaDung;
CREATE TABLE #KetQuaDung
(
    STT     INT IDENTITY(1,1) PRIMARY KEY,
    CaThu   NVARCHAR(120),
    MaLoi   INT NULL,
    ThongBao NVARCHAR(4000) NULL,
    KetQua  NVARCHAR(20)
);
GO

PRINT N'PHẦN 1: RB2 - NHÂN VIÊN ĐÃ NGHỈ HOẶC TÀI KHOẢN BỊ KHÓA';
GO

-- RB2-A: nhân viên 8 mở phiên. Mong đợi: lỗi 50491
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 16:00:00', 8);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB2-A: nhân viên nghỉ mở phiên', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB2-A: nhân viên nghỉ mở phiên', @MaLoi, @Loi, CASE WHEN @MaLoi = 50491 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB2-B: nhân viên 8 ghi gọi món vào phiên đang chơi. Mong đợi: lỗi 50492
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.DONG_GOI_MON (MaPhien, SoThuTuDong, ThoiDiemGoi, SoLuong, DonGiaTaiThoiDiemGoi, MaMatHang, MaNVGhiNhan)
    VALUES (10, 3, '2025-10-25 16:00:00', 1, 10000, 1, 8);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB2-B: nhân viên nghỉ ghi gọi món', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB2-B: nhân viên nghỉ ghi gọi món', @MaLoi, @Loi, CASE WHEN @MaLoi = 50492 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

PRINT N'PHẦN 2: RB7 - SỬ DỤNG BÀN';
GO

-- RB7-A: mở đoạn trên bàn 11 đang bảo trì. Mong đợi: lỗi 50471
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 16:00:00', 3);
    DECLARE @P INT = SCOPE_IDENTITY();
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (@P, 1, '2025-10-25 16:00:00', NULL, 85000, 11, 1, 4);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-A: mở đoạn trên bàn đang bảo trì', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-A: mở đoạn trên bàn đang bảo trì', @MaLoi, @Loi, CASE WHEN @MaLoi = 50471 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB7-B: thêm đoạn kết thúc sau giờ kết thúc của phiên 8 (09:30 - 11:00). Mong đợi: lỗi 50472
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (8, 2, '2025-10-25 11:00:00', '2025-10-25 11:30:00', 160000, 10, 5, 4);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-B: đoạn ngoài thời gian của phiên', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-B: đoạn ngoài thời gian của phiên', @MaLoi, @Loi, CASE WHEN @MaLoi = 50472 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB7-C: phiên 9 đang có đoạn mở ở bàn 2, mở thêm đoạn ở bàn 10 chồng thời gian. Mong đợi: lỗi 50473
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (9, 2, '2025-10-25 15:30:00', NULL, 160000, 10, 5, 4);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-C: hai đoạn của một phiên chồng lấn', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-C: hai đoạn của một phiên chồng lấn', @MaLoi, @Loi, CASE WHEN @MaLoi = 50473 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB7-D: bàn 2 đang có đoạn diễn ra, phiên mới mở thêm đoạn trên bàn 2.
-- Mong đợi: lỗi 2601 (unique index UQ_DoanSuDungBan_BanDangDung chặn trước) hoặc 50474
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 16:00:00', 3);
    DECLARE @P INT = SCOPE_IDENTITY();
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (@P, 1, '2025-10-25 16:00:00', NULL, 85000, 2, 1, 4);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-D: một bàn hai đoạn đang diễn ra', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-D: một bàn hai đoạn đang diễn ra', @MaLoi, @Loi, CASE WHEN @MaLoi IN (2601, 50474) THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB7-E: bàn 1 đã có đoạn 09:05 - 11:20 ngày 20/10 (phiên 2), phiên mới dùng bàn 1 lúc 10:00 - 10:30. Mong đợi: lỗi 50474
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-20 10:00:00', 3);
    DECLARE @P INT = SCOPE_IDENTITY();
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (@P, 1, '2025-10-20 10:00:00', '2025-10-20 10:30:00', 60000, 1, 1, 1);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-E: bàn thuộc hai đoạn chồng lấn', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-E: bàn thuộc hai đoạn chồng lấn', @MaLoi, @Loi, CASE WHEN @MaLoi = 50474 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB7-F: dời giờ bắt đầu phiên 9 sang 15:30, sau giờ bắt đầu đoạn 15:00. Mong đợi: lỗi 50475
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.PHIEN_CHOI SET GioBatDau = '2025-10-25 15:30:00' WHERE MaPhien = 9;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-F: sửa giờ phiên làm đoạn rơi ra ngoài', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-F: sửa giờ phiên làm đoạn rơi ra ngoài', @MaLoi, @Loi, CASE WHEN @MaLoi = 50475 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB7-G: trạng thái bàn tự đổi. Mở đoạn trên bàn 1 thì bàn 1 'Đang chơi', đóng đoạn thì bàn 1 'Trống'
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @TruocMo NVARCHAR(30), @SauMo NVARCHAR(30), @SauDong NVARCHAR(30);
    SELECT @TruocMo = TrangThai FROM dbo.BAN WHERE MaBan = 1;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 16:00:00', 3);
    DECLARE @P INT = SCOPE_IDENTITY();
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (@P, 1, '2025-10-25 16:00:00', NULL, 85000, 1, 1, 4);
    SELECT @SauMo = TrangThai FROM dbo.BAN WHERE MaBan = 1;
    UPDATE dbo.DOAN_SU_DUNG_BAN SET GioKetThucDung = '2025-10-25 16:30:00' WHERE MaPhien = @P AND SoThuTuDoan = 1;
    SELECT @SauDong = TrangThai FROM dbo.BAN WHERE MaBan = 1;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-G: trạng thái bàn theo đoạn sử dụng', NULL,
            N'Trước: ' + @TruocMo + N' | Mở đoạn: ' + @SauMo + N' | Đóng đoạn: ' + @SauDong,
            CASE WHEN @SauMo = N'Đang chơi' AND @SauDong = N'Trống' THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-G: trạng thái bàn theo đoạn sử dụng', @MaLoi, @Loi, N'CẦN KIỂM TRA');
END CATCH;
GO

-- RB7-H: chuyển bàn. Phiên 9 đóng đoạn ở bàn 2 lúc 15:45 và mở đoạn mới ở bàn 1 đúng lúc đó
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.DOAN_SU_DUNG_BAN SET GioKetThucDung = '2025-10-25 15:45:00' WHERE MaPhien = 9 AND SoThuTuDoan = 1;
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (9, 2, '2025-10-25 15:45:00', NULL, 85000, 1, 1, 4);
    DECLARE @Ban2 NVARCHAR(30), @Ban1 NVARCHAR(30);
    SELECT @Ban2 = TrangThai FROM dbo.BAN WHERE MaBan = 2;
    SELECT @Ban1 = TrangThai FROM dbo.BAN WHERE MaBan = 1;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-H: chuyển bàn nối liền', NULL, N'Bàn 2: ' + @Ban2 + N' | Bàn 1: ' + @Ban1,
            CASE WHEN @Ban2 = N'Trống' AND @Ban1 = N'Đang chơi' THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB7-H: chuyển bàn nối liền', @MaLoi, @Loi, N'CẦN KIỂM TRA');
END CATCH;
GO

PRINT N'PHẦN 3: RB8 - ĐƠN GIÁ ÁP DỤNG VÀ CHỐT GIÁ';
GO

-- RB8-A: bàn 1 thuộc loại 1 nhưng đoạn áp dụng khung giá của loại 2. Mong đợi: lỗi 50481
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 16:00:00', 3);
    DECLARE @P INT = SCOPE_IDENTITY();
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (@P, 1, '2025-10-25 16:00:00', NULL, 110000, 1, 2, 4);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-A: khung giá sai loại bàn', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-A: khung giá sai loại bàn', @MaLoi, @Loi, CASE WHEN @MaLoi = 50481 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB8-B: thứ Bảy 25/10 nhưng dùng khung giá 'Ngày thường'. Mong đợi: lỗi 50482
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 10:00:00', 3);
    DECLARE @P INT = SCOPE_IDENTITY();
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (@P, 1, '2025-10-25 10:00:00', NULL, 60000, 3, 1, 1);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-B: khung giá sai loại ngày', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-B: khung giá sai loại ngày', @MaLoi, @Loi, CASE WHEN @MaLoi = 50482 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB8-C: đoạn 17:30 - 18:30 đi qua mốc 18:00 của khung cuối tuần. Mong đợi: lỗi 50483
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 17:30:00', 3);
    DECLARE @P INT = SCOPE_IDENTITY();
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (@P, 1, '2025-10-25 17:30:00', '2025-10-25 18:30:00', 85000, 1, 1, 4);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-C: đoạn đi qua mốc đổi khung giá', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-C: đoạn đi qua mốc đổi khung giá', @MaLoi, @Loi, CASE WHEN @MaLoi = 50483 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB8-D: đơn giá áp dụng 99.999 khác đơn giá khung (85.000). Mong đợi: lỗi 50484
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 16:00:00', 3);
    DECLARE @P INT = SCOPE_IDENTITY();
    INSERT dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung)
    VALUES (@P, 1, '2025-10-25 16:00:00', NULL, 99999, 1, 1, 4);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-D: đơn giá khác đơn giá khung', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-D: đơn giá khác đơn giá khung', @MaLoi, @Loi, CASE WHEN @MaLoi = 50484 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB8-E: sửa đơn giá của đoạn đã ghi. Mong đợi: lỗi 50485
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.DOAN_SU_DUNG_BAN SET DonGiaApDung = 90000 WHERE MaPhien = 9 AND SoThuTuDoan = 1;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-E: sửa đơn giá đã chốt', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-E: sửa đơn giá đã chốt', @MaLoi, @Loi, CASE WHEN @MaLoi = 50485 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB8-F: kết thúc phiên 9 khi đoạn còn mở. Mong đợi: lỗi 50486
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.PHIEN_CHOI SET GioKetThuc = '2025-10-25 17:00:00', TrangThai = N'Đã kết thúc' WHERE MaPhien = 9;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-F: kết thúc phiên khi còn đoạn mở', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-F: kết thúc phiên khi còn đoạn mở', @MaLoi, @Loi, CASE WHEN @MaLoi = 50486 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB8-G: đoạn của phiên 9 đóng lúc 16:00 nhưng phiên kết thúc lúc 17:00 (không phủ kín). Mong đợi: lỗi 50487
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.DOAN_SU_DUNG_BAN SET GioKetThucDung = '2025-10-25 16:00:00' WHERE MaPhien = 9 AND SoThuTuDoan = 1;
    UPDATE dbo.PHIEN_CHOI SET GioKetThuc = '2025-10-25 17:00:00', TrangThai = N'Đã kết thúc' WHERE MaPhien = 9;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-G: các đoạn không phủ kín phiên', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-G: các đoạn không phủ kín phiên', @MaLoi, @Loi, CASE WHEN @MaLoi = 50487 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB8-H: kết thúc phiên đúng quy trình. Đóng đoạn rồi kết thúc phiên 9 cùng lúc 16:00, bàn 2 về 'Trống'
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.DOAN_SU_DUNG_BAN SET GioKetThucDung = '2025-10-25 16:00:00' WHERE MaPhien = 9 AND SoThuTuDoan = 1;
    UPDATE dbo.PHIEN_CHOI SET GioKetThuc = '2025-10-25 16:00:00', TrangThai = N'Đã kết thúc' WHERE MaPhien = 9;
    DECLARE @TrangThaiPhien NVARCHAR(50), @Ban2 NVARCHAR(30), @TienGio DECIMAL(18,2);
    SELECT @TrangThaiPhien = TrangThai FROM dbo.PHIEN_CHOI WHERE MaPhien = 9;
    SELECT @Ban2 = TrangThai FROM dbo.BAN WHERE MaBan = 2;
    SELECT @TienGio = TienGio FROM dbo.DOAN_SU_DUNG_BAN WHERE MaPhien = 9 AND SoThuTuDoan = 1;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-H: kết thúc phiên đúng quy trình', NULL,
            N'Phiên: ' + @TrangThaiPhien + N' | Bàn 2: ' + @Ban2 + N' | TienGio đoạn 1: ' + CAST(@TienGio AS NVARCHAR(30)),
            CASE WHEN @TrangThaiPhien = N'Đã kết thúc' AND @Ban2 = N'Trống' AND @TienGio = 85000 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB8-H: kết thúc phiên đúng quy trình', @MaLoi, @Loi, N'CẦN KIỂM TRA');
END CATCH;
GO

PRINT N'PHẦN 4: RB9 - CÁCH TÍNH TIỀN GIỜ';
GO

-- RB9: phiên 4 có 2 đoạn: 70 phút x 130.000 và 90 phút x 120.000 mỗi giờ.
-- Tiền giờ từng đoạn không làm tròn, tổng 331.666,67 làm tròn thành 331.667 và khớp TienGioChoi của hóa đơn
SELECT N'RB9: tiền giờ phiên 4' AS CaThu,
       d.SoThuTuDoan, d.ThoiLuong AS ThoiLuongGiay, d.DonGiaApDung, d.TienGio
FROM dbo.DOAN_SU_DUNG_BAN AS d
WHERE d.MaPhien = 4
ORDER BY d.SoThuTuDoan;

INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
SELECT N'RB9: tổng tiền giờ phiên 4 làm tròn khớp hóa đơn', NULL,
       N'Tổng đoạn làm tròn: ' + CAST(CAST(ROUND(SUM(d.TienGio), 0) AS DECIMAL(18,0)) AS NVARCHAR(30))
       + N' | TienGioChoi hóa đơn: ' + CAST(CAST(hd.TienGioChoi AS DECIMAL(18,0)) AS NVARCHAR(30)),
       CASE WHEN ROUND(SUM(d.TienGio), 0) = hd.TienGioChoi AND hd.TienGioChoi = 331667 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END
FROM dbo.DOAN_SU_DUNG_BAN AS d
JOIN dbo.HOA_DON AS hd ON hd.MaPhien = d.MaPhien
WHERE d.MaPhien = 4
GROUP BY hd.TienGioChoi;
GO

PRINT N'PHẦN 5: RB10 - GỌI MÓN VÀ TRỪ KHO';
GO

-- RB10-A: gọi mặt hàng 9 đang ngừng bán (tạm đặt tồn 10 để chỉ còn lỗi này). Mong đợi: lỗi 50401
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.MAT_HANG SET SoLuongTon = 10 WHERE MaMatHang = 9;
    INSERT dbo.DONG_GOI_MON (MaPhien, SoThuTuDong, ThoiDiemGoi, SoLuong, DonGiaTaiThoiDiemGoi, MaMatHang, MaNVGhiNhan)
    VALUES (10, 3, '2025-10-25 16:00:00', 1, 20000, 9, 5);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-A: gọi mặt hàng ngừng bán', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-A: gọi mặt hàng ngừng bán', @MaLoi, @Loi, CASE WHEN @MaLoi = 50401 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB10-B: gọi món vào phiên 8 đã kết thúc. Mong đợi: lỗi 50402
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.DONG_GOI_MON (MaPhien, SoThuTuDong, ThoiDiemGoi, SoLuong, DonGiaTaiThoiDiemGoi, MaMatHang, MaNVGhiNhan)
    VALUES (8, 2, '2025-10-25 10:30:00', 1, 10000, 1, 5);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-B: gọi món vào phiên đã kết thúc', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-B: gọi món vào phiên đã kết thúc', @MaLoi, @Loi, CASE WHEN @MaLoi = 50402 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB10-C: đơn giá 9.999 khác đơn giá niêm yết 10.000. Mong đợi: lỗi 50403
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.DONG_GOI_MON (MaPhien, SoThuTuDong, ThoiDiemGoi, SoLuong, DonGiaTaiThoiDiemGoi, MaMatHang, MaNVGhiNhan)
    VALUES (10, 3, '2025-10-25 16:00:00', 1, 9999, 1, 5);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-C: đơn giá khác giá niêm yết', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-C: đơn giá khác giá niêm yết', @MaLoi, @Loi, CASE WHEN @MaLoi = 50403 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB10-D: ghi dòng gọi món mới với trạng thái 'Đã hủy'. Mong đợi: lỗi 50404
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.DONG_GOI_MON (MaPhien, SoThuTuDong, ThoiDiemGoi, SoLuong, DonGiaTaiThoiDiemGoi, TrangThaiPhucVu, MaMatHang, MaNVGhiNhan)
    VALUES (10, 3, '2025-10-25 16:00:00', 1, 10000, N'Đã hủy', 1, 5);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-D: dòng gọi món mới đã hủy', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-D: dòng gọi món mới đã hủy', @MaLoi, @Loi, CASE WHEN @MaLoi = 50404 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB10-E: gọi 4 Red Bull trong khi chỉ còn 3. Mong đợi: lỗi 50408
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.DONG_GOI_MON (MaPhien, SoThuTuDong, ThoiDiemGoi, SoLuong, DonGiaTaiThoiDiemGoi, MaMatHang, MaNVGhiNhan)
    VALUES (10, 3, '2025-10-25 16:00:00', 4, 20000, 4, 5);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-E: gọi vượt số lượng tồn', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-E: gọi vượt số lượng tồn', @MaLoi, @Loi, CASE WHEN @MaLoi = 50408 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB10-F: gọi 2 Red Bull thì tồn 3 giảm còn 1; hủy dòng đang chờ chế biến thì tồn hoàn lại 3
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Ton0 INT, @Ton1 INT, @Ton2 INT;
    SELECT @Ton0 = SoLuongTon FROM dbo.MAT_HANG WHERE MaMatHang = 4;
    INSERT dbo.DONG_GOI_MON (MaPhien, SoThuTuDong, ThoiDiemGoi, SoLuong, DonGiaTaiThoiDiemGoi, MaMatHang, MaNVGhiNhan)
    VALUES (10, 3, '2025-10-25 16:00:00', 2, 20000, 4, 5);
    SELECT @Ton1 = SoLuongTon FROM dbo.MAT_HANG WHERE MaMatHang = 4;
    UPDATE dbo.DONG_GOI_MON SET TrangThaiPhucVu = N'Đã hủy' WHERE MaPhien = 10 AND SoThuTuDong = 3;
    SELECT @Ton2 = SoLuongTon FROM dbo.MAT_HANG WHERE MaMatHang = 4;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-F: trừ kho khi gọi, hoàn kho khi hủy', NULL,
            N'Tồn: ' + CAST(@Ton0 AS NVARCHAR(10)) + N' -> ' + CAST(@Ton1 AS NVARCHAR(10)) + N' -> ' + CAST(@Ton2 AS NVARCHAR(10)),
            CASE WHEN @Ton0 = 3 AND @Ton1 = 1 AND @Ton2 = 3 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-F: trừ kho khi gọi, hoàn kho khi hủy', @MaLoi, @Loi, N'CẦN KIỂM TRA');
END CATCH;
GO

-- RB10-G: xóa dòng gọi món. Mong đợi: lỗi 50405
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.DONG_GOI_MON WHERE MaPhien = 10 AND SoThuTuDong = 1;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-G: xóa dòng gọi món', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-G: xóa dòng gọi món', @MaLoi, @Loi, CASE WHEN @MaLoi = 50405 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB10-H: sửa số lượng của dòng đã ghi. Mong đợi: lỗi 50406
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.DONG_GOI_MON SET SoLuong = 5 WHERE MaPhien = 10 AND SoThuTuDong = 1;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-H: sửa số lượng dòng đã ghi', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-H: sửa số lượng dòng đã ghi', @MaLoi, @Loi, CASE WHEN @MaLoi = 50406 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

-- RB10-I: hủy dòng đã phục vụ (phiên 9, dòng 1). Mong đợi: lỗi 50407
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.DONG_GOI_MON SET TrangThaiPhucVu = N'Đã hủy' WHERE MaPhien = 9 AND SoThuTuDong = 1;
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-I: hủy dòng đã phục vụ', NULL, N'Lệnh sai không bị chặn', N'KHÔNG ĐẠT');
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'RB10-I: hủy dòng đã phục vụ', @MaLoi, @Loi, CASE WHEN @MaLoi = 50407 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END CATCH;
GO

PRINT N'PHẦN 6: HÀM fn_DuBaoSoNgayTonKho (CON TRỎ, KỲ XÉT 7 NGÀY KẾT THÚC NGÀY 25/10/2025)';
GO

-- Dự báo số ngày còn bán được của từng mặt hàng; số âm là mã lỗi (-3: ngừng bán, -4: không có lịch sử bán)
SELECT mh.MaMatHang, mh.TenMatHang, mh.SoLuongTon,
       dbo.fn_DuBaoSoNgayTonKho(mh.MaMatHang, 7, NULL) AS SoNgayDuBao
FROM dbo.MAT_HANG AS mh
ORDER BY CASE WHEN dbo.fn_DuBaoSoNgayTonKho(mh.MaMatHang, 7, NULL) < 0 THEN 1 ELSE 0 END,
         dbo.fn_DuBaoSoNgayTonKho(mh.MaMatHang, 7, NULL), mh.MaMatHang;
GO

INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
SELECT v.CaThu, NULL,
       N'Mong đợi: ' + CAST(v.MongDoi AS NVARCHAR(20)) + N' | Hàm trả: ' + CAST(dbo.fn_DuBaoSoNgayTonKho(v.MaMatHang, v.SoNgay, v.NgayTC) AS NVARCHAR(20)),
       CASE WHEN dbo.fn_DuBaoSoNgayTonKho(v.MaMatHang, v.SoNgay, v.NgayTC) = v.MongDoi THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END
FROM (VALUES
    (N'HAM-A: thuê gậy, tồn 8, bán 2 trong 7 ngày',        13,   7, CAST(NULL AS DATE), CAST(28.0   AS DECIMAL(18,1))),
    (N'HAM-B: bia Tiger, tồn 132, bán 12 trong 7 ngày',     7,   7, CAST(NULL AS DATE), CAST(77.0   AS DECIMAL(18,1))),
    (N'HAM-C: bia Tiger, kỳ xét 3 ngày (bán 6)',            7,   3, CAST(NULL AS DATE), CAST(66.0   AS DECIMAL(18,1))),
    (N'HAM-D: bia Tiger, ngày tham chiếu 22/10 (bán 6)',    7,   4, CAST('2025-10-22' AS DATE), CAST(88.0 AS DECIMAL(18,1))),
    (N'HAM-E: mã mặt hàng không tồn tại',                 9999,  7, CAST(NULL AS DATE), CAST(-1.0   AS DECIMAL(18,1))),
    (N'HAM-F: số ngày xét bằng 0',                           1,   0, CAST(NULL AS DATE), CAST(-2.0   AS DECIMAL(18,1))),
    (N'HAM-G: số ngày xét vượt 365',                         1, 366, CAST(NULL AS DATE), CAST(-2.0   AS DECIMAL(18,1))),
    (N'HAM-H: mặt hàng 9 đã ngừng bán',                      9,   7, CAST(NULL AS DATE), CAST(-3.0   AS DECIMAL(18,1))),
    (N'HAM-I: Red Bull không có lịch sử bán trong kỳ',       4,   7, CAST(NULL AS DATE), CAST(-4.0   AS DECIMAL(18,1)))
) AS v(CaThu, MaMatHang, SoNgay, NgayTC, MongDoi);
GO

-- HAM-J: tồn bằng 0 thì dự báo 0 ngày (tạm đặt tồn của Aquafina bằng 0, rồi ROLLBACK)
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.MAT_HANG SET SoLuongTon = 0 WHERE MaMatHang = 1;
    DECLARE @KetQua DECIMAL(18,1) = dbo.fn_DuBaoSoNgayTonKho(1, 7, NULL);
    ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'HAM-J: hết hàng thì dự báo 0 ngày', NULL, N'Hàm trả: ' + CAST(@KetQua AS NVARCHAR(20)),
            CASE WHEN @KetQua = 0 THEN N'ĐẠT' ELSE N'CẦN KIỂM TRA' END);
END TRY
BEGIN CATCH
    DECLARE @MaLoi INT = ERROR_NUMBER(), @Loi NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    INSERT #KetQuaDung (CaThu, MaLoi, ThongBao, KetQua)
    VALUES (N'HAM-J: hết hàng thì dự báo 0 ngày', @MaLoi, @Loi, N'CẦN KIỂM TRA');
END CATCH;
GO

PRINT N'TỔNG HỢP KẾT QUẢ';
GO

SELECT STT, CaThu, MaLoi, ThongBao, KetQua FROM #KetQuaDung ORDER BY STT;

SELECT SUM(CASE WHEN KetQua = N'ĐẠT' THEN 1 ELSE 0 END) AS SoCaDat,
       SUM(CASE WHEN KetQua <> N'ĐẠT' THEN 1 ELSE 0 END) AS SoCaCanKiemTra,
       COUNT(*) AS TongSoCa
FROM #KetQuaDung;
GO
