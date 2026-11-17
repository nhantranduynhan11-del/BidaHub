-- ============================================================================
-- Hệ thống Quản lý Quán Bida - BidaHub
-- Phần việc thành viên: Đào Huy Phong (MSSV: 2412628)
-- File: sql/99_demo/phong.sql
-- Mô tả: Kịch bản kiểm thử toàn diện phục vụ báo cáo và chấm điểm BTL2:
--        PHẦN 1: TRIGGER RB15 (Cập nhật hạng, chặn xóa hạng, tích điểm hóa đơn)
--        PHẦN 2: THỦ TỤC THÊM, SỬA, XÓA KHACH_HANG (sp_Them, sp_Sua, sp_Xoa)
--        PHẦN 3: THỦ TỤC TRA CỨU & THỐNG KÊ (sp_TraCuu, sp_ThongKe)
--        PHẦN 4: CÁC HÀM TÍNH TOÁN UDF CÓ CON TRỎ (fn_XacDinhHang, fn_TinhTongChiTieu)
-- ============================================================================

USE BidaHub;
GO

PRINT N'====================================================================';
PRINT N'              KỊCH BẢN DEMO PHẦN VIỆC - ĐÀO HUY PHONG              ';
PRINT N'====================================================================';
GO

-- ============================================================================
-- PHẦN 1: KIỂM THỬ TRIGGER RB15 (ĐIỂM TÍCH LŨY VÀ HẠNG THÀNH VIÊN)
-- ============================================================================
PRINT N'--------------------------------------------------------------------';
PRINT N'PHẦN 1: KIỂM THỬ TRIGGER RB15';
PRINT N'--------------------------------------------------------------------';
GO

PRINT N'--- 1.1. Trigger tự động nâng hạng theo điểm tích lũy ---';
-- Xem thông tin hiện tại của hội viên MaKH = 3 (Đang có 50 điểm, MaHang = 1 - Đồng)
SELECT hv.MaKH, kh.Ho + ' ' + kh.Ten AS HoTen, hv.DiemTichLuy, hv.MaHang, h.TenHang 
FROM dbo.HOI_VIEN hv
JOIN dbo.KHACH_HANG kh ON hv.MaKH = kh.MaKH
JOIN dbo.HANG_THANH_VIEN h ON hv.MaHang = h.MaHang
WHERE hv.MaKH = 3;

-- Cập nhật điểm của MaKH = 3 lên 350 điểm (mốc >= 300 điểm là hạng Vàng, MaHang = 3)
PRINT N'Cập nhật điểm hội viên MaKH = 3 từ 50 lên 350 điểm...';
UPDATE dbo.HOI_VIEN
SET DiemTichLuy = 350
WHERE MaKH = 3;

-- Kiểm tra lại: Trigger trg_HOI_VIEN_RB15_CapNhatHang tự động thăng hạng MaHang = 3 (Vàng)
SELECT hv.MaKH, kh.Ho + ' ' + kh.Ten AS HoTen, hv.DiemTichLuy, hv.MaHang, h.TenHang, N'Đã tự động nâng hạng!' AS TrangThai
FROM dbo.HOI_VIEN hv
JOIN dbo.KHACH_HANG kh ON hv.MaKH = kh.MaKH
JOIN dbo.HANG_THANH_VIEN h ON hv.MaHang = h.MaHang
WHERE hv.MaKH = 3;
GO

PRINT N'--- 1.2. Chặn cập nhật điểm tích lũy âm ---';
BEGIN TRY
    UPDATE dbo.HOI_VIEN
    SET DiemTichLuy = -50
    WHERE MaKH = 3;
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 1.3. Chặn xóa hạng thành viên đang có hội viên sử dụng (Kỳ vọng lỗi 50219) ---';
BEGIN TRY
    DELETE FROM dbo.HANG_THANH_VIEN WHERE MaHang = 1;
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 1.4. Trigger tích điểm hóa đơn và tự động tính thuộc tính dẫn xuất DiemCong ---';
-- Dọn dẹp hóa đơn demo của phiên 7 nếu có từ lần chạy trước
DELETE FROM dbo.HOA_DON WHERE MaPhien = 7;

