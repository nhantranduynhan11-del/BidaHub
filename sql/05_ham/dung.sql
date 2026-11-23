-- sql/05_ham/dung.sql - fn_DuBaoSoNgayTonKho (mục 2.4)
--
-- Dự báo số ngày còn bán được của một mặt hàng = SoLuongTon / lượng bán trung bình mỗi ngày.
-- Lượng bán lấy từ DONG_GOI_MON (bỏ dòng 'Đã hủy') trong @SoNgayXet ngày kết thúc tại @NgayThamChieu,
-- con trỏ duyệt tổng số lượng bán theo từng ngày; ngày không bán tính là 0 nên chia cho @SoNgayXet.
--
-- Tham số:
--    @MaMatHang     mặt hàng cần dự báo
--    @SoNgayXet     số ngày xét, từ 1 đến 365 (gợi ý 7)
--    @NgayThamChieu ngày cuối của kỳ xét; NULL: lấy ngày gọi món mới nhất trong CSDL
--                   (dữ liệu mẫu nằm ở tháng 10/2025 nên không lấy GETDATE())
-- Kết quả: số ngày dự báo (làm tròn 1 chữ số thập phân), 0 khi đã hết hàng.
-- Hàm không dùng được THROW nên trả mã âm, ứng dụng đổi thành thông báo (app/ma_loi.py):
--    -1  @MaMatHang NULL hoặc không tồn tại
--    -2  @SoNgayXet NULL hoặc ngoài khoảng 1 đến 365
--    -3  mặt hàng đã ngừng bán
--    -4  không có dòng gọi món nào trong kỳ xét nên không dự báo được

USE BidaHub;
GO

CREATE OR ALTER FUNCTION dbo.fn_DuBaoSoNgayTonKho
(
    @MaMatHang      INT,
    @SoNgayXet      INT,
    @NgayThamChieu  DATE
)
RETURNS DECIMAL(18,1)
AS
BEGIN
    IF @MaMatHang IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.MAT_HANG WHERE MaMatHang = @MaMatHang)
        RETURN -1;

    IF @SoNgayXet IS NULL OR @SoNgayXet < 1 OR @SoNgayXet > 365
        RETURN -2;

    DECLARE @SoLuongTon INT, @TrangThai NVARCHAR(50);
    SELECT @SoLuongTon = SoLuongTon, @TrangThai = TrangThaiKinhDoanh
    FROM dbo.MAT_HANG
    WHERE MaMatHang = @MaMatHang;

    IF @TrangThai = N'Ngừng bán'
        RETURN -3;

    IF @NgayThamChieu IS NULL
        SELECT @NgayThamChieu = MAX(CAST(ThoiDiemGoi AS DATE))
        FROM dbo.DONG_GOI_MON
        WHERE TrangThaiPhucVu <> N'Đã hủy';

    IF @NgayThamChieu IS NULL
        RETURN -4;

    DECLARE @TuNgay DATE = DATEADD(DAY, 1 - @SoNgayXet, @NgayThamChieu);
    DECLARE @TongBan BIGINT = 0, @SoLuongNgay INT;

    DECLARE cur_BanTheoNgay CURSOR LOCAL FAST_FORWARD FOR
        SELECT SUM(SoLuong)
        FROM dbo.DONG_GOI_MON
        WHERE MaMatHang = @MaMatHang
          AND TrangThaiPhucVu <> N'Đã hủy'
          AND CAST(ThoiDiemGoi AS DATE) BETWEEN @TuNgay AND @NgayThamChieu
        GROUP BY CAST(ThoiDiemGoi AS DATE)
        ORDER BY CAST(ThoiDiemGoi AS DATE);

    OPEN cur_BanTheoNgay;
    FETCH NEXT FROM cur_BanTheoNgay INTO @SoLuongNgay;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @SoLuongNgay > 0
            SET @TongBan = @TongBan + @SoLuongNgay;

        FETCH NEXT FROM cur_BanTheoNgay INTO @SoLuongNgay;
    END;

    CLOSE cur_BanTheoNgay;
    DEALLOCATE cur_BanTheoNgay;

    IF @TongBan = 0
        RETURN -4;

    IF @SoLuongTon = 0
        RETURN 0;

    RETURN ROUND(CAST(@SoLuongTon AS DECIMAL(18,6)) * @SoNgayXet / @TongBan, 1);
END;
GO
