-- 03_trigger/nhan.sql (Nhân): RB1, RB2, RB3 (phần cần đối chiếu nhiều dòng hoặc nhiều bảng); trigger 1 của mục 2.2 là RB1.
--
-- Phần của RB1-RB3 kiểm tra được trong CREATE TABLE thì nằm ở 01_bang (CHECK, UNIQUE), không lặp lại ở đây:
--   RB1: UQ_TaiKhoan_TenDangNhap, UQ_TaiKhoan_Email, CK_TaiKhoan_TenDangNhap, CK_TaiKhoan_MatKhauBam,
--        UQ_NhanVien_MaTK, UQ_HoiVien_MaTK
--   RB3: CK_NhanVien_Du18Tuoi, CK_NhanVien_KhongTuGiamSat
--
-- Quy ước: trigger AFTER; khi vi phạm thì ROLLBACK TRANSACTION rồi THROW câu thông báo cụ thể.
-- Dải mã lỗi của Nhân: 50100-50199.
--   50101  RB1  vai trò "Quản lý" cấp cho tài khoản không thuộc nhân viên chức vụ Quản lý   trg_DuocCap_KiemTraVaiTro
--   50102  RB1  vai trò "Hội viên" cấp cho tài khoản không thuộc hội viên                    trg_DuocCap_KiemTraVaiTro
--   50103  RB1  vai trò còn lại cấp cho tài khoản không thuộc nhân viên                      trg_DuocCap_KiemTraVaiTro
--   50104  RB1  gán cho nhân viên một tài khoản đang thuộc hội viên                          trg_NhanVien_TaiKhoan
--   50105  RB1  nhân viên bị hạ khỏi Quản lý nhưng tài khoản còn vai trò "Quản lý"           trg_NhanVien_TaiKhoan
--   50106  RB1  gán cho hội viên một tài khoản đang thuộc nhân viên                          trg_HoiVien_TaiKhoan
--   50107  RB2  khóa, cho nghỉ, đổi chức vụ, gỡ vai trò hoặc xóa quản lý cuối cùng          trg_TaiKhoan_GiuQuanLyCuoi
--                                                                                            trg_NhanVien_GiuQuanLyCuoi
--                                                                                            trg_DuocCap_GiuQuanLyCuoi
--   50108  RB3  người giám sát không có chức vụ Quản lý                                      trg_NhanVien_GiamSat
--   50109  RB3  nhân viên đang giám sát người khác bị hạ khỏi chức vụ Quản lý                trg_NhanVien_GiamSat
--   50110  RB3  quan hệ giám sát tạo thành vòng lặp                                          trg_NhanVien_GiamSat
--
-- Chạy sau 01_bang (đủ cả HOI_VIEN của Phong) và 02_du_lieu. Dữ liệu mẫu nạp trước khi trigger tồn tại nên không bị trigger chặn;
-- các truy vấn kiểm tra A1-A4 trong 99_demo/nhan.sql bảo đảm dữ liệu mẫu thỏa RB1-RB3.
USE BidaHub;
GO

------------------------------------------------------------------------------------------
-- Hàm dùng chung cho RB2: nhân viên còn làm việc và tài khoản chưa bị khóa.
-- Trigger mở phiên, ghi gọi món, lập hóa đơn, xác nhận thanh toán, lập phiếu nhập (của Dũng và Khang)
-- gọi hàm này để cả nhóm chỉ có một định nghĩa duy nhất cho "nhân viên dùng được".
-- Trả 1 nếu dùng được, 0 nếu không (nhân viên đã nghỉ, tài khoản bị khóa, hoặc không có nhân viên đó).
------------------------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_NhanVienDangHoatDong (@MaNV INT)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (
                    SELECT 1
                    FROM dbo.NHAN_VIEN nv
                    JOIN dbo.TAI_KHOAN tk ON tk.MaTK = nv.MaTK
                    WHERE nv.MaNV = @MaNV
                      AND nv.TinhTrangLamViec = N'Đang làm'
                      AND tk.TrangThai = N'Hoạt động')
                THEN 1 ELSE 0 END;
END
GO

-- Các tài khoản quản lý còn dùng được (RB2: luôn phải còn ít nhất một dòng).
CREATE OR ALTER VIEW dbo.v_QuanLyHoatDong
AS
SELECT nv.MaNV, tk.MaTK
FROM dbo.NHAN_VIEN nv
JOIN dbo.TAI_KHOAN tk ON tk.MaTK = nv.MaTK
JOIN dbo.DUOC_CAP dc  ON dc.MaTK = tk.MaTK
JOIN dbo.VAI_TRO vt   ON vt.MaVaiTro = dc.MaVaiTro
WHERE nv.ChucVu = N'Quản lý'
  AND nv.TinhTrangLamViec = N'Đang làm'
  AND tk.TrangThai = N'Hoạt động'
  AND vt.TenVaiTro = N'Quản lý';
