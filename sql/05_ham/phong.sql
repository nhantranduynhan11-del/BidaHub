-- ============================================================================
-- Hệ thống Quản lý Quán Bida - BidaHub
-- Phần việc thành viên: Đào Huy Phong (MSSV: 2412628)
-- File: sql/05_ham/phong.sql
-- Mô tả: Các hàm nghiệp vụ (UDF) phụ trách bởi Phong thỏa mãn:
--        - Có kiểm tra tham số đầu vào
--        - Có sử dụng CON TRỎ (CURSOR)
--        - Có câu lệnh IF và VÒNG LẶP (WHILE / LOOP) để tính toán
--        - Truy vấn dữ liệu từ các bảng trong CSDL
-- Hàm 1: fn_XacDinhHangThanhVien(@DiemTichLuy) -> Xác định mã hạng phù hợp bằng con trỏ
-- Hàm 2: fn_TinhTongChiTieuKhachHang(@MaKH) -> Tính tổng tiền chi tiêu qua con trỏ duyệt hóa đơn
-- ============================================================================

USE BidaHub;
GO

-- ============================================================================
-- 1. HÀM 1: fn_XacDinhHangThanhVien
-- Mô tả: Xác định mã hạng thành viên (MaHang) tương ứng với số điểm tích lũy.
--        Quy tắc RB15: Hạng có điểm tối thiểu lớn nhất mà <= điểm tích lũy.
-- Tham số đầu vào: @DiemTichLuy INT
-- Kiểm tra tham số: Nếu @DiemTichLuy IS NULL hoặc < 0, hàm trả về NULL.
-- Cấu trúc: Sử dụng CURSOR duyệt bảng HANG_THANH_VIEN, vòng lặp WHILE, điều kiện IF.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_XacDinhHangThanhVien (
    @DiemTichLuy INT
)
RETURNS INT
AS
BEGIN
    -- 1. Kiểm tra tham số đầu vào
    IF @DiemTichLuy IS NULL OR @DiemTichLuy < 0
        RETURN NULL;

    DECLARE @KetQuaMaHang INT = NULL;
    DECLARE @MaHangCur INT;
    DECLARE @DiemToiThieuCur INT;

    -- 2. Khai báo con trỏ duyệt qua các hạng sắp xếp theo điểm tối thiểu giảm dần
    DECLARE cur_Hang CURSOR LOCAL FAST_FORWARD FOR
        SELECT MaHang, DiemToiThieu
        FROM dbo.HANG_THANH_VIEN
        ORDER BY DiemToiThieu DESC;

    OPEN cur_Hang;
    FETCH NEXT FROM cur_Hang INTO @MaHangCur, @DiemToiThieuCur;

    -- 3. Vòng lặp duyệt qua các bản ghi
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Kiểm tra điều kiện: Hạng đầu tiên (có điểm tối thiểu lớn nhất) mà <= DiemTichLuy
        IF @DiemTichLuy >= @DiemToiThieuCur
        BEGIN
            SET @KetQuaMaHang = @MaHangCur;
            BREAK; -- Đã tìm được hạng chuẩn cao nhất thỏa mãn
        END

        FETCH NEXT FROM cur_Hang INTO @MaHangCur, @DiemToiThieuCur;
    END

    -- 4. Đóng và giải phóng con trỏ
    CLOSE cur_Hang;
    DEALLOCATE cur_Hang;

    RETURN @KetQuaMaHang;
END;
GO

-- ============================================================================
-- 2. HÀM 2: fn_TinhTongChiTieuKhachHang
-- Mô tả: Tính tổng số tiền khách hàng đã thanh toán tại quán BidaHub qua con trỏ.
-- Tham số đầu vào: @MaKH INT
-- Kiểm tra tham số:
--   - Nếu @MaKH IS NULL hoặc khách hàng không tồn tại trong KHACH_HANG -> trả về -1 (mã lỗi)
-- Cấu trúc: 
--   - Sử dụng CURSOR duyệt qua từng hóa đơn đã thanh toán thuộc các phiên chơi của khách
--   - Vòng lặp WHILE cộng dồn chi tiêu
--   - Câu lệnh IF kiểm tra giá trị hợp lệ
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_TinhTongChiTieuKhachHang (
    @MaKH INT
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    -- 1. Kiểm tra tham số đầu vào
    IF @MaKH IS NULL OR @MaKH <= 0
        RETURN -1.00;

    IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = @MaKH)
        RETURN -1.00;

    DECLARE @TongChiTieu DECIMAL(18, 2) = 0.00;
    DECLARE @TienHoaDon DECIMAL(18, 2);

    -- 2. Khai báo con trỏ duyệt qua các hóa đơn đã thanh toán của khách hàng
    DECLARE cur_HoaDonKhach CURSOR LOCAL FAST_FORWARD FOR
        SELECT hd.TongPhaiTra
        FROM dbo.HOA_DON hd
        INNER JOIN dbo.PHIEN_CHOI pc ON hd.MaPhien = pc.MaPhien
        WHERE pc.MaKH = @MaKH 
          AND hd.TrangThaiThanhToan = N'Đã thanh toán';

    OPEN cur_HoaDonKhach;
    FETCH NEXT FROM cur_HoaDonKhach INTO @TienHoaDon;

    -- 3. Vòng lặp duyệt con trỏ và tính toán tích lũy
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @TienHoaDon IS NOT NULL AND @TienHoaDon > 0
        BEGIN
            SET @TongChiTieu = @TongChiTieu + @TienHoaDon;
        END

        FETCH NEXT FROM cur_HoaDonKhach INTO @TienHoaDon;
    END

    -- 4. Đóng và giải phóng con trỏ
    CLOSE cur_HoaDonKhach;
    DEALLOCATE cur_HoaDonKhach;

    RETURN @TongChiTieu;
END;
GO
