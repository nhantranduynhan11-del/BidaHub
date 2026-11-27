-- ============================================================================
-- sql/99_demo/nhan.sql (Nhân): kịch bản minh họa trigger 1 (RB1) của mục 2.2.1 và kiểm tra RB1-RB3
--
-- Chạy sau: init.sql -> 01_bang/tao_tat_ca_bang.sql -> 02_du_lieu/nap_tat_ca_du_lieu.sql
--           -> 03_trigger/tao_tat_ca_trigger.sql (hoặc chỉ 03_trigger/nhan.sql).
-- Mỗi ca thử nằm trong một giao tác rồi ROLLBACK, nên chạy bao nhiêu lần dữ liệu mẫu cũng không đổi.
-- Kết quả xem ở tab Messages (mỗi ca một dòng ĐẠT / KHÔNG ĐẠT); bảng kết quả SELECT ở tab Results.
-- Khi báo cáo có thể bôi đen và chạy (F5) từng khối giữa hai dòng GO.
--
--   Phần A. Dữ liệu mẫu thỏa RB1-RB3 (dữ liệu nạp trước khi có trigger nên phải tự kiểm tra)
--   Phần B. Trigger 1 (RB1): các thao tác DML vi phạm bị chặn, mỗi ca một mã lỗi
--   Phần C. Trigger 1 (RB1): các thao tác hợp lệ vẫn đi được (trigger không chặn nhầm)
--   Phần D. RB2, RB3: một ca cho mỗi mã lỗi còn lại của Nhân
--
-- Dữ liệu mẫu dùng trong các ca:
--   TK 1 quanly.minh  - NV 1, Quản lý, vai trò Quản lý + Thu ngân, đỉnh cây giám sát
--   TK 2 quanly.huong - NV 2, Quản lý, vai trò Quản lý, do NV 1 giám sát, giám sát NV 4, 5, 7, 8, 9, 11
--   TK 3 thungan.lan  - NV 3, Thu ngân, vai trò Thu ngân
--   TK 8 phucvu.vy    - NV 8, đã nghỉ, tài khoản bị khóa
--   TK 9 phucvu.tuan  - NV 9, Phục vụ, vai trò Phục vụ
--   TK 12 tranbinh92  - hội viên MaKH 1, vai trò Hội viên;  TK 16 hoangyen.hv - hội viên MaKH 5
-- ============================================================================
USE BidaHub;
GO
SET NOCOUNT ON;
GO

