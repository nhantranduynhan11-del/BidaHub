
USE BidaHub;
GO

-- ============================================================================
-- THU TUC: THONG KE DOANH THU
-- ============================================================================
-- Nguoi phu trach: Khang
-- Bang su dung:
--   GIAO_DICH_THANH_TOAN
--   HOA_DON
--   PHIEN_CHOI
--
-- Chuc nang:
--   Thong ke doanh thu thuc thu theo ngay.
--   Chi tinh giao dich co TrangThai = N'Thành công'.
--
-- Tham so:
--   @TuNgay: Ngay bat dau
--   @DenNgay: Ngay ket thuc
--   @DoanhThuToiThieu: Muc doanh thu toi thieu
--
-- Ma loi:
--   50571: Khoang ngay khong hop le
--   50572: Doanh thu toi thieu khong hop le
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_ThongKeDoanhThu
    @TuNgay DATE,
    @DenNgay DATE,
    @DoanhThuToiThieu DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Kiem tra khoang ngay
    IF @TuNgay IS NULL
       OR @DenNgay IS NULL
       OR @TuNgay > @DenNgay
       OR @DenNgay = '9999-12-31'
    BEGIN
        THROW 50571,
              N'Khoảng thời gian thống kê không hợp lệ.',
              1;
    END;

    -- Kiem tra doanh thu toi thieu
    IF @DoanhThuToiThieu IS NULL
       OR @DoanhThuToiThieu < 0
    BEGIN
        THROW 50572,
              N'Doanh thu tối thiểu không hợp lệ.',
              1;
    END;

    -- Thong ke doanh thu theo ngay
    SELECT
        CAST(gd.ThoiDiemThanhToan AS DATE) AS NgayThanhToan,

        COUNT(gd.MaGD) AS SoGiaoDichThanhCong,

        COUNT(DISTINCT hd.MaHoaDon) AS SoHoaDon,

        COUNT(DISTINCT pc.MaPhien) AS SoPhienChoi,

        SUM(gd.SoTien) AS TongDoanhThu

    FROM dbo.GIAO_DICH_THANH_TOAN AS gd

    INNER JOIN dbo.HOA_DON AS hd
        ON gd.MaHoaDon = hd.MaHoaDon

    INNER JOIN dbo.PHIEN_CHOI AS pc
        ON hd.MaPhien = pc.MaPhien

    WHERE gd.TrangThai = N'Thành công'
      AND gd.ThoiDiemThanhToan >= @TuNgay
      AND gd.ThoiDiemThanhToan < DATEADD(DAY, 1, @DenNgay)

    GROUP BY
        CAST(gd.ThoiDiemThanhToan AS DATE)

    HAVING SUM(gd.SoTien) >= @DoanhThuToiThieu

    ORDER BY NgayThanhToan DESC;
END;
GO