GO

------------------------------------------------------------------------------------------
-- RB1 (trigger 1 của mục 2.2). Ba trigger cùng bảo vệ một ràng buộc:
--   (1) vai trò chỉ được cấp đúng loại chủ tài khoản,
--   (2) một tài khoản không thuộc đồng thời nhân viên và hội viên.
-- DML có thể vi phạm: INSERT và UPDATE (MaTK, MaVaiTro) trên DUOC_CAP; INSERT và UPDATE (MaTK, ChucVu) trên NHAN_VIEN;
-- INSERT và UPDATE (MaTK) trên HOI_VIEN. DELETE không tạo ra cặp sai loại nên không cần kiểm tra.
------------------------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DuocCap_KiemTraVaiTro
ON dbo.DUOC_CAP
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(MaTK) OR UPDATE(MaVaiTro)) RETURN;

    DECLARE @Ma INT, @Loi NVARCHAR(300);

    SELECT TOP (1)
           @Ma  = CASE vt.TenVaiTro WHEN N'Quản lý' THEN 50101
                                    WHEN N'Hội viên' THEN 50102
                                    ELSE 50103 END,
           @Loi = CASE vt.TenVaiTro
                    WHEN N'Quản lý' THEN N'Vai trò "Quản lý" chỉ cấp cho tài khoản của nhân viên có chức vụ Quản lý (tài khoản '
                    WHEN N'Hội viên' THEN N'Vai trò "Hội viên" chỉ cấp cho tài khoản của hội viên (tài khoản '
                    ELSE N'Vai trò "' + vt.TenVaiTro + N'" chỉ cấp cho tài khoản của nhân viên (tài khoản '
                  END + tk.TenDangNhap + N')'
    FROM inserted i
    JOIN dbo.VAI_TRO vt   ON vt.MaVaiTro = i.MaVaiTro
    JOIN dbo.TAI_KHOAN tk ON tk.MaTK = i.MaTK
    WHERE (vt.TenVaiTro = N'Quản lý'
               AND NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN nv
                               WHERE nv.MaTK = i.MaTK AND nv.ChucVu = N'Quản lý'))
       OR (vt.TenVaiTro = N'Hội viên'
               AND NOT EXISTS (SELECT 1 FROM dbo.HOI_VIEN hv WHERE hv.MaTK = i.MaTK))
       OR (vt.TenVaiTro NOT IN (N'Quản lý', N'Hội viên')
               AND NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN nv WHERE nv.MaTK = i.MaTK));

    IF @Loi IS NOT NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW @Ma, @Loi, 1;
    END
END
GO

CREATE OR ALTER TRIGGER dbo.trg_NhanVien_TaiKhoan
ON dbo.NHAN_VIEN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ma INT, @Loi NVARCHAR(300);

    -- (a) tài khoản đã thuộc hội viên thì không gán cho nhân viên
    IF UPDATE(MaTK)
        SELECT TOP (1) @Ma = 50104,
               @Loi = N'Tài khoản "' + tk.TenDangNhap + N'" đã thuộc về một hội viên nên không thể gán cho nhân viên'
        FROM inserted i
        JOIN dbo.HOI_VIEN hv  ON hv.MaTK = i.MaTK
        JOIN dbo.TAI_KHOAN tk ON tk.MaTK = i.MaTK;

    -- (b) nhân viên không giữ chức vụ Quản lý mà tài khoản vẫn mang vai trò Quản lý (do đổi chức vụ hoặc đổi tài khoản)
    IF @Loi IS NULL AND (UPDATE(ChucVu) OR UPDATE(MaTK))
        SELECT TOP (1) @Ma = 50105,
               @Loi = N'Nhân viên mã ' + CAST(i.MaNV AS NVARCHAR(10))
                    + N' không giữ chức vụ Quản lý nhưng tài khoản vẫn mang vai trò "Quản lý"; hãy gỡ vai trò trước'
        FROM inserted i
        JOIN dbo.DUOC_CAP dc ON dc.MaTK = i.MaTK
        JOIN dbo.VAI_TRO vt  ON vt.MaVaiTro = dc.MaVaiTro
        WHERE i.ChucVu <> N'Quản lý' AND vt.TenVaiTro = N'Quản lý';

    IF @Loi IS NOT NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW @Ma, @Loi, 1;
    END
END
GO

CREATE OR ALTER TRIGGER dbo.trg_HoiVien_TaiKhoan
ON dbo.HOI_VIEN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(MaTK) RETURN;

    DECLARE @Loi NVARCHAR(300);
    SELECT TOP (1) @Loi = N'Tài khoản "' + tk.TenDangNhap + N'" đã thuộc về nhân viên nên không thể gán cho hội viên'
    FROM inserted i
    JOIN dbo.NHAN_VIEN nv ON nv.MaTK = i.MaTK
    JOIN dbo.TAI_KHOAN tk ON tk.MaTK = i.MaTK;

    IF @Loi IS NOT NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50106, @Loi, 1;
    END
