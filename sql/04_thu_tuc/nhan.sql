-- thủ tục của trang mẫu khung ứng dụng. Không thuộc các mục 2.1-2.3 được chấm.
USE BidaHub;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DanhSachNhanVien
    @TuKhoa    NVARCHAR(50) = NULL,       -- tìm trong họ tên hoặc số điện thoại
    @ChucVu    NVARCHAR(20) = NULL,
    @TinhTrang NVARCHAR(20) = NULL,
    @SapXep    NVARCHAR(20) = N'MaNV',    -- MaNV | HoTen | NgayVaoLam
    @Giam      BIT = 0                    -- 1: sắp xếp giảm dần
AS
BEGIN
    SET NOCOUNT ON;

    SELECT nv.MaNV,
           CONCAT_WS(N' ', nv.Ho, nv.TenDem, nv.Ten) AS HoTen,
           nv.ChucVu,
           nv.SoDienThoai,
           nv.NgayVaoLam,
           nv.TinhTrangLamViec,
           -- tuổi không lưu cột mà tính từ ngày sinh
           DATEDIFF(YEAR, nv.NgaySinh, GETDATE())
             - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, nv.NgaySinh, GETDATE()), nv.NgaySinh)
                         > CONVERT(DATE, GETDATE()) THEN 1 ELSE 0 END AS Tuoi,
           CASE WHEN tt.MaNV IS NOT NULL THEN N'Toàn thời gian' ELSE N'Bán thời gian' END AS HinhThuc,
           tk.TenDangNhap,
           tk.TrangThai AS TrangThaiTaiKhoan,
           CONCAT_WS(N' ', gs.Ho, gs.TenDem, gs.Ten) AS NguoiGiamSat
    FROM dbo.NHAN_VIEN nv
    JOIN dbo.TAI_KHOAN tk ON tk.MaTK = nv.MaTK
    LEFT JOIN dbo.NV_TOAN_THOI_GIAN tt ON tt.MaNV = nv.MaNV
    LEFT JOIN dbo.NHAN_VIEN gs ON gs.MaNV = nv.MaNVGiamSat
    WHERE (@TuKhoa IS NULL
           OR CONCAT_WS(N' ', nv.Ho, nv.TenDem, nv.Ten) LIKE N'%' + @TuKhoa + N'%'
           OR nv.SoDienThoai LIKE N'%' + @TuKhoa + N'%')
      AND (@ChucVu IS NULL OR nv.ChucVu = @ChucVu)
      AND (@TinhTrang IS NULL OR nv.TinhTrangLamViec = @TinhTrang)
    ORDER BY
        CASE WHEN @SapXep = N'HoTen' AND @Giam = 0 THEN nv.Ten END ASC,
        CASE WHEN @SapXep = N'HoTen' AND @Giam = 1 THEN nv.Ten END DESC,
        CASE WHEN @SapXep = N'NgayVaoLam' AND @Giam = 0 THEN nv.NgayVaoLam END ASC,
        CASE WHEN @SapXep = N'NgayVaoLam' AND @Giam = 1 THEN nv.NgayVaoLam END DESC,
        CASE WHEN @SapXep = N'MaNV' AND @Giam = 1 THEN nv.MaNV END DESC,
        nv.MaNV;
END
GO