-- Reset điểm của hội viên MaKH = 4 về 750 (mức ban đầu)
UPDATE dbo.HOI_VIEN SET DiemTichLuy = 750 WHERE MaKH = 4;

-- Kiểm tra điểm hội viên MaKH = 4 trước khi thanh toán
SELECT hv.MaKH, kh.Ho + ' ' + kh.Ten AS HoTen, hv.DiemTichLuy, hv.MaHang, h.TenHang
FROM dbo.HOI_VIEN hv
JOIN dbo.KHACH_HANG kh ON hv.MaKH = kh.MaKH
JOIN dbo.HANG_THANH_VIEN h ON hv.MaHang = h.MaHang
WHERE hv.MaKH = 4;

-- Thêm hóa đơn đã thanh toán 250.000 VNĐ cho phiên 7 (khách MaKH = 4)
-- Trigger tự động tính DiemCong = 25 điểm và cộng dồn vào DiemTichLuy của MaKH = 4
INSERT INTO dbo.HOA_DON 
    (ThoiDiemLap, DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra)
VALUES 
    (SYSDATETIME(), 0, N'Đã thanh toán', 7, 3, 150000.00, 100000.00, 0.00, 250000.00);

-- Kiểm tra DiemCong trên hóa đơn mới tạo
SELECT MaHoaDon, MaPhien, DiemCong, TrangThaiThanhToan, TongPhaiTra, N'Đã tự tính điểm cộng!' AS GhiChu
FROM dbo.HOA_DON
WHERE MaPhien = 7;

-- Kiểm tra điểm tích lũy của hội viên MaKH = 4 đã được cộng thêm 25 điểm (750 -> 775)
SELECT hv.MaKH, kh.Ho + ' ' + kh.Ten AS HoTen, hv.DiemTichLuy, hv.MaHang, h.TenHang, N'Đã cộng điểm tích lũy!' AS GhiChu
FROM dbo.HOI_VIEN hv
JOIN dbo.KHACH_HANG kh ON hv.MaKH = kh.MaKH
JOIN dbo.HANG_THANH_VIEN h ON hv.MaHang = h.MaHang
WHERE hv.MaKH = 4;
GO

PRINT N'--- 1.5. Chặn hóa đơn của khách không phải hội viên được cộng điểm (Kỳ vọng lỗi 50216) ---';
BEGIN TRY
    -- Phiên 9 là phiên của khách vãng lai (MaKH IS NULL)
    INSERT INTO dbo.HOA_DON 
        (ThoiDiemLap, DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, TienGioChoi, TienMon, TienGiam, TongPhaiTra)
    VALUES 
        (SYSDATETIME(), 10, N'Đã thanh toán', 9, 3, 100000.00, 0.00, 0.00, 100000.00);
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 1.6. Chặn sửa đổi điểm cộng của hóa đơn đã thanh toán (Kỳ vọng lỗi 50217) ---';
BEGIN TRY
    DECLARE @MaHD INT;
    SELECT TOP 1 @MaHD = hd.MaHoaDon 
    FROM dbo.HOA_DON hd
    JOIN dbo.PHIEN_CHOI pc ON pc.MaPhien = hd.MaPhien
    JOIN dbo.HOI_VIEN hv ON hv.MaKH = pc.MaKH
    WHERE hd.TrangThaiThanhToan = N'Đã thanh toán';

    UPDATE dbo.HOA_DON SET DiemCong = 999 WHERE MaHoaDon = @MaHD;
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================================
-- PHẦN 2: KIỂM THỬ THỦ TỤC THÊM, SỬA, XÓA KHACH_HANG (CÂU 2.1)
-- ============================================================================
PRINT N'--------------------------------------------------------------------';
PRINT N'PHẦN 2: KIỂM THỬ THỦ TỤC THÊM, SỬA, XÓA KHACH_HANG';
PRINT N'--------------------------------------------------------------------';
GO