END
GO

------------------------------------------------------------------------------------------
-- RB2: không được khóa, cho nghỉ hoặc gỡ vai trò của quản lý cuối cùng.
-- Ba bảng cùng làm thay đổi tập quản lý còn hoạt động nên có ba trigger, chung một điều kiện.
------------------------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_TaiKhoan_GiuQuanLyCuoi
ON dbo.TAI_KHOAN
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND NOT UPDATE(TrangThai) RETURN;
    IF NOT EXISTS (SELECT 1 FROM dbo.v_QuanLyHoatDong)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50107, N'Hệ thống phải còn ít nhất một tài khoản Quản lý đang hoạt động; không thể khóa hoặc xóa quản lý cuối cùng', 1;
    END
END
GO

CREATE OR ALTER TRIGGER dbo.trg_NhanVien_GiuQuanLyCuoi
ON dbo.NHAN_VIEN
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted)
       AND NOT (UPDATE(TinhTrangLamViec) OR UPDATE(ChucVu) OR UPDATE(MaTK)) RETURN;
    IF NOT EXISTS (SELECT 1 FROM dbo.v_QuanLyHoatDong)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50107, N'Hệ thống phải còn ít nhất một tài khoản Quản lý đang hoạt động; không thể cho nghỉ hoặc đổi chức vụ quản lý cuối cùng', 1;
    END
END
GO

CREATE OR ALTER TRIGGER dbo.trg_DuocCap_GiuQuanLyCuoi
ON dbo.DUOC_CAP
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND NOT (UPDATE(MaTK) OR UPDATE(MaVaiTro)) RETURN;
    IF NOT EXISTS (SELECT 1 FROM dbo.v_QuanLyHoatDong)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50107, N'Hệ thống phải còn ít nhất một tài khoản Quản lý đang hoạt động; không thể gỡ vai trò Quản lý cuối cùng', 1;
    END
END
GO

------------------------------------------------------------------------------------------
-- RB3: người giám sát phải là quản lý và quan hệ giám sát không tạo vòng lặp.
-- (Đủ 18 tuổi và không tự giám sát chính mình đã nằm trong CHECK của CREATE TABLE.)
------------------------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_NhanVien_GiamSat
ON dbo.NHAN_VIEN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(MaNVGiamSat) OR UPDATE(ChucVu)) RETURN;

    DECLARE @Ma INT, @Loi NVARCHAR(300);

    -- (a) người giám sát phải có chức vụ Quản lý
    SELECT TOP (1) @Ma = 50108,
           @Loi = N'Người giám sát (mã ' + CAST(gs.MaNV AS NVARCHAR(10)) + N') của nhân viên mã '
                + CAST(i.MaNV AS NVARCHAR(10)) + N' phải có chức vụ Quản lý'
    FROM inserted i
    JOIN dbo.NHAN_VIEN gs ON gs.MaNV = i.MaNVGiamSat
    WHERE gs.ChucVu <> N'Quản lý';

    -- (b) nhân viên vừa bị đổi chức vụ khỏi Quản lý mà vẫn đang giám sát người khác
    IF @Loi IS NULL
        SELECT TOP (1) @Ma = 50109,
               @Loi = N'Nhân viên mã ' + CAST(i.MaNV AS NVARCHAR(10))
                    + N' đang giám sát người khác nên phải giữ chức vụ Quản lý'
        FROM inserted i
        JOIN dbo.NHAN_VIEN cap ON cap.MaNVGiamSat = i.MaNV
        WHERE i.ChucVu <> N'Quản lý';

    -- (c) không có vòng lặp: đi ngược dây giám sát từ mỗi dòng vừa ghi, nếu gặp lại chính nó là vòng
    IF @Loi IS NULL
    BEGIN
        ;WITH Chuoi AS (
            SELECT i.MaNV AS Goc, i.MaNVGiamSat AS Cur, 1 AS Buoc
            FROM inserted i
            WHERE i.MaNVGiamSat IS NOT NULL
            UNION ALL
            SELECT c.Goc, nv.MaNVGiamSat, c.Buoc + 1
            FROM Chuoi c
            JOIN dbo.NHAN_VIEN nv ON nv.MaNV = c.Cur
            WHERE nv.MaNVGiamSat IS NOT NULL AND c.Cur <> c.Goc AND c.Buoc < 50
        )
        SELECT TOP (1) @Ma = 50110,
               @Loi = N'Quan hệ giám sát của nhân viên mã ' + CAST(Goc AS NVARCHAR(10)) + N' tạo thành vòng lặp'
        FROM Chuoi
        WHERE Cur = Goc;
    END

    IF @Loi IS NOT NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW @Ma, @Loi, 1;
    END
END
GO