-- In kết quả của một ca mong đợi bị chặn; gọi trong khối CATCH (ERROR_NUMBER() vẫn đọc được trong thủ tục được gọi).
-- Thủ tục tạm (#) tự mất khi đóng kết nối, không để lại gì trong CSDL.
CREATE OR ALTER PROCEDURE #KetQua @Ca NVARCHAR(200), @MaMongDoi INT
AS
BEGIN
    PRINT CONCAT(CASE WHEN ERROR_NUMBER() = @MaMongDoi THEN N'  ĐẠT        ' ELSE N'  KHÔNG ĐẠT  ' END,
                 @Ca, N'  ->  lỗi ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END
GO

-- ############################################################################
-- PHẦN A. DỮ LIỆU MẪU THỎA RB1-RB3
-- ############################################################################
PRINT N'===== PHẦN A. Dữ liệu mẫu thỏa RB1-RB3 =====';

-- A1 (RB1). Không tài khoản nào thuộc cả nhân viên lẫn hội viên; liệt kê tài khoản chưa có chủ (nếu có).
DECLARE @CaHai INT = (SELECT COUNT(*) FROM dbo.TAI_KHOAN tk
                      WHERE EXISTS (SELECT 1 FROM dbo.NHAN_VIEN nv WHERE nv.MaTK = tk.MaTK)
                        AND EXISTS (SELECT 1 FROM dbo.HOI_VIEN hv WHERE hv.MaTK = tk.MaTK));
DECLARE @MoCoi INT = (SELECT COUNT(*) FROM dbo.TAI_KHOAN tk
                      WHERE NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN nv WHERE nv.MaTK = tk.MaTK)
                        AND NOT EXISTS (SELECT 1 FROM dbo.HOI_VIEN hv WHERE hv.MaTK = tk.MaTK));
PRINT CONCAT(CASE WHEN @CaHai = 0 AND @MoCoi = 0 THEN N'  ĐẠT        ' ELSE N'  KHÔNG ĐẠT  ' END,
             N'A1 mỗi tài khoản thuộc đúng một chủ: ', @CaHai, N' tài khoản thuộc cả hai, ', @MoCoi, N' tài khoản chưa có chủ');

SELECT tk.MaTK, tk.TenDangNhap, tk.TrangThai,
       CASE WHEN nv.MaNV IS NOT NULL THEN CONCAT(N'Nhân viên ', nv.MaNV, N' (', nv.ChucVu, N')')
            WHEN hv.MaKH IS NOT NULL THEN CONCAT(N'Hội viên ', hv.MaKH) ELSE N'(chưa có chủ)' END AS ChuTaiKhoan,
       (SELECT STRING_AGG(vt.TenVaiTro, N', ') FROM dbo.DUOC_CAP dc JOIN dbo.VAI_TRO vt ON vt.MaVaiTro = dc.MaVaiTro
        WHERE dc.MaTK = tk.MaTK) AS VaiTro
FROM dbo.TAI_KHOAN tk
LEFT JOIN dbo.NHAN_VIEN nv ON nv.MaTK = tk.MaTK
LEFT JOIN dbo.HOI_VIEN hv  ON hv.MaTK = tk.MaTK
ORDER BY tk.MaTK;

-- A2 (RB1). Vai trò được cấp đúng loại chủ: danh sách vi phạm v_VaiTroSaiChu phải rỗng.
DECLARE @SaiVaiTro INT = (SELECT COUNT(*) FROM dbo.v_VaiTroSaiChu);
PRINT CONCAT(CASE WHEN @SaiVaiTro = 0 THEN N'  ĐẠT        ' ELSE N'  KHÔNG ĐẠT  ' END,
             N'A2 vai trò cấp đúng loại chủ: ', @SaiVaiTro, N' cặp (tài khoản, vai trò) sai');

-- A3 (RB2). Còn ít nhất một tài khoản quản lý đang hoạt động.
DECLARE @SoQuanLy INT = (SELECT COUNT(*) FROM dbo.v_QuanLyHoatDong);
PRINT CONCAT(CASE WHEN @SoQuanLy >= 1 THEN N'  ĐẠT        ' ELSE N'  KHÔNG ĐẠT  ' END,
             N'A3 số quản lý đang hoạt động: ', @SoQuanLy);

-- A4 (RB3). Người giám sát là Quản lý, không ai tự giám sát, không có vòng giám sát, ai cũng đủ 18 tuổi lúc vào làm.
DECLARE @SaiGiamSat INT = (SELECT COUNT(*) FROM dbo.NHAN_VIEN nv JOIN dbo.NHAN_VIEN gs ON gs.MaNV = nv.MaNVGiamSat
                           WHERE gs.ChucVu <> N'Quản lý' OR gs.MaNV = nv.MaNV);
DECLARE @ChuaDu18 INT = (SELECT COUNT(*) FROM dbo.NHAN_VIEN WHERE DATEADD(YEAR, 18, NgaySinh) > NgayVaoLam);
DECLARE @SoNV INT = (SELECT COUNT(*) FROM dbo.NHAN_VIEN), @CoVong INT;
WITH Chuoi AS (
    SELECT MaNV AS Goc, MaNVGiamSat AS Cur, 1 AS Buoc FROM dbo.NHAN_VIEN WHERE MaNVGiamSat IS NOT NULL
    UNION ALL
    SELECT c.Goc, nv.MaNVGiamSat, c.Buoc + 1
    FROM Chuoi c JOIN dbo.NHAN_VIEN nv ON nv.MaNV = c.Cur
    WHERE nv.MaNVGiamSat IS NOT NULL AND c.Cur <> c.Goc AND c.Buoc < @SoNV
)
SELECT @CoVong = COUNT(*) FROM Chuoi WHERE Cur = Goc OR Buoc >= @SoNV OPTION (MAXRECURSION 0);
PRINT CONCAT(CASE WHEN @SaiGiamSat = 0 AND @ChuaDu18 = 0 AND @CoVong = 0 THEN N'  ĐẠT        ' ELSE N'  KHÔNG ĐẠT  ' END,
             N'A4 giám sát và tuổi: ', @SaiGiamSat, N' người giám sát sai, ', @CoVong, N' vòng lặp, ', @ChuaDu18, N' nhân viên chưa đủ 18 tuổi');
GO

-- ############################################################################
-- PHẦN B. TRIGGER 1 (RB1): THAO TÁC VI PHẠM BỊ CHẶN
--
-- Ràng buộc RB1: mỗi tài khoản thuộc đúng một nhân viên hoặc đúng một hội viên, không thuộc đồng thời cả hai;
--   vai trò "Quản lý" chỉ cấp cho tài khoản của nhân viên có chức vụ Quản lý, vai trò "Hội viên" chỉ cấp cho
--   tài khoản của hội viên, các vai trò còn lại chỉ cấp cho tài khoản của nhân viên.
-- Thao tác DML có thể vi phạm và trigger bắt (tên trigger theo 03_trigger/tao_tat_ca_trigger.sql):
--   DUOC_CAP  INSERT, UPDATE(MaTK, MaVaiTro)          trg_DUOC_CAP_RB1_KiemTraVaiTro   50101, 50102, 50103   (B1-B4, B12)
--   NHAN_VIEN INSERT, UPDATE(MaTK, ChucVu), DELETE    trg_NHAN_VIEN_RB1_TaiKhoan       50104, 50105, 50112   (B5, B6, B9)
--   HOI_VIEN  INSERT, UPDATE(MaTK), DELETE            trg_HOI_VIEN_RB1_TaiKhoan        50106, 50112          (B7, B8, B10, B11)
--   VAI_TRO   UPDATE(TenVaiTro)                       trg_VAI_TRO_RB1_KhongDoiTen      50113                 (B13)
-- ############################################################################
PRINT N'';
PRINT N'===== PHẦN B. Trigger 1 (RB1): thao tác vi phạm bị chặn =====';
GO

-- B1. INSERT DUOC_CAP: cấp vai trò Quản lý cho tài khoản thu ngân thungan.lan (NV 3)
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.DUOC_CAP (MaTK, MaVaiTro) SELECT 3, MaVaiTro FROM dbo.VAI_TRO WHERE TenVaiTro = N'Quản lý';
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B1 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B1 cấp vai trò Quản lý cho tài khoản thu ngân', 50101; END CATCH;
GO

-- B2. INSERT DUOC_CAP: cấp vai trò Hội viên cho tài khoản nhân viên thungan.lan
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.DUOC_CAP (MaTK, MaVaiTro) SELECT 3, MaVaiTro FROM dbo.VAI_TRO WHERE TenVaiTro = N'Hội viên';
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B2 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B2 cấp vai trò Hội viên cho tài khoản nhân viên', 50102; END CATCH;
GO

-- B3. INSERT DUOC_CAP: cấp vai trò Thu ngân cho tài khoản hội viên tranbinh92 (MaKH 1)
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.DUOC_CAP (MaTK, MaVaiTro) SELECT 12, MaVaiTro FROM dbo.VAI_TRO WHERE TenVaiTro = N'Thu ngân';
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B3 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B3 cấp vai trò Thu ngân cho tài khoản hội viên', 50103; END CATCH;
GO

-- B4. UPDATE DUOC_CAP: đổi vai trò Thu ngân của thungan.lan thành Quản lý (đường UPDATE, không phải INSERT)
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dc SET dc.MaVaiTro = (SELECT MaVaiTro FROM dbo.VAI_TRO WHERE TenVaiTro = N'Quản lý')
    FROM dbo.DUOC_CAP dc JOIN dbo.VAI_TRO vt ON vt.MaVaiTro = dc.MaVaiTro
    WHERE dc.MaTK = 3 AND vt.TenVaiTro = N'Thu ngân';
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B4 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B4 đổi vai trò Thu ngân thành Quản lý bằng UPDATE', 50101; END CATCH;
GO

-- B5. UPDATE NHAN_VIEN: gán tài khoản của hội viên (tranbinh92) cho nhân viên NV 5
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.NHAN_VIEN SET MaTK = 12 WHERE MaNV = 5;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B5 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B5 gán tài khoản hội viên cho nhân viên', 50104; END CATCH;
GO

-- B6. UPDATE NHAN_VIEN: hạ NV 2 xuống Thu ngân khi tài khoản vẫn còn vai trò Quản lý
--     (chuyển trước cấp dưới của NV 2 sang NV 1 để ca này chỉ vi phạm RB1, không vi phạm RB3)
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.NHAN_VIEN SET MaNVGiamSat = 1 WHERE MaNVGiamSat = 2;
    UPDATE dbo.NHAN_VIEN SET ChucVu = N'Thu ngân' WHERE MaNV = 2;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B6 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B6 hạ chức vụ quản lý khi tài khoản còn vai trò Quản lý', 50105; END CATCH;
GO

-- B7. UPDATE HOI_VIEN: gán tài khoản của nhân viên (thungan.lan) cho hội viên MaKH 1
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.HOI_VIEN SET MaTK = 3 WHERE MaKH = 1;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B7 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B7 gán tài khoản nhân viên cho hội viên', 50106; END CATCH;
GO

-- B8. UPDATE HOI_VIEN: gỡ tài khoản tranbinh92 khỏi hội viên MaKH 1 khi tài khoản còn vai trò Hội viên
--     (nếu lọt, tài khoản 12 mang vai trò Hội viên mà không thuộc hội viên nào, rồi có thể gán cho nhân viên)
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.HOI_VIEN SET MaTK = NULL WHERE MaKH = 1;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B8 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B8 gỡ tài khoản khỏi hội viên khi còn vai trò Hội viên', 50112; END CATCH;
GO

-- B9. UPDATE NHAN_VIEN: đổi NV 9 sang tài khoản mới, tài khoản cũ phucvu.tuan bị bỏ lại vẫn còn vai trò Phục vụ
--     (trigger phải nhìn bảng deleted mới thấy tài khoản cũ)
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.TAI_KHOAN (TenDangNhap, MatKhau, Email)
    VALUES (N'phucvu.tuan2', REPLICATE('a', 64), N'phucvu.tuan2@bidahub.vn');
    UPDATE dbo.NHAN_VIEN SET MaTK = SCOPE_IDENTITY() WHERE MaNV = 9;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B9 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B9 đổi tài khoản nhân viên, tài khoản cũ còn vai trò', 50112; END CATCH;
GO

-- B10. DELETE HOI_VIEN: xóa hội viên MaKH 5 khi tài khoản hoangyen.hv còn vai trò Hội viên
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.HOI_VIEN WHERE MaKH = 5;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B10 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B10 xóa hội viên khi tài khoản còn vai trò Hội viên', 50112; END CATCH;
GO

-- B11. DELETE KHACH_HANG: xóa khách hàng thì HOI_VIEN bị xóa dây chuyền (ON DELETE CASCADE), trigger trên HOI_VIEN vẫn chạy
--      (tạo khách thử mới để không vướng phiên chơi, phiếu đặt bàn của khách có sẵn)
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @MaKH INT, @MaTK INT;
    INSERT INTO dbo.KHACH_HANG (Ho, Ten) VALUES (N'Thử', N'Dây Chuyền');
    SET @MaKH = SCOPE_IDENTITY();
    INSERT INTO dbo.TAI_KHOAN (TenDangNhap, MatKhau, Email) VALUES (N'thu.daychuyen', REPLICATE('b', 64), N'thu.daychuyen@bidahub.vn');
    SET @MaTK = SCOPE_IDENTITY();
    INSERT INTO dbo.HOI_VIEN (MaKH, MaHang, MaTK) VALUES (@MaKH, 1, @MaTK);
    INSERT INTO dbo.DUOC_CAP (MaTK, MaVaiTro) SELECT @MaTK, MaVaiTro FROM dbo.VAI_TRO WHERE TenVaiTro = N'Hội viên';
    DELETE FROM dbo.KHACH_HANG WHERE MaKH = @MaKH;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B11 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B11 xóa khách hàng, hội viên bị xóa dây chuyền khi còn vai trò', 50112; END CATCH;
GO

-- B12. Một lệnh INSERT nhiều dòng: (thungan.lan, Phục vụ) hợp lệ và (thungan.lan, Quản lý) sai.
--      Trigger chạy một lần cho cả lệnh: cả lệnh bị hủy, dòng hợp lệ cũng không được ghi.
DECLARE @CoPhucVu INT;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.DUOC_CAP (MaTK, MaVaiTro)
    SELECT 3, MaVaiTro FROM dbo.VAI_TRO WHERE TenVaiTro IN (N'Phục vụ', N'Quản lý');
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B12 lệnh sai không bị chặn';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    EXEC #KetQua N'B12 lệnh nhiều dòng có một dòng sai', 50101;
    SELECT @CoPhucVu = COUNT(*) FROM dbo.DUOC_CAP dc JOIN dbo.VAI_TRO vt ON vt.MaVaiTro = dc.MaVaiTro
    WHERE dc.MaTK = 3 AND vt.TenVaiTro = N'Phục vụ';
    PRINT CONCAT(N'             sau lệnh: thungan.lan có vai trò Phục vụ? ', CASE WHEN @CoPhucVu = 0 THEN N'không (cả lệnh đã bị hủy)' ELSE N'CÓ (sai)' END);
END CATCH;
GO

-- B13. UPDATE VAI_TRO: đổi tên vai trò Quản lý (đổi nghĩa vai trò của mọi tài khoản đã được cấp)
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE dc FROM dbo.DUOC_CAP dc JOIN dbo.VAI_TRO vt ON vt.MaVaiTro = dc.MaVaiTro WHERE vt.TenVaiTro = N'Pha chế';
    DELETE FROM dbo.VAI_TRO WHERE TenVaiTro = N'Pha chế';       -- nhường tên "Pha chế" để không vướng UNIQUE
    UPDATE dbo.VAI_TRO SET TenVaiTro = N'Pha chế' WHERE TenVaiTro = N'Quản lý';
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  B13 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'B13 đổi tên vai trò Quản lý', 50113; END CATCH;
GO

-- ############################################################################
-- PHẦN C. TRIGGER 1 (RB1): THAO TÁC HỢP LỆ VẪN ĐI ĐƯỢC
-- ############################################################################
PRINT N'';
PRINT N'===== PHẦN C. Trigger 1 (RB1): thao tác hợp lệ vẫn đi được =====';
GO

-- C1. Thêm nhân viên mới đúng thứ tự: tài khoản -> nhân viên -> vai trò đúng chức vụ
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @MaTK INT, @MaNV INT;
    INSERT INTO dbo.TAI_KHOAN (TenDangNhap, MatKhau, Email)
    VALUES (N'thungan.moi', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'thungan.moi@bidahub.vn');
    SET @MaTK = SCOPE_IDENTITY();
    INSERT INTO dbo.NHAN_VIEN (Ho, TenDem, Ten, NgaySinh, GioiTinh, SoNha, Duong, PhuongXa, QuanHuyen, TinhThanhPho,
                               SoDienThoai, ChucVu, NgayVaoLam, MaTK, MaNVGiamSat)
    VALUES (N'Lê', N'Thị', N'Mới', '2003-05-10', N'Nữ', N'12', N'Lý Thường Kiệt', N'Phường 14', N'Quận 10', N'TP. Hồ Chí Minh',
            '0912345678', N'Thu ngân', '2025-11-01', @MaTK, 1);
    SET @MaNV = SCOPE_IDENTITY();
    INSERT INTO dbo.DUOC_CAP (MaTK, MaVaiTro) SELECT @MaTK, MaVaiTro FROM dbo.VAI_TRO WHERE TenVaiTro = N'Thu ngân';

    SELECT N'C1' AS Ca, nv.MaNV, nv.Ho + N' ' + ISNULL(nv.TenDem + N' ', N'') + nv.Ten AS HoTen, nv.ChucVu,
           tk.TenDangNhap, vt.TenVaiTro
    FROM dbo.NHAN_VIEN nv JOIN dbo.TAI_KHOAN tk ON tk.MaTK = nv.MaTK
    JOIN dbo.DUOC_CAP dc ON dc.MaTK = tk.MaTK JOIN dbo.VAI_TRO vt ON vt.MaVaiTro = dc.MaVaiTro
    WHERE nv.MaNV = @MaNV;
    ROLLBACK TRANSACTION;
    PRINT N'  ĐẠT        C1 thêm nhân viên mới kèm tài khoản và vai trò Thu ngân';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT CONCAT(N'  KHÔNG ĐẠT  C1 bị chặn nhầm  ->  lỗi ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
GO

-- C2. Hạ NV 2 xuống Thu ngân đúng quy trình; mỗi lệnh đều để CSDL ở trạng thái hợp lệ
--     (trigger kiểm tra sau từng lệnh, SQL Server không có ràng buộc hoãn tới cuối giao tác nên thứ tự quan trọng)
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.NHAN_VIEN SET MaNVGiamSat = 1 WHERE MaNVGiamSat = 2;                      -- 1. chuyển cấp dưới sang NV 1
    DELETE dc FROM dbo.DUOC_CAP dc JOIN dbo.VAI_TRO vt ON vt.MaVaiTro = dc.MaVaiTro
    WHERE dc.MaTK = 2 AND vt.TenVaiTro = N'Quản lý';                                   -- 2. gỡ vai trò Quản lý
    UPDATE dbo.NHAN_VIEN SET ChucVu = N'Thu ngân' WHERE MaNV = 2;                       -- 3. đổi chức vụ
    INSERT INTO dbo.DUOC_CAP (MaTK, MaVaiTro) SELECT 2, MaVaiTro FROM dbo.VAI_TRO WHERE TenVaiTro = N'Thu ngân';  -- 4. cấp vai trò mới

    SELECT N'C2' AS Ca, nv.MaNV, nv.ChucVu, tk.TenDangNhap,
           (SELECT STRING_AGG(vt.TenVaiTro, N', ') FROM dbo.DUOC_CAP dc JOIN dbo.VAI_TRO vt ON vt.MaVaiTro = dc.MaVaiTro
            WHERE dc.MaTK = tk.MaTK) AS VaiTro,
           (SELECT COUNT(*) FROM dbo.v_QuanLyHoatDong) AS SoQuanLyConLai
    FROM dbo.NHAN_VIEN nv JOIN dbo.TAI_KHOAN tk ON tk.MaTK = nv.MaTK WHERE nv.MaNV = 2;
    ROLLBACK TRANSACTION;
    PRINT N'  ĐẠT        C2 hạ chức vụ quản lý theo đúng 4 bước';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT CONCAT(N'  KHÔNG ĐẠT  C2 bị chặn nhầm  ->  lỗi ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
GO

-- C3. Gỡ vai trò Hội viên của hoangyen.hv trước rồi mới xóa hội viên MaKH 5 (quy trình đúng của B10)
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.DUOC_CAP WHERE MaTK = 16;
    DELETE FROM dbo.HOI_VIEN WHERE MaKH = 5;
    ROLLBACK TRANSACTION;
    PRINT N'  ĐẠT        C3 gỡ vai trò rồi xóa hội viên';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT CONCAT(N'  KHÔNG ĐẠT  C3 bị chặn nhầm  ->  lỗi ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
GO

-- C4. Sửa cột không liên quan RB1 (số điện thoại nhân viên, điểm hội viên): trigger thoát sớm nhờ UPDATE(cột)
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.NHAN_VIEN SET SoDienThoai = '0900000000' WHERE MaNV = 3;
    UPDATE dbo.HOI_VIEN SET DiemTichLuy = DiemTichLuy + 1 WHERE MaKH = 1;
    ROLLBACK TRANSACTION;
    PRINT N'  ĐẠT        C4 sửa cột không liên quan RB1';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT CONCAT(N'  KHÔNG ĐẠT  C4 bị chặn nhầm  ->  lỗi ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
GO

-- ############################################################################
-- PHẦN D. RB2, RB3: MỘT CA CHO MỖI MÃ LỖI CÒN LẠI CỦA NHÂN
-- ############################################################################
PRINT N'';
PRINT N'===== PHẦN D. RB2, RB3 =====';
GO

-- D1 (RB2). Khóa cả hai tài khoản quản lý: hệ thống phải còn ít nhất một quản lý đang hoạt động
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.TAI_KHOAN SET TrangThai = N'Bị khóa' WHERE MaTK IN (1, 2);
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  D1 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'D1 khóa quản lý cuối cùng', 50107; END CATCH;
GO

-- D2 (RB2). Nhân viên đã nghỉ (NV 8, tài khoản bị khóa) mở phiên chơi.
--     Trigger trg_PHIEN_CHOI_RB2_NhanVienMoPhien (50111) chỉ có trong file ghép 03_trigger/tao_tat_ca_trigger.sql,
--     nên ca này tự bỏ qua khi mới nạp 03_trigger/nhan.sql.
IF OBJECT_ID(N'dbo.trg_PHIEN_CHOI_RB2_NhanVienMoPhien', N'TR') IS NULL
    PRINT N'  (bỏ qua)   D2 cần chạy 03_trigger/tao_tat_ca_trigger.sql trước';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.PHIEN_CHOI (GioBatDau, MaNVMoPhien) VALUES ('2025-10-25 16:00', 8);
        ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  D2 lệnh sai không bị chặn';
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'D2 nhân viên đã nghỉ mở phiên chơi', 50111; END CATCH;
END
GO

-- D3 (RB3). Người giám sát của NV 5 là thu ngân NV 3
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.NHAN_VIEN SET MaNVGiamSat = 3 WHERE MaNV = 5;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  D3 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'D3 người giám sát không phải Quản lý', 50108; END CATCH;
GO

-- D4 (RB3). Hạ NV 2 xuống Thu ngân khi NV 2 vẫn đang giám sát người khác
--     (gỡ vai trò Quản lý trước để ca này chỉ vi phạm RB3, không vi phạm RB1)
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE dc FROM dbo.DUOC_CAP dc JOIN dbo.VAI_TRO vt ON vt.MaVaiTro = dc.MaVaiTro
    WHERE dc.MaTK = 2 AND vt.TenVaiTro = N'Quản lý';
    UPDATE dbo.NHAN_VIEN SET ChucVu = N'Thu ngân' WHERE MaNV = 2;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  D4 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'D4 hạ chức người đang giám sát người khác', 50109; END CATCH;
GO

-- D5 (RB3). Vòng giám sát 1 -> 2 -> 1: cho NV 1 do NV 2 giám sát (NV 2 đang do NV 1 giám sát)
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.NHAN_VIEN SET MaNVGiamSat = 2 WHERE MaNV = 1;
    ROLLBACK TRANSACTION; PRINT N'  KHÔNG ĐẠT  D5 lệnh sai không bị chặn';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; EXEC #KetQua N'D5 vòng giám sát 1 -> 2 -> 1', 50110; END CATCH;
GO

PRINT N'';
PRINT N'Xong 99_demo/nhan.sql. Mọi ca đã ROLLBACK, dữ liệu mẫu không đổi.';
GO