PRINT N'--- 2.1. Thêm khách hàng hợp lệ (Sinh mã IDENTITY tự động) ---';
DECLARE @NewMaKH INT;
EXEC dbo.sp_ThemKhachHang 
    @Ho = N'Lý', 
    @TenDem = N'Hải', 
    @Ten = N'Nam', 
    @NgaySinh = '1997-05-15', 
    @GioiTinh = N'Nam', 
    @SoDienThoai = '0919998877', 
    @MaKH = @NewMaKH OUTPUT;
PRINT N'-> Đã thêm khách hàng mới với mã: ' + CAST(@NewMaKH AS NVARCHAR);
GO

PRINT N'--- 2.2. Thêm thất bại: Họ để trống (Kỳ vọng lỗi 50202) ---';
BEGIN TRY
    EXEC dbo.sp_ThemKhachHang 
        @Ho = N'   ', 
        @TenDem = N'Văn', 
        @Ten = N'Bình', 
        @NgaySinh = '1995-01-01', 
        @GioiTinh = N'Nam';
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 2.3. Thêm thất bại: Tên để trống (Kỳ vọng lỗi 50203) ---';
BEGIN TRY
    EXEC dbo.sp_ThemKhachHang 
        @Ho = N'Trịnh', 
        @TenDem = NULL, 
        @Ten = N'', 
        @NgaySinh = '1995-01-01', 
        @GioiTinh = N'Nam';
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 2.4. Thêm thất bại: Giới tính không hợp lệ (Kỳ vọng lỗi 50204) ---';
BEGIN TRY
    EXEC dbo.sp_ThemKhachHang 
        @Ho = N'Phan', 
        @TenDem = N'Thanh', 
        @Ten = N'Thảo', 
        @NgaySinh = '1998-03-20', 
        @GioiTinh = N'KhôngXácĐịnh';
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 2.5. Thêm thất bại: Ngày sinh ở tương lai (Kỳ vọng lỗi 50205) ---';
BEGIN TRY
    EXEC dbo.sp_ThemKhachHang 
        @Ho = N'Đoàn', 
        @TenDem = N'Minh', 
        @Ten = N'Khánh', 
        @NgaySinh = '2099-01-01', 
        @GioiTinh = N'Nam';
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 2.6. Thêm thất bại: Sai định dạng số điện thoại (Kỳ vọng lỗi 50207) ---';
BEGIN TRY
    EXEC dbo.sp_ThemKhachHang 
        @Ho = N'Lê', 
        @TenDem = N'Văn', 
        @Ten = N'Toàn', 
        @NgaySinh = '1993-02-10', 
        @GioiTinh = N'Nam',
        @SoDienThoai = '12345ABC';
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 2.7. Thêm thất bại: Trùng số điện thoại của khách khác (Kỳ vọng lỗi 50208) ---';
BEGIN TRY
    EXEC dbo.sp_ThemKhachHang 
        @Ho = N'Lê', 
        @TenDem = N'Văn', 
        @Ten = N'Toàn', 
        @NgaySinh = '1993-02-10', 
        @GioiTinh = N'Nam',
        @SoDienThoai = '0903123456'; -- Đã thuộc MaKH = 1
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 2.8. Sửa khách hàng thành công ---';
EXEC dbo.sp_SuaKhachHang 
    @MaKH = 1, 
    @Ho = N'Trần', 
    @TenDem = N'Văn', 
    @Ten = N'Bình (Đã Sửa)', 
    @NgaySinh = '1992-06-15', 
    @GioiTinh = N'Nam', 
    @SoDienThoai = '0903123456';
GO

PRINT N'--- 2.9. Sửa thất bại: Khách hàng không tồn tại (Kỳ vọng lỗi 50209) ---';
BEGIN TRY
    EXEC dbo.sp_SuaKhachHang 
        @MaKH = 9999, 
        @Ho = N'Không', 
        @TenDem = NULL, 
        @Ten = N'Tồn Tại';
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 2.10. Thử xóa khách hàng là hội viên có điểm tích lũy (Kỳ vọng chặn 50212) ---';
BEGIN TRY
    EXEC dbo.sp_XoaKhachHang @MaKH = 1; -- Hội viên có điểm
END TRY
BEGIN CATCH
    PRINT N'[BẮT ĐƯỢC LỖI] Mã: ' + CAST(ERROR_NUMBER() AS NVARCHAR) + N' - ' + ERROR_MESSAGE();
END CATCH
GO

PRINT N'--- 2.11. Xóa khách hàng hợp lệ (khách thử nghiệm vừa tạo không có ràng buộc) ---';
DECLARE @TempMaKH INT;
SELECT TOP 1 @TempMaKH = MaKH FROM dbo.KHACH_HANG WHERE Ten = N'Nam' AND Ho = N'Lý';
IF @TempMaKH IS NOT NULL
BEGIN
    PRINT N'Xóa khách thử nghiệm MaKH = ' + CAST(@TempMaKH AS NVARCHAR);
    EXEC dbo.sp_XoaKhachHang @MaKH = @TempMaKH;
END
GO

-- ============================================================================
-- PHẦN 3: KIỂM THỬ THỦ TỤC TRA CỨU & THỐNG KÊ (CÂU 2.3)
-- ============================================================================
PRINT N'--------------------------------------------------------------------';
PRINT N'PHẦN 3: KIỂM THỬ THỦ TỤC TRA CỨU & THỐNG KÊ';
PRINT N'--------------------------------------------------------------------';
GO

PRINT N'--- 3.1. Tra cứu tất cả khách hàng (sp_TraCuuKhachHang) ---';
EXEC dbo.sp_TraCuuKhachHang;
GO

PRINT N'--- 3.2. Tra cứu theo từ khóa "Bình" hoặc SĐT ---';
EXEC dbo.sp_TraCuuKhachHang @TuKhoa = N'Bình';
GO

PRINT N'--- 3.3. Tra cứu khách hàng theo loại Hội viên và hạng Vàng (MaHang = 3) ---';
EXEC dbo.sp_TraCuuKhachHang @LoaiKhach = 'HoiVien', @MaHang = 3;
GO

PRINT N'--- 3.4. Thống kê chi tiêu khách hàng (sp_ThongKeChiTieuKhachHang - HAVING) ---';
EXEC dbo.sp_ThongKeChiTieuKhachHang @SoLuotChoiToiThieu = 0;
GO

PRINT N'--- 3.5. Thống kê khách hàng có tổng chi tiêu >= 200.000 VNĐ ---';
EXEC dbo.sp_ThongKeChiTieuKhachHang @TongChiTieuToiThieu = 200000;
GO

-- ============================================================================
-- PHẦN 4: KIỂM THỬ CÁC HÀM TÍNH TOÁN UDF CÓ CON TRỎ (CÂU 2.4)
-- ============================================================================
PRINT N'--------------------------------------------------------------------';
PRINT N'PHẦN 4: KIỂM THỬ CÁC HÀM UDF';
PRINT N'--------------------------------------------------------------------';
GO

PRINT N'--- 4.1. Hàm fn_XacDinhHangThanhVien (Dùng Cursor và Loop) ---';
SELECT 
    0 AS Diem, dbo.fn_XacDinhHangThanhVien(0) AS MaHangExpected_1,
    150 AS Diem, dbo.fn_XacDinhHangThanhVien(150) AS MaHangExpected_2,
    350 AS Diem, dbo.fn_XacDinhHangThanhVien(350) AS MaHangExpected_3,
    750 AS Diem, dbo.fn_XacDinhHangThanhVien(750) AS MaHangExpected_4,
    1250 AS Diem, dbo.fn_XacDinhHangThanhVien(1250) AS MaHangExpected_5,
    -10 AS Diem, dbo.fn_XacDinhHangThanhVien(-10) AS MaHangExpected_NULL;
GO

PRINT N'--- 4.2. Hàm fn_TinhTongChiTieuKhachHang (Dùng Cursor duyệt hóa đơn) ---';
SELECT 
    kh.MaKH,
    kh.Ho + ' ' + kh.Ten AS HoTen,
    dbo.fn_TinhTongChiTieuKhachHang(kh.MaKH) AS TongTienChiTieu
FROM dbo.KHACH_HANG kh;
GO

PRINT N'====================================================================';
PRINT N'            KẾT THÚC KỊCH BẢN DEMO - TẤT CẢ ĐÃ VƯỢT QUA             ';
PRINT N'====================================================================';
GO
