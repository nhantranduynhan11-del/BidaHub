-- ============================================================================
-- sql/03_trigger/tao_tat_ca_trigger.sql
-- Toàn bộ trigger RB1-RB15 của nhóm 5 (BidaHub): 54 trigger, 3 view, 1 hàm.
--
-- Thứ tự chạy: init.sql -> 01_bang/tao_tat_ca_bang.sql -> 02_du_lieu/nap_tat_ca_du_lieu.sql -> file này.
-- Dữ liệu mẫu nạp trước khi có trigger; phần A của 99_demo/nhan.sql kiểm tra lại dữ liệu mẫu.
-- Chạy lại nhiều lần được: đầu file xóa mọi trigger đang có rồi tạo lại.
--
-- Quy ước viết, giống nhau ở cả 5 phần:
--   * Tên trigger: trg_<BẢNG>_RB<x>_<NộiDung>.
--   * Trigger AFTER; riêng trg_HANG_THANH_VIEN_RB15_XoaHang là INSTEAD OF DELETE.
--   * Đầu thân trigger: RETURN sớm khi lệnh không đụng cột liên quan.
--   * Mỗi điều kiện một khối:  IF EXISTS (<dòng vi phạm>) THROW <mã>, N'RB<x> (BẢNG.Cột): <lỗi>.', 1;
--   * Không viết ROLLBACK trong trigger. Trong trigger SQL Server bật sẵn XACT_ABORT nên THROW hủy cả giao tác:
--     lệnh gây lỗi, các lệnh trước nó trong giao tác và thay đổi của các trigger lồng nhau.
--     Người gọi hủy giao tác trong CATCH bằng IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION.
--   * Ràng buộc kiểm được trên một dòng (CHECK, UNIQUE, NOT NULL) nằm ở 01_bang, không lặp lại ở đây.
--
-- Mã lỗi theo người viết (ý nghĩa từng mã ghi ở khối chú thích của trigger):
--   Phần 1  Nhân   RB1 50101-50106, 50112, 50113 | RB2 50107, 50111 | RB3 50108-50110
--   Phần 2  Thành  RB4 50301 | RB5 50302-50305 | RB6 50306-50309
--   Phần 3  Dũng   RB7 50471-50476 | RB8 50481-50487 | RB10 50401-50408
--   Phần 4  Khang  RB11 50512-50514 | RB12 50521-50528 | RB13 50531-50535 | RB14 50541-50547
--   Phần 5  Phong  RB15 50216-50219
--   RB9 không cần trigger: tiền giờ là cột tính toán DOAN_SU_DUNG_BAN.TienGio, làm tròn khi lập hóa đơn (RB12).
-- ============================================================================
USE BidaHub;
GO

-- Xóa mọi trigger trên bảng (kể cả trigger mang tên cũ) để CSDL chỉ còn đúng các trigger của file này.
DECLARE @Lenh NVARCHAR(MAX) = N'';
SELECT @Lenh += N'DROP TRIGGER ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N'.' + QUOTENAME(t.name) + N';'
FROM sys.triggers AS t
JOIN sys.objects AS o ON o.object_id = t.object_id
WHERE t.parent_class = 1;
EXEC sys.sp_executesql @Lenh;
GO


-- ############################################################################
-- PHẦN 1. NHÂN: RB1, RB2, RB3
-- Trigger 1 của mục 2.2.1 là RB1 (bốn trigger RB1 đầu tiên).
-- ############################################################################

-- ----------------------------------------------------------------------------
-- fn_NhanVienDangHoatDong (RB2): 1 nếu nhân viên đang làm và tài khoản đang hoạt động, ngược lại 0.
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_NhanVienDangHoatDong (@MaNV INT)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1
                             FROM dbo.NHAN_VIEN AS nv
                             JOIN dbo.TAI_KHOAN AS tk ON tk.MaTK = nv.MaTK
                             WHERE nv.MaNV = @MaNV
                               AND nv.TinhTrangLamViec = N'Đang làm'
                               AND tk.TrangThai = N'Hoạt động')
                THEN 1 ELSE 0 END;
END;
GO

-- ----------------------------------------------------------------------------
-- v_QuanLyHoatDong (RB2): các quản lý còn dùng được; luôn phải còn ít nhất một dòng.
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_QuanLyHoatDong
AS
SELECT nv.MaNV, tk.MaTK
FROM dbo.NHAN_VIEN AS nv
JOIN dbo.TAI_KHOAN AS tk ON tk.MaTK = nv.MaTK
JOIN dbo.DUOC_CAP AS dc  ON dc.MaTK = tk.MaTK
JOIN dbo.VAI_TRO AS vt   ON vt.MaVaiTro = dc.MaVaiTro
WHERE nv.ChucVu = N'Quản lý'
  AND nv.TinhTrangLamViec = N'Đang làm'
  AND tk.TrangThai = N'Hoạt động'
  AND vt.TenVaiTro = N'Quản lý';
GO

-- ----------------------------------------------------------------------------
-- v_VaiTroSaiChu (RB1): các cặp (tài khoản, vai trò) sai loại chủ; dữ liệu đúng thì view rỗng.
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_VaiTroSaiChu
AS
SELECT dc.MaTK, vt.TenVaiTro
FROM dbo.DUOC_CAP AS dc
JOIN dbo.VAI_TRO AS vt        ON vt.MaVaiTro = dc.MaVaiTro
LEFT JOIN dbo.NHAN_VIEN AS nv ON nv.MaTK = dc.MaTK
LEFT JOIN dbo.HOI_VIEN AS hv  ON hv.MaTK = dc.MaTK
WHERE (vt.TenVaiTro = N'Quản lý'  AND (nv.MaNV IS NULL OR nv.ChucVu <> N'Quản lý'))
   OR (vt.TenVaiTro = N'Hội viên' AND hv.MaKH IS NULL)
   OR (vt.TenVaiTro NOT IN (N'Quản lý', N'Hội viên') AND nv.MaNV IS NULL);
GO

-- ----------------------------------------------------------------------------
-- trg_DUOC_CAP_RB1_KiemTraVaiTro
--   RB1: vai trò Quản lý chỉ cấp cho nhân viên có chức vụ Quản lý, vai trò Hội viên chỉ cấp cho hội viên,
--        các vai trò còn lại chỉ cấp cho nhân viên.
--   Chạy khi: INSERT, UPDATE(MaTK, MaVaiTro) trên DUOC_CAP.
--   Mã lỗi: 50101 Quản lý, 50102 Hội viên, 50103 vai trò khác.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DUOC_CAP_RB1_KiemTraVaiTro
ON dbo.DUOC_CAP
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(MaTK) OR UPDATE(MaVaiTro)) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.VAI_TRO AS vt ON vt.MaVaiTro = i.MaVaiTro
               WHERE vt.TenVaiTro = N'Quản lý'
                 AND NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN AS nv
                                 WHERE nv.MaTK = i.MaTK AND nv.ChucVu = N'Quản lý'))
        THROW 50101, N'RB1 (DUOC_CAP.MaVaiTro): Vai trò Quản lý chỉ được cấp cho tài khoản của nhân viên có chức vụ Quản lý.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.VAI_TRO AS vt ON vt.MaVaiTro = i.MaVaiTro
               WHERE vt.TenVaiTro = N'Hội viên'
                 AND NOT EXISTS (SELECT 1 FROM dbo.HOI_VIEN AS hv WHERE hv.MaTK = i.MaTK))
        THROW 50102, N'RB1 (DUOC_CAP.MaVaiTro): Vai trò Hội viên chỉ được cấp cho tài khoản của hội viên.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.VAI_TRO AS vt ON vt.MaVaiTro = i.MaVaiTro
               WHERE vt.TenVaiTro NOT IN (N'Quản lý', N'Hội viên')
                 AND NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN AS nv WHERE nv.MaTK = i.MaTK))
        THROW 50103, N'RB1 (DUOC_CAP.MaVaiTro): Vai trò Thu ngân, Phục vụ, Pha chế, Thủ kho chỉ được cấp cho tài khoản của nhân viên.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_NHAN_VIEN_RB1_TaiKhoan
--   RB1: tài khoản không thuộc đồng thời nhân viên và hội viên; vai trò của tài khoản phải hợp với chủ.
--   Chạy khi: INSERT, UPDATE(MaTK, ChucVu), DELETE trên NHAN_VIEN.
--   Mã lỗi: 50104 tài khoản đang thuộc hội viên, 50105 hạ chức vụ khi còn vai trò Quản lý,
--           50112 tài khoản mới hoặc tài khoản bị bỏ lại còn vai trò sai loại chủ.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_NHAN_VIEN_RB1_TaiKhoan
ON dbo.NHAN_VIEN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND NOT (UPDATE(MaTK) OR UPDATE(ChucVu)) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.HOI_VIEN AS hv ON hv.MaTK = i.MaTK)
        THROW 50104, N'RB1 (NHAN_VIEN.MaTK): Tài khoản này đã thuộc về một hội viên, không gán cho nhân viên được.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.DUOC_CAP AS dc ON dc.MaTK = i.MaTK
               JOIN dbo.VAI_TRO AS vt  ON vt.MaVaiTro = dc.MaVaiTro
               WHERE i.ChucVu <> N'Quản lý' AND vt.TenVaiTro = N'Quản lý')
        THROW 50105, N'RB1 (NHAN_VIEN.ChucVu): Nhân viên không giữ chức vụ Quản lý nhưng tài khoản vẫn mang vai trò Quản lý; hãy gỡ vai trò trước.', 1;

    -- deleted chứa tài khoản cũ bị tách khỏi nhân viên (đổi MaTK hoặc xóa nhân viên)
    IF EXISTS (SELECT 1
               FROM dbo.v_VaiTroSaiChu AS v
               WHERE v.MaTK IN (SELECT MaTK FROM inserted UNION SELECT MaTK FROM deleted))
        THROW 50112, N'RB1 (NHAN_VIEN.MaTK): Sau thao tác này có tài khoản mang vai trò không hợp với chủ tài khoản; hãy gỡ vai trò trước.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HOI_VIEN_RB1_TaiKhoan
--   RB1: như trg_NHAN_VIEN_RB1_TaiKhoan, phía hội viên.
--   Chạy khi: INSERT, UPDATE(MaTK), DELETE trên HOI_VIEN (kể cả xóa dây chuyền từ KHACH_HANG).
--   Mã lỗi: 50106 tài khoản đang thuộc nhân viên, 50112 tài khoản còn vai trò sai loại chủ.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOI_VIEN_RB1_TaiKhoan
ON dbo.HOI_VIEN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND NOT UPDATE(MaTK) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.NHAN_VIEN AS nv ON nv.MaTK = i.MaTK)
        THROW 50106, N'RB1 (HOI_VIEN.MaTK): Tài khoản này đã thuộc về một nhân viên, không gán cho hội viên được.', 1;

    -- deleted chứa tài khoản cũ bị tách khỏi hội viên (đổi MaTK, gỡ MaTK hoặc xóa hội viên)
    IF EXISTS (SELECT 1
               FROM dbo.v_VaiTroSaiChu AS v
               WHERE v.MaTK IN (SELECT MaTK FROM inserted UNION SELECT MaTK FROM deleted))
        THROW 50112, N'RB1 (HOI_VIEN.MaTK): Sau thao tác này có tài khoản mang vai trò không hợp với chủ tài khoản; hãy gỡ vai trò trước.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_VAI_TRO_RB1_KhongDoiTen
--   RB1, RB2: mọi kiểm tra nhận diện vai trò bằng tên, nên đổi tên vai trò làm đổi quyền của mọi tài khoản được cấp.
--   MaVaiTro là IDENTITY và được khóa ngoại tham chiếu nên không cần kiểm tra.
--   Chạy khi: UPDATE(TenVaiTro) trên VAI_TRO.
--   Mã lỗi: 50113.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_VAI_TRO_RB1_KhongDoiTen
ON dbo.VAI_TRO
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(TenVaiTro) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN deleted AS d ON d.MaVaiTro = i.MaVaiTro
               WHERE d.TenVaiTro <> i.TenVaiTro)
        THROW 50113, N'RB1 (VAI_TRO.TenVaiTro): Không được đổi tên vai trò đã có vì tên vai trò quyết định quyền của mọi tài khoản được cấp.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_TAI_KHOAN_RB2_GiuQuanLyCuoi, trg_NHAN_VIEN_RB2_GiuQuanLyCuoi, trg_DUOC_CAP_RB2_GiuQuanLyCuoi
--   RB2: hệ thống luôn còn ít nhất một quản lý đang hoạt động (v_QuanLyHoatDong không rỗng).
--   Ba bảng chứa các cột mà view dùng, nên mỗi bảng một trigger; cả ba hỏi cùng một câu
--   "sau lệnh này view còn dòng nào không". INSERT không làm giảm số quản lý nên không xét.
--   Chạy khi: TAI_KHOAN  UPDATE(TrangThai), DELETE
--             NHAN_VIEN  UPDATE(TinhTrangLamViec, ChucVu, MaTK), DELETE
--             DUOC_CAP   UPDATE(MaTK, MaVaiTro), DELETE
--   Mã lỗi: 50107.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_TAI_KHOAN_RB2_GiuQuanLyCuoi
ON dbo.TAI_KHOAN
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND NOT UPDATE(TrangThai) RETURN;

    IF NOT EXISTS (SELECT 1 FROM dbo.v_QuanLyHoatDong)
        THROW 50107, N'RB2 (TAI_KHOAN.TrangThai): Hệ thống phải còn ít nhất một quản lý đang hoạt động; không được khóa hoặc xóa tài khoản quản lý cuối cùng.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_NHAN_VIEN_RB2_GiuQuanLyCuoi
ON dbo.NHAN_VIEN
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted)
       AND NOT (UPDATE(TinhTrangLamViec) OR UPDATE(ChucVu) OR UPDATE(MaTK)) RETURN;

    IF NOT EXISTS (SELECT 1 FROM dbo.v_QuanLyHoatDong)
        THROW 50107, N'RB2 (NHAN_VIEN.TinhTrangLamViec): Hệ thống phải còn ít nhất một quản lý đang hoạt động; không được cho nghỉ, hạ chức vụ hoặc đổi tài khoản của quản lý cuối cùng.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DUOC_CAP_RB2_GiuQuanLyCuoi
ON dbo.DUOC_CAP
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND NOT (UPDATE(MaTK) OR UPDATE(MaVaiTro)) RETURN;

    IF NOT EXISTS (SELECT 1 FROM dbo.v_QuanLyHoatDong)
        THROW 50107, N'RB2 (DUOC_CAP.MaVaiTro): Hệ thống phải còn ít nhất một quản lý đang hoạt động; không được gỡ vai trò Quản lý của quản lý cuối cùng.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_PHIEN_CHOI_RB2_NhanVienMoPhien, trg_DONG_GOI_MON_RB2_NhanVienGhiMon, trg_PHIEU_NHAP_RB2_NhanVienLapPhieu,
-- trg_HOA_DON_RB2_NhanVienLapHoaDon, trg_GIAO_DICH_THANH_TOAN_RB2_NhanVienXacNhan
--   RB2: nhân viên đã nghỉ hoặc tài khoản bị khóa không được mở phiên, ghi gọi món, lập phiếu nhập,
--        lập hóa đơn, xác nhận thanh toán (dùng fn_NhanVienDangHoatDong).
--   Chỉ xét dòng mới hoặc dòng đổi người thực hiện, để dữ liệu cũ của người đã nghỉ vẫn xử lý tiếp được
--   (ví dụ hóa đơn do thu ngân đã nghỉ lập vẫn thanh toán được).
--   Chạy khi: INSERT, UPDATE(cột mã nhân viên) trên từng bảng.
--   Mã lỗi: 50111.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PHIEN_CHOI_RB2_NhanVienMoPhien
ON dbo.PHIEN_CHOI
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(MaNVMoPhien) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien
               WHERE (d.MaPhien IS NULL OR d.MaNVMoPhien <> i.MaNVMoPhien)
                 AND dbo.fn_NhanVienDangHoatDong(i.MaNVMoPhien) = 0)
        THROW 50111, N'RB2 (PHIEN_CHOI.MaNVMoPhien): Nhân viên đã nghỉ việc hoặc tài khoản bị khóa không được mở phiên chơi.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DONG_GOI_MON_RB2_NhanVienGhiMon
ON dbo.DONG_GOI_MON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(MaNVGhiNhan) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDong = i.SoThuTuDong
               WHERE (d.MaPhien IS NULL OR d.MaNVGhiNhan <> i.MaNVGhiNhan)
                 AND dbo.fn_NhanVienDangHoatDong(i.MaNVGhiNhan) = 0)
        THROW 50111, N'RB2 (DONG_GOI_MON.MaNVGhiNhan): Nhân viên đã nghỉ việc hoặc tài khoản bị khóa không được ghi gọi món.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_PHIEU_NHAP_RB2_NhanVienLapPhieu
ON dbo.PHIEU_NHAP
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(MaNVLap) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.MaPhieuNhap = i.MaPhieuNhap
               WHERE (d.MaPhieuNhap IS NULL OR d.MaNVLap <> i.MaNVLap)
                 AND dbo.fn_NhanVienDangHoatDong(i.MaNVLap) = 0)
        THROW 50111, N'RB2 (PHIEU_NHAP.MaNVLap): Nhân viên đã nghỉ việc hoặc tài khoản bị khóa không được lập phiếu nhập.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB2_NhanVienLapHoaDon
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(MaNVLap) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.MaHoaDon = i.MaHoaDon
               WHERE (d.MaHoaDon IS NULL OR d.MaNVLap <> i.MaNVLap)
                 AND dbo.fn_NhanVienDangHoatDong(i.MaNVLap) = 0)
        THROW 50111, N'RB2 (HOA_DON.MaNVLap): Nhân viên đã nghỉ việc hoặc tài khoản bị khóa không được lập hóa đơn.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_GIAO_DICH_THANH_TOAN_RB2_NhanVienXacNhan
ON dbo.GIAO_DICH_THANH_TOAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(MaNVXacNhan) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.MaGD = i.MaGD
               WHERE (d.MaGD IS NULL OR d.MaNVXacNhan <> i.MaNVXacNhan)
                 AND dbo.fn_NhanVienDangHoatDong(i.MaNVXacNhan) = 0)
        THROW 50111, N'RB2 (GIAO_DICH_THANH_TOAN.MaNVXacNhan): Nhân viên đã nghỉ việc hoặc tài khoản bị khóa không được xác nhận thanh toán.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_NHAN_VIEN_RB3_GiamSat
--   RB3: người giám sát phải có chức vụ Quản lý và quan hệ giám sát không tạo vòng lặp
--        (đủ 18 tuổi và không tự giám sát nằm ở CHECK của NHAN_VIEN).
--   Chạy khi: INSERT, UPDATE(MaNVGiamSat, ChucVu) trên NHAN_VIEN.
--   Mã lỗi: 50108 người giám sát không phải Quản lý, 50109 hạ chức vụ người đang giám sát người khác,
--           50110 vòng lặp.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_NHAN_VIEN_RB3_GiamSat
ON dbo.NHAN_VIEN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(MaNVGiamSat) OR UPDATE(ChucVu)) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.NHAN_VIEN AS gs ON gs.MaNV = i.MaNVGiamSat
               WHERE gs.ChucVu <> N'Quản lý')
        THROW 50108, N'RB3 (NHAN_VIEN.MaNVGiamSat): Người giám sát phải có chức vụ Quản lý.', 1;

    -- Người vừa bị hạ chức vụ không còn là Quản lý mà cấp dưới vẫn trỏ tới (cấp dưới không nằm trong inserted)
    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.NHAN_VIEN AS cd ON cd.MaNVGiamSat = i.MaNV
               WHERE i.ChucVu <> N'Quản lý')
        THROW 50109, N'RB3 (NHAN_VIEN.ChucVu): Nhân viên đang giám sát người khác phải giữ chức vụ Quản lý.', 1;

    -- Leo ngược dây giám sát từ mỗi dòng vừa ghi: gặp lại chính nó, hoặc đi đủ @SoNV bước mà chưa tới
    -- đỉnh (dây không vòng chỉ dài tối đa @SoNV - 1 bước), thì có vòng. CTE không đặt được trong IF EXISTS
    -- nên ghi kết quả vào biến @CoVong.
    DECLARE @SoNV INT = (SELECT COUNT(*) FROM dbo.NHAN_VIEN), @CoVong BIT = 0;

    WITH Chuoi AS (
        SELECT i.MaNV AS Goc, i.MaNVGiamSat AS Cur, 1 AS Buoc
        FROM inserted AS i
        WHERE i.MaNVGiamSat IS NOT NULL
        UNION ALL
        SELECT c.Goc, nv.MaNVGiamSat, c.Buoc + 1
        FROM Chuoi AS c
        JOIN dbo.NHAN_VIEN AS nv ON nv.MaNV = c.Cur
        WHERE nv.MaNVGiamSat IS NOT NULL AND c.Cur <> c.Goc AND c.Buoc < @SoNV
    )
    SELECT @CoVong = 1
    FROM Chuoi
    WHERE Cur = Goc OR Buoc >= @SoNV
    OPTION (MAXRECURSION 0);

    IF @CoVong = 1
        THROW 50110, N'RB3 (NHAN_VIEN.MaNVGiamSat): Quan hệ giám sát không được tạo thành vòng lặp.', 1;
END;
GO


-- ############################################################################
-- PHẦN 2. THÀNH: RB4, RB5, RB6
-- Khoảng giờ tính gồm giờ bắt đầu, không gồm giờ kết thúc: [a, b) và [c, d) chồng nhau khi a < d AND c < b.
-- ############################################################################

-- ----------------------------------------------------------------------------
-- trg_KHUNG_GIA_RB4_KhongChongLan
--   RB4: các khung giá cùng loại bàn và cùng loại ngày áp dụng không chồng giờ
--        (giờ kết thúc sau giờ bắt đầu và đơn giá > 0 nằm ở CHECK của KHUNG_GIA).
--   Chạy khi: INSERT, UPDATE trên KHUNG_GIA.
--   Mã lỗi: 50301.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_KHUNG_GIA_RB4_KhongChongLan
ON dbo.KHUNG_GIA
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.KHUNG_GIA AS k ON k.MaLoaiBan = i.MaLoaiBan
                                      AND k.LoaiNgayApDung = i.LoaiNgayApDung
                                      AND k.SoThuTuKhung <> i.SoThuTuKhung
               WHERE i.GioBatDau < k.GioKetThuc
                 AND k.GioBatDau < i.GioKetThuc)
        THROW 50301, N'RB4 (KHUNG_GIA.GioBatDau): Khung giá bị chồng giờ với một khung khác cùng loại bàn và cùng loại ngày áp dụng.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_PHIEU_DAT_BAN_RB5_RB6_KiemTraPhieu
--   RB5: mỗi khách tối đa 3 phiếu chờ xác nhận; phiếu đã xác nhận giữ ít nhất một bàn, không giữ bàn bảo trì
--        hoặc ngưng sử dụng, không chồng giờ với phiếu đã xác nhận khác trên cùng bàn.
--   RB6: phiếu đã mở phiên không được đổi sang khách khác.
--   Chạy khi: INSERT, UPDATE trên PHIEU_DAT_BAN.
--   Mã lỗi: 50302, 50303, 50304, 50305 (RB5); 50307 (RB6).
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PHIEU_DAT_BAN_RB5_RB6_KiemTraPhieu
ON dbo.PHIEU_DAT_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM dbo.PHIEU_DAT_BAN AS p
               WHERE p.TrangThai = N'Chờ xác nhận'
                 AND p.MaKH IN (SELECT MaKH FROM inserted WHERE TrangThai = N'Chờ xác nhận')
               GROUP BY p.MaKH
               HAVING COUNT(*) > 3)
        THROW 50302, N'RB5 (PHIEU_DAT_BAN.TrangThai): Mỗi khách hàng chỉ được có tối đa 3 phiếu đặt bàn đang chờ xác nhận.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               WHERE i.TrangThai = N'Đã xác nhận'
                 AND NOT EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g WHERE g.MaDatBan = i.MaDatBan))
        THROW 50303, N'RB5 (PHIEU_DAT_BAN.TrangThai): Phiếu đặt bàn đã xác nhận phải giữ ít nhất một bàn.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.GIU_BAN AS g ON g.MaDatBan = i.MaDatBan
               JOIN dbo.BAN AS b     ON b.MaBan = g.MaBan
               WHERE i.TrangThai = N'Đã xác nhận'
                 AND b.TrangThai IN (N'Đang bảo trì', N'Ngưng sử dụng'))
        THROW 50304, N'RB5 (GIU_BAN.MaBan): Phiếu đặt bàn đã xác nhận không được giữ bàn đang bảo trì hoặc ngưng sử dụng.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.GIU_BAN AS g1       ON g1.MaDatBan = i.MaDatBan
               JOIN dbo.GIU_BAN AS g2       ON g2.MaBan = g1.MaBan AND g2.MaDatBan <> i.MaDatBan
               JOIN dbo.PHIEU_DAT_BAN AS p2 ON p2.MaDatBan = g2.MaDatBan
               WHERE i.TrangThai = N'Đã xác nhận'
                 AND p2.TrangThai = N'Đã xác nhận'
                 AND i.GioBatDauDuKien < p2.GioKetThucDuKien
                 AND p2.GioBatDauDuKien < i.GioKetThucDuKien)
        THROW 50305, N'RB5 (GIU_BAN.MaBan): Một bàn không được giữ cho hai phiếu đã xác nhận có khoảng giờ dự kiến chồng nhau.', 1;

    IF UPDATE(MaKH)
       AND EXISTS (SELECT 1
                   FROM inserted AS i
                   JOIN dbo.PHIEN_CHOI AS pc ON pc.MaDatBan = i.MaDatBan
                   WHERE pc.MaKH IS NULL OR pc.MaKH <> i.MaKH)
        THROW 50307, N'RB6 (PHIEU_DAT_BAN.MaKH): Phiếu đặt bàn đã mở phiên không được đổi sang khách hàng khác.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_GIU_BAN_RB5_ThemSuaBanGiu
--   RB5: không giữ bàn bảo trì hoặc ngưng sử dụng; một bàn không giữ cho hai phiếu đã xác nhận chồng giờ.
--   Chạy khi: INSERT, UPDATE trên GIU_BAN.
--   Mã lỗi: 50304, 50305.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_GIU_BAN_RB5_ThemSuaBanGiu
ON dbo.GIU_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = i.MaDatBan
               JOIN dbo.BAN AS b           ON b.MaBan = i.MaBan
               WHERE p.TrangThai IN (N'Chờ xác nhận', N'Đã xác nhận')
                 AND b.TrangThai IN (N'Đang bảo trì', N'Ngưng sử dụng'))
        THROW 50304, N'RB5 (GIU_BAN.MaBan): Không được giữ bàn đang bảo trì hoặc ngưng sử dụng.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEU_DAT_BAN AS p1 ON p1.MaDatBan = i.MaDatBan
               JOIN dbo.GIU_BAN AS g2       ON g2.MaBan = i.MaBan AND g2.MaDatBan <> i.MaDatBan
               JOIN dbo.PHIEU_DAT_BAN AS p2 ON p2.MaDatBan = g2.MaDatBan
               WHERE p1.TrangThai = N'Đã xác nhận'
                 AND p2.TrangThai = N'Đã xác nhận'
                 AND p1.GioBatDauDuKien < p2.GioKetThucDuKien
                 AND p2.GioBatDauDuKien < p1.GioKetThucDuKien)
        THROW 50305, N'RB5 (GIU_BAN.MaBan): Một bàn không được giữ cho hai phiếu đã xác nhận có khoảng giờ dự kiến chồng nhau.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_GIU_BAN_RB5_RB6_BoBanGiu
--   RB5: phiếu đã xác nhận không được mất bàn giữ cuối cùng.
--   RB6: không bỏ bàn giữ mà đoạn đầu tiên của phiên mở từ phiếu đó đang dùng.
--   Chạy khi: DELETE, UPDATE trên GIU_BAN (bảng deleted là các dòng giữ bàn bị bỏ).
--   Mã lỗi: 50303, 50309.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_GIU_BAN_RB5_RB6_BoBanGiu
ON dbo.GIU_BAN
AFTER DELETE, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM deleted AS d
               JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = d.MaDatBan
               WHERE p.TrangThai = N'Đã xác nhận'
                 AND NOT EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g WHERE g.MaDatBan = p.MaDatBan))
        THROW 50303, N'RB5 (GIU_BAN.MaBan): Không được bỏ bàn giữ cuối cùng của phiếu đặt bàn đã xác nhận.', 1;

    -- Đoạn đầu tiên của phiên = đoạn không có đoạn nào khác cùng phiên bắt đầu sớm hơn
    IF EXISTS (SELECT 1
               FROM deleted AS d
               JOIN dbo.PHIEN_CHOI AS pc      ON pc.MaDatBan = d.MaDatBan
               JOIN dbo.DOAN_SU_DUNG_BAN AS o ON o.MaPhien = pc.MaPhien AND o.MaBan = d.MaBan
               WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o2
                                 WHERE o2.MaPhien = o.MaPhien AND o2.GioBatDauDung < o.GioBatDauDung)
                 AND NOT EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g
                                 WHERE g.MaDatBan = d.MaDatBan AND g.MaBan = d.MaBan))
        THROW 50309, N'RB6 (GIU_BAN.MaBan): Không được bỏ bàn giữ mà đoạn sử dụng bàn đầu tiên của phiên mở từ phiếu này đang dùng.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_BAN_RB5_BaoTriBanDangGiu
--   RB5: bàn đang được giữ cho phiếu đã xác nhận không chuyển sang bảo trì hoặc ngưng sử dụng.
--   Chạy khi: UPDATE(TrangThai) trên BAN.
--   Mã lỗi: 50304.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_BAN_RB5_BaoTriBanDangGiu
ON dbo.BAN
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(TrangThai) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.GIU_BAN AS g       ON g.MaBan = i.MaBan
               JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = g.MaDatBan
               WHERE i.TrangThai IN (N'Đang bảo trì', N'Ngưng sử dụng')
                 AND p.TrangThai = N'Đã xác nhận')
        THROW 50304, N'RB5 (BAN.TrangThai): Bàn đang được giữ cho phiếu đã xác nhận không được chuyển sang bảo trì hoặc ngưng sử dụng.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_PHIEN_CHOI_RB6_TuPhieuDatBan
--   RB6: chỉ mở phiên từ phiếu đã xác nhận (phiếu đã hủy, không đến, đã chuyển thành phiên hoặc còn chờ thì không);
--        phiên thuộc đúng khách của phiếu; đổi phiếu của phiên đã có đoạn thì đoạn đầu tiên phải dùng bàn phiếu mới giữ.
--   Tính: phiếu vừa được dùng chuyển sang 'Đã chuyển thành phiên'.
--   Chạy khi: INSERT, UPDATE trên PHIEN_CHOI có MaDatBan.
--   Mã lỗi: 50306, 50307, 50308.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PHIEN_CHOI_RB6_TuPhieuDatBan
ON dbo.PHIEN_CHOI
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE MaDatBan IS NOT NULL) RETURN;

    -- Phiên mới, hoặc phiên vừa đổi sang phiếu khác
    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d      ON d.MaPhien = i.MaPhien
               JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = i.MaDatBan
               WHERE (d.MaPhien IS NULL OR ISNULL(d.MaDatBan, -1) <> i.MaDatBan)
                 AND p.TrangThai <> N'Đã xác nhận')
        THROW 50306, N'RB6 (PHIEN_CHOI.MaDatBan): Chỉ mở phiên từ phiếu đặt bàn đã xác nhận; phiếu chờ xác nhận, đã hủy, không đến hoặc đã chuyển thành phiên thì không dùng được.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = i.MaDatBan
               WHERE i.MaKH IS NULL OR i.MaKH <> p.MaKH)
        THROW 50307, N'RB6 (PHIEN_CHOI.MaKH): Phiên mở từ phiếu đặt bàn phải thuộc đúng khách hàng của phiếu.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN deleted AS d              ON d.MaPhien = i.MaPhien
               JOIN dbo.DOAN_SU_DUNG_BAN AS o ON o.MaPhien = i.MaPhien
               WHERE ISNULL(d.MaDatBan, -1) <> i.MaDatBan
                 AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o2
                                 WHERE o2.MaPhien = o.MaPhien AND o2.GioBatDauDung < o.GioBatDauDung)
                 AND NOT EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g
                                 WHERE g.MaDatBan = i.MaDatBan AND g.MaBan = o.MaBan))
        THROW 50308, N'RB6 (PHIEN_CHOI.MaDatBan): Đoạn sử dụng bàn đầu tiên của phiên phải dùng một bàn mà phiếu đặt bàn mới giữ.', 1;

    UPDATE p
    SET p.TrangThai = N'Đã chuyển thành phiên'
    FROM dbo.PHIEU_DAT_BAN AS p
    JOIN inserted AS i ON i.MaDatBan = p.MaDatBan
    WHERE p.TrangThai = N'Đã xác nhận';
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DOAN_SU_DUNG_BAN_RB6_DoanDauTien
--   RB6: đoạn đầu tiên (giờ bắt đầu sớm nhất) của phiên mở từ phiếu đặt bàn phải dùng một bàn phiếu đã giữ.
--   Chạy khi: INSERT, UPDATE trên DOAN_SU_DUNG_BAN.
--   Mã lỗi: 50308.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DOAN_SU_DUNG_BAN_RB6_DoanDauTien
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
               WHERE pc.MaDatBan IS NOT NULL
                 AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                                 WHERE o.MaPhien = i.MaPhien AND o.GioBatDauDung < i.GioBatDauDung)
                 AND NOT EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g
                                 WHERE g.MaDatBan = pc.MaDatBan AND g.MaBan = i.MaBan))
        THROW 50308, N'RB6 (DOAN_SU_DUNG_BAN.MaBan): Đoạn sử dụng bàn đầu tiên của phiên mở từ phiếu đặt bàn phải dùng một trong các bàn phiếu đã giữ.', 1;
END;
GO


-- ############################################################################
-- PHẦN 3. DŨNG: RB7, RB8, RB10
-- (Một bàn tối đa một đoạn đang diễn ra: chỉ mục UQ_DoanSuDungBan_BanDangDung ở 01_bang.)
-- ############################################################################

-- ----------------------------------------------------------------------------
-- v_TrangThaiBanSuyRa (RB7): trạng thái suy ra của mỗi bàn.
--   Có đoạn đang diễn ra -> 'Đang chơi'; có phiếu đã xác nhận giữ -> 'Đã đặt'; còn lại -> 'Trống'.
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_TrangThaiBanSuyRa
AS
SELECT b.MaBan,
       CASE
           WHEN EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                        WHERE d.MaBan = b.MaBan AND d.GioKetThucDung IS NULL) THEN N'Đang chơi'
           WHEN EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g
                        JOIN dbo.PHIEU_DAT_BAN AS pd ON pd.MaDatBan = g.MaDatBan
                        WHERE g.MaBan = b.MaBan AND pd.TrangThai = N'Đã xác nhận') THEN N'Đã đặt'
           ELSE N'Trống'
       END AS TrangThaiSuyRa
FROM dbo.BAN AS b;
GO

-- ----------------------------------------------------------------------------
-- trg_DOAN_SU_DUNG_BAN_RB7_KiemTraDoan
--   RB7: không mở đoạn trên bàn bảo trì hoặc ngưng sử dụng; đoạn nằm trong thời gian của phiên;
--        các đoạn cùng phiên không chồng giờ; một bàn không thuộc hai đoạn chồng giờ.
--   Chạy khi: INSERT, UPDATE trên DOAN_SU_DUNG_BAN (đoạn đang diễn ra coi như kết thúc ở 9999-12-31).
--   Mã lỗi: 50471, 50472, 50473, 50474.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DOAN_SU_DUNG_BAN_RB7_KiemTraDoan
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
               JOIN dbo.BAN AS b      ON b.MaBan = i.MaBan
               WHERE d.MaPhien IS NULL
                 AND b.TrangThai IN (N'Đang bảo trì', N'Ngưng sử dụng'))
        THROW 50471, N'RB7 (DOAN_SU_DUNG_BAN.MaBan): Không được mở đoạn sử dụng trên bàn đang bảo trì hoặc ngưng sử dụng.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = i.MaPhien
               WHERE i.GioBatDauDung < p.GioBatDau
                  OR (p.GioKetThuc IS NOT NULL
                      AND (i.GioKetThucDung IS NULL OR i.GioKetThucDung > p.GioKetThuc)))
        THROW 50472, N'RB7 (DOAN_SU_DUNG_BAN.GioBatDauDung): Đoạn sử dụng bàn phải nằm trong khoảng thời gian của phiên.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.DOAN_SU_DUNG_BAN AS o ON o.MaPhien = i.MaPhien AND o.SoThuTuDoan <> i.SoThuTuDoan
               WHERE o.GioBatDauDung < ISNULL(i.GioKetThucDung, '9999-12-31')
                 AND i.GioBatDauDung < ISNULL(o.GioKetThucDung, '9999-12-31'))
        THROW 50473, N'RB7 (DOAN_SU_DUNG_BAN.GioBatDauDung): Các đoạn sử dụng bàn của cùng một phiên không được chồng giờ nhau.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.DOAN_SU_DUNG_BAN AS o ON o.MaBan = i.MaBan
                                             AND NOT (o.MaPhien = i.MaPhien AND o.SoThuTuDoan = i.SoThuTuDoan)
               WHERE o.GioBatDauDung < ISNULL(i.GioKetThucDung, '9999-12-31')
                 AND i.GioBatDauDung < ISNULL(o.GioKetThucDung, '9999-12-31'))
        THROW 50474, N'RB7 (DOAN_SU_DUNG_BAN.MaBan): Bàn đã thuộc một đoạn sử dụng khác trong khoảng giờ này.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DOAN_SU_DUNG_BAN_RB7_TrangThaiBan, trg_PHIEU_DAT_BAN_RB7_TrangThaiBan, trg_GIU_BAN_RB7_TrangThaiBan
--   RB7: trạng thái Trống, Đang chơi, Đã đặt của bàn do hệ thống suy ra (v_TrangThaiBanSuyRa).
--   Tính: ghi lại BAN.TrangThai cho các bàn bị ảnh hưởng đang lệch; bàn bảo trì, ngưng sử dụng giữ nguyên.
--   Chạy khi: đoạn sử dụng bàn thay đổi; phiếu đặt bàn đổi trạng thái; bàn giữ của phiếu thay đổi.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DOAN_SU_DUNG_BAN_RB7_TrangThaiBan
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE b
    SET b.TrangThai = v.TrangThaiSuyRa
    FROM dbo.BAN AS b
    JOIN dbo.v_TrangThaiBanSuyRa AS v ON v.MaBan = b.MaBan
    WHERE b.MaBan IN (SELECT MaBan FROM inserted UNION SELECT MaBan FROM deleted)
      AND b.TrangThai NOT IN (N'Đang bảo trì', N'Ngưng sử dụng')
      AND b.TrangThai <> v.TrangThaiSuyRa;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_PHIEU_DAT_BAN_RB7_TrangThaiBan
ON dbo.PHIEU_DAT_BAN
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(TrangThai) RETURN;

    -- Phiếu mới chưa giữ bàn nào (GIU_BAN cần phiếu có trước) nên chỉ cần xét UPDATE
    UPDATE b
    SET b.TrangThai = v.TrangThaiSuyRa
    FROM dbo.BAN AS b
    JOIN dbo.v_TrangThaiBanSuyRa AS v ON v.MaBan = b.MaBan
    WHERE b.MaBan IN (SELECT g.MaBan FROM dbo.GIU_BAN AS g JOIN inserted AS i ON i.MaDatBan = g.MaDatBan)
      AND b.TrangThai NOT IN (N'Đang bảo trì', N'Ngưng sử dụng')
      AND b.TrangThai <> v.TrangThaiSuyRa;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_GIU_BAN_RB7_TrangThaiBan
ON dbo.GIU_BAN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE b
    SET b.TrangThai = v.TrangThaiSuyRa
    FROM dbo.BAN AS b
    JOIN dbo.v_TrangThaiBanSuyRa AS v ON v.MaBan = b.MaBan
    WHERE b.MaBan IN (SELECT MaBan FROM inserted UNION SELECT MaBan FROM deleted)
      AND b.TrangThai NOT IN (N'Đang bảo trì', N'Ngưng sử dụng')
      AND b.TrangThai <> v.TrangThaiSuyRa;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_BAN_RB7_ChanSuaTayTrangThai
--   RB7: không sửa tay trạng thái Trống, Đang chơi, Đã đặt; giá trị ghi vào phải bằng trạng thái suy ra.
--        Bảo trì, ngưng sử dụng vẫn đặt được (chỉ quản lý được đặt: ứng dụng kiểm tra theo vai trò đăng nhập).
--   Chạy khi: INSERT, UPDATE(TrangThai) trên BAN.
--   Mã lỗi: 50476.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_BAN_RB7_ChanSuaTayTrangThai
ON dbo.BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(TrangThai) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d            ON d.MaBan = i.MaBan
               JOIN dbo.v_TrangThaiBanSuyRa AS v ON v.MaBan = i.MaBan
               WHERE (d.MaBan IS NULL OR d.TrangThai <> i.TrangThai)
                 AND i.TrangThai IN (N'Trống', N'Đang chơi', N'Đã đặt')
                 AND i.TrangThai <> v.TrangThaiSuyRa)
        THROW 50476, N'RB7 (BAN.TrangThai): Trạng thái Trống, Đang chơi, Đã đặt do hệ thống suy ra từ đoạn sử dụng bàn và phiếu đặt bàn, không được sửa tay.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_PHIEN_CHOI_RB7_ThoiGianPhien
--   RB7: sửa giờ bắt đầu, giờ kết thúc của phiên không được làm đoạn nào nằm ngoài thời gian của phiên.
--   Chạy khi: UPDATE(GioBatDau, GioKetThuc) trên PHIEN_CHOI.
--   Mã lỗi: 50475.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PHIEN_CHOI_RB7_ThoiGianPhien
ON dbo.PHIEN_CHOI
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(GioBatDau) OR UPDATE(GioKetThuc)) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS p
               JOIN deleted AS d              ON d.MaPhien = p.MaPhien
               JOIN dbo.DOAN_SU_DUNG_BAN AS o ON o.MaPhien = p.MaPhien
               WHERE (p.GioBatDau <> d.GioBatDau
                      OR ISNULL(p.GioKetThuc, '9999-12-31') <> ISNULL(d.GioKetThuc, '9999-12-31'))
                 AND (o.GioBatDauDung < p.GioBatDau
                      OR (p.GioKetThuc IS NOT NULL AND o.GioKetThucDung > p.GioKetThuc)))
        THROW 50475, N'RB7 (PHIEN_CHOI.GioBatDau): Giờ mới của phiên làm có đoạn sử dụng bàn nằm ngoài khoảng thời gian của phiên.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DOAN_SU_DUNG_BAN_RB8_KhungGia
--   RB8: khung giá của đoạn thuộc đúng loại bàn, chứa thời điểm bắt đầu đoạn và đúng loại ngày
--        ('Ngày thường' Thứ Hai - Thứ Sáu, 'Cuối tuần' Thứ Bảy, Chủ nhật; 'Ngày lễ' không kiểm tra vì
--        CSDL không có lịch lễ); đoạn không đi qua thời điểm đổi khung giá.
--   Chạy khi: INSERT, UPDATE trên DOAN_SU_DUNG_BAN.
--   Mã lỗi: 50481, 50482, 50483.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DOAN_SU_DUNG_BAN_RB8_KhungGia
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
               JOIN dbo.BAN AS b      ON b.MaBan = i.MaBan
               WHERE d.MaPhien IS NULL AND b.MaLoaiBan <> i.MaLoaiBan)
        THROW 50481, N'RB8 (DOAN_SU_DUNG_BAN.MaLoaiBan): Khung giá của đoạn phải thuộc đúng loại của bàn được sử dụng.', 1;

    -- 1900-01-01 là Thứ Hai: ThuTrongTuan 0-4 là Thứ Hai - Thứ Sáu, 5-6 là Thứ Bảy, Chủ nhật (không phụ thuộc DATEFIRST)
    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d   ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
               JOIN dbo.KHUNG_GIA AS k  ON k.MaLoaiBan = i.MaLoaiBan AND k.SoThuTuKhung = i.SoThuTuKhung
               CROSS APPLY (SELECT DATEDIFF(DAY, '19000101', CAST(i.GioBatDauDung AS DATE)) % 7 AS ThuTrongTuan) AS t
               WHERE d.MaPhien IS NULL
                 AND (CAST(i.GioBatDauDung AS TIME(0)) < k.GioBatDau
                      OR CAST(i.GioBatDauDung AS TIME(0)) >= k.GioKetThuc
                      OR (k.LoaiNgayApDung = N'Ngày thường' AND t.ThuTrongTuan >= 5)
                      OR (k.LoaiNgayApDung = N'Cuối tuần' AND t.ThuTrongTuan < 5)))
        THROW 50482, N'RB8 (DOAN_SU_DUNG_BAN.SoThuTuKhung): Khung giá phải chứa thời điểm bắt đầu đoạn và đúng loại ngày áp dụng.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.KHUNG_GIA AS k ON k.MaLoaiBan = i.MaLoaiBan AND k.SoThuTuKhung = i.SoThuTuKhung
               WHERE i.GioKetThucDung IS NOT NULL
                 AND (CAST(i.GioKetThucDung AS DATE) <> CAST(i.GioBatDauDung AS DATE)
                      OR CAST(i.GioKetThucDung AS TIME(0)) > k.GioKetThuc))
        THROW 50483, N'RB8 (DOAN_SU_DUNG_BAN.GioKetThucDung): Đoạn không được đi qua thời điểm đổi khung giá; hãy kết thúc đoạn và mở đoạn mới.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DOAN_SU_DUNG_BAN_RB8_ChotDonGia
--   RB8: đơn giá áp dụng của đoạn mới bằng đơn giá khung giá; đoạn đã ghi chỉ được cập nhật GioKetThucDung
--        (chuyển bàn hoặc đổi khung thì kết thúc đoạn cũ, mở đoạn mới).
--   Chạy khi: INSERT, UPDATE trên DOAN_SU_DUNG_BAN.
--   Mã lỗi: 50484, 50485.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DOAN_SU_DUNG_BAN_RB8_ChotDonGia
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Dòng cũ biến mất (đổi khóa) hoặc đổi cột khác ngoài GioKetThucDung
    IF EXISTS (SELECT 1
               FROM deleted AS d
               LEFT JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDoan = d.SoThuTuDoan
               WHERE i.MaPhien IS NULL
                  OR EXISTS (SELECT d.GioBatDauDung, d.DonGiaApDung, d.MaBan, d.MaLoaiBan, d.SoThuTuKhung
                             EXCEPT
                             SELECT i.GioBatDauDung, i.DonGiaApDung, i.MaBan, i.MaLoaiBan, i.SoThuTuKhung))
        THROW 50485, N'RB8 (DOAN_SU_DUNG_BAN.DonGiaApDung): Đoạn đã ghi chỉ được cập nhật giờ kết thúc; đơn giá áp dụng đã được chốt.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d  ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
               JOIN dbo.KHUNG_GIA AS k ON k.MaLoaiBan = i.MaLoaiBan AND k.SoThuTuKhung = i.SoThuTuKhung
               WHERE d.MaPhien IS NULL AND i.DonGiaApDung <> k.DonGiaMoiGio)
        THROW 50484, N'RB8 (DOAN_SU_DUNG_BAN.DonGiaApDung): Đơn giá áp dụng phải bằng đơn giá mỗi giờ của khung giá.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_PHIEN_CHOI_RB8_PhuKinPhien, trg_DOAN_SU_DUNG_BAN_RB8_PhuKinPhien
--   RB8: phiên đã kết thúc có ít nhất một đoạn, mọi đoạn đã đóng, và các đoạn phủ kín thời gian phiên:
--        có đoạn bắt đầu đúng GioBatDau, có đoạn kết thúc đúng GioKetThuc, mọi đoạn khác nối liền đoạn trước.
--   Chạy khi: phiên vừa có giờ kết thúc hoặc đổi giờ; đoạn của phiên đã kết thúc bị thêm, sửa, xóa.
--   Mã lỗi: 50486, 50487.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PHIEN_CHOI_RB8_PhuKinPhien
ON dbo.PHIEN_CHOI
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PhienKetThuc TABLE (MaPhien INT PRIMARY KEY, GioBatDau DATETIME2(0), GioKetThuc DATETIME2(0));
    INSERT INTO @PhienKetThuc (MaPhien, GioBatDau, GioKetThuc)
    SELECT p.MaPhien, p.GioBatDau, p.GioKetThuc
    FROM inserted AS p
    LEFT JOIN deleted AS d ON d.MaPhien = p.MaPhien
    WHERE p.GioKetThuc IS NOT NULL
      AND (d.MaPhien IS NULL OR d.GioKetThuc IS NULL
           OR d.GioKetThuc <> p.GioKetThuc OR d.GioBatDau <> p.GioBatDau);

    IF EXISTS (SELECT 1
               FROM @PhienKetThuc AS p
               WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o WHERE o.MaPhien = p.MaPhien)
                  OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                             WHERE o.MaPhien = p.MaPhien AND o.GioKetThucDung IS NULL))
        THROW 50486, N'RB8 (PHIEN_CHOI.GioKetThuc): Phiên kết thúc phải có ít nhất một đoạn sử dụng bàn và mọi đoạn đã đóng.', 1;

    IF EXISTS (SELECT 1
               FROM @PhienKetThuc AS p
               WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                                 WHERE o.MaPhien = p.MaPhien AND o.GioBatDauDung = p.GioBatDau)
                  OR NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                                 WHERE o.MaPhien = p.MaPhien AND o.GioKetThucDung = p.GioKetThuc)
                  OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS s
                             WHERE s.MaPhien = p.MaPhien AND s.GioBatDauDung <> p.GioBatDau
                               AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS t
                                               WHERE t.MaPhien = s.MaPhien AND t.GioKetThucDung = s.GioBatDauDung)))
        THROW 50487, N'RB8 (PHIEN_CHOI.GioKetThuc): Các đoạn sử dụng bàn phải phủ kín toàn bộ thời gian của phiên.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DOAN_SU_DUNG_BAN_RB8_PhuKinPhien
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PhienKetThuc TABLE (MaPhien INT PRIMARY KEY, GioBatDau DATETIME2(0), GioKetThuc DATETIME2(0));
    INSERT INTO @PhienKetThuc (MaPhien, GioBatDau, GioKetThuc)
    SELECT p.MaPhien, p.GioBatDau, p.GioKetThuc
    FROM dbo.PHIEN_CHOI AS p
    WHERE p.GioKetThuc IS NOT NULL
      AND p.MaPhien IN (SELECT MaPhien FROM inserted UNION SELECT MaPhien FROM deleted);

    IF EXISTS (SELECT 1
               FROM @PhienKetThuc AS p
               WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o WHERE o.MaPhien = p.MaPhien)
                  OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                             WHERE o.MaPhien = p.MaPhien AND o.GioKetThucDung IS NULL))
        THROW 50486, N'RB8 (DOAN_SU_DUNG_BAN.GioKetThucDung): Phiên kết thúc phải có ít nhất một đoạn sử dụng bàn và mọi đoạn đã đóng.', 1;

    IF EXISTS (SELECT 1
               FROM @PhienKetThuc AS p
               WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                                 WHERE o.MaPhien = p.MaPhien AND o.GioBatDauDung = p.GioBatDau)
                  OR NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                                 WHERE o.MaPhien = p.MaPhien AND o.GioKetThucDung = p.GioKetThuc)
                  OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS s
                             WHERE s.MaPhien = p.MaPhien AND s.GioBatDauDung <> p.GioBatDau
                               AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS t
                                               WHERE t.MaPhien = s.MaPhien AND t.GioKetThucDung = s.GioBatDauDung)))
        THROW 50487, N'RB8 (DOAN_SU_DUNG_BAN.GioBatDauDung): Các đoạn sử dụng bàn phải phủ kín toàn bộ thời gian của phiên.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DONG_GOI_MON_RB10_KiemTraGoiMon
--   RB10: dòng mới gọi mặt hàng đang bán, trong phiên đang chơi (không trước giờ bắt đầu phiên),
--         đơn giá bằng đơn giá niêm yết (RB8: chốt giá khi gọi), không ở trạng thái 'Đã hủy'.
--   Chạy khi: INSERT trên DONG_GOI_MON.
--   Mã lỗi: 50401, 50402, 50403, 50404.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DONG_GOI_MON_RB10_KiemTraGoiMon
ON dbo.DONG_GOI_MON
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.MAT_HANG AS mh ON mh.MaMatHang = i.MaMatHang
               WHERE mh.TrangThaiKinhDoanh <> N'Đang bán')
        THROW 50401, N'RB10 (DONG_GOI_MON.MaMatHang): Chỉ được gọi mặt hàng đang bán.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = i.MaPhien
               WHERE p.TrangThai <> N'Đang chơi' OR i.ThoiDiemGoi < p.GioBatDau)
        THROW 50402, N'RB10 (DONG_GOI_MON.MaPhien): Chỉ được ghi dòng gọi món trong phiên đang chơi.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.MAT_HANG AS mh ON mh.MaMatHang = i.MaMatHang
               WHERE i.DonGiaTaiThoiDiemGoi <> mh.DonGiaNiemYet)
        THROW 50403, N'RB10 (DONG_GOI_MON.DonGiaTaiThoiDiemGoi): Đơn giá tại thời điểm gọi phải bằng đơn giá niêm yết của mặt hàng.', 1;

    IF EXISTS (SELECT 1 FROM inserted WHERE TrangThaiPhucVu = N'Đã hủy')
        THROW 50404, N'RB10 (DONG_GOI_MON.TrangThaiPhucVu): Dòng gọi món mới không được ở trạng thái Đã hủy.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DONG_GOI_MON_RB10_KhoaDongDaGhi
--   RB10: không xóa dòng gọi món (giữ lịch sử bán); dòng đã ghi chỉ đổi trạng thái phục vụ và ghi chú;
--         chỉ dòng 'Chờ chế biến' mới chuyển sang 'Đã phục vụ' hoặc 'Đã hủy'.
--   Chạy khi: UPDATE, DELETE trên DONG_GOI_MON.
--   Mã lỗi: 50405, 50406, 50407.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DONG_GOI_MON_RB10_KhoaDongDaGhi
ON dbo.DONG_GOI_MON
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Lệnh DELETE: deleted có dòng, inserted rỗng. Phải xét cả deleted, vì UPDATE hoặc DELETE
    -- không khớp dòng nào cũng gọi trigger với hai bảng đều rỗng.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 50405, N'RB10 (DONG_GOI_MON): Không được xóa dòng gọi món; chỉ được hủy khi còn chờ chế biến.', 1;

    IF EXISTS (SELECT 1
               FROM deleted AS d
               LEFT JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDong = d.SoThuTuDong
               WHERE i.MaPhien IS NULL
                  OR EXISTS (SELECT d.ThoiDiemGoi, d.SoLuong, d.DonGiaTaiThoiDiemGoi, d.MaMatHang, d.MaNVGhiNhan
                             EXCEPT
                             SELECT i.ThoiDiemGoi, i.SoLuong, i.DonGiaTaiThoiDiemGoi, i.MaMatHang, i.MaNVGhiNhan))
        THROW 50406, N'RB10 (DONG_GOI_MON): Dòng gọi món đã ghi chỉ được đổi trạng thái phục vụ và ghi chú.', 1;

    IF EXISTS (SELECT 1
               FROM deleted AS d
               JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDong = d.SoThuTuDong
               WHERE i.TrangThaiPhucVu <> d.TrangThaiPhucVu AND d.TrangThaiPhucVu <> N'Chờ chế biến')
        THROW 50407, N'RB10 (DONG_GOI_MON.TrangThaiPhucVu): Chỉ dòng đang chờ chế biến mới được chuyển sang Đã phục vụ hoặc Đã hủy.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DONG_GOI_MON_RB10_CapNhatTonKho
--   RB10: gọi món làm giảm số lượng tồn đúng bằng số lượng gọi, không được xuống dưới 0;
--         hủy dòng đang chờ chế biến thì hoàn lại kho.
--   Tính: MAT_HANG.SoLuongTon.
--   Chạy khi: INSERT, UPDATE trên DONG_GOI_MON.
--   Mã lỗi: 50408.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DONG_GOI_MON_RB10_CapNhatTonKho
ON dbo.DONG_GOI_MON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BienDong TABLE (MaMatHang INT PRIMARY KEY, SoLuongChenhLech INT NOT NULL);
    INSERT INTO @BienDong (MaMatHang, SoLuongChenhLech)
    SELECT x.MaMatHang, SUM(x.ChenhLech)
    FROM (
        SELECT i.MaMatHang, -i.SoLuong AS ChenhLech             -- dòng mới: trừ kho
        FROM inserted AS i
        LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDong = i.SoThuTuDong
        WHERE d.MaPhien IS NULL AND i.TrangThaiPhucVu <> N'Đã hủy'
        UNION ALL
        SELECT i.MaMatHang, i.SoLuong                           -- dòng chuyển sang 'Đã hủy': hoàn kho
        FROM inserted AS i
        JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDong = i.SoThuTuDong
        WHERE d.TrangThaiPhucVu = N'Chờ chế biến' AND i.TrangThaiPhucVu = N'Đã hủy'
    ) AS x
    GROUP BY x.MaMatHang
    HAVING SUM(x.ChenhLech) <> 0;

    IF EXISTS (SELECT 1
               FROM dbo.MAT_HANG AS mh WITH (UPDLOCK, HOLDLOCK)
               JOIN @BienDong AS bd ON bd.MaMatHang = mh.MaMatHang
               WHERE mh.SoLuongTon + bd.SoLuongChenhLech < 0)
        THROW 50408, N'RB10 (MAT_HANG.SoLuongTon): Số lượng tồn của mặt hàng không đủ cho dòng gọi món.', 1;

    UPDATE mh
    SET mh.SoLuongTon = mh.SoLuongTon + bd.SoLuongChenhLech
    FROM dbo.MAT_HANG AS mh
    JOIN @BienDong AS bd ON bd.MaMatHang = mh.MaMatHang;
END;
GO


-- ############################################################################
-- PHẦN 4. KHANG: RB11, RB12, RB13, RB14
-- Trigger 2 của mục 2.2.2 là trg_CHI_TIET_NHAP_RB11_TinhTongTien (thuộc tính dẫn xuất PHIEU_NHAP.TongTien).
-- HOA_DON.TongPhaiTra do CHECK CK_HoaDon_TongPhaiTra bảo đảm, ngày nhập không sau hôm nay do CHECK
-- CK_PhieuNhap_NgayNhap, TienGiam = TienGiamTheoHang + TienGiamKhuyenMai do CHECK CK_HoaDon_PhanBoGiam.
-- ############################################################################

-- ----------------------------------------------------------------------------
-- trg_PHIEU_NHAP_RB11_NguoiLap
--   RB11: chỉ nhân viên có chức vụ Thủ kho hoặc Quản lý mới được lập phiếu nhập.
--   Chạy khi: INSERT, UPDATE(MaNVLap) trên PHIEU_NHAP (chỉ xét phiếu mới hoặc đổi người lập).
--   Mã lỗi: 50512.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PHIEU_NHAP_RB11_NguoiLap
ON dbo.PHIEU_NHAP
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(MaNVLap) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d   ON d.MaPhieuNhap = i.MaPhieuNhap
               JOIN dbo.NHAN_VIEN AS nv ON nv.MaNV = i.MaNVLap
               WHERE (d.MaPhieuNhap IS NULL OR d.MaNVLap <> i.MaNVLap)
                 AND nv.ChucVu NOT IN (N'Thủ kho', N'Quản lý'))
        THROW 50512, N'RB11 (PHIEU_NHAP.MaNVLap): Người lập phiếu nhập phải có chức vụ Thủ kho hoặc Quản lý.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_CHI_TIET_NHAP_RB11_TinhTongTien  (trigger 2, mục 2.2.2)
--   RB11: tổng tiền phiếu bằng tổng số lượng nhân đơn giá các dòng nhập.
--   Tính: PHIEU_NHAP.TongTien = SUM(SoLuongNhap * DonGiaNhap) của các phiếu có dòng nhập thay đổi.
--   Chạy khi: INSERT, UPDATE, DELETE trên CHI_TIET_NHAP.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_CHI_TIET_NHAP_RB11_TinhTongTien
ON dbo.CHI_TIET_NHAP
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    WITH PhieuBiAnhHuong AS (
        SELECT MaPhieuNhap FROM inserted
        UNION
        SELECT MaPhieuNhap FROM deleted
    ),
    TongTienMoi AS (
        SELECT p.MaPhieuNhap,
               COALESCE(SUM(CAST(ct.SoLuongNhap AS DECIMAL(18,2)) * ct.DonGiaNhap), 0) AS TongTien
        FROM PhieuBiAnhHuong AS p
        LEFT JOIN dbo.CHI_TIET_NHAP AS ct ON ct.MaPhieuNhap = p.MaPhieuNhap
        GROUP BY p.MaPhieuNhap
    )
    UPDATE pn
    SET pn.TongTien = t.TongTien
    FROM dbo.PHIEU_NHAP AS pn
    JOIN TongTienMoi AS t ON t.MaPhieuNhap = pn.MaPhieuNhap;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_CHI_TIET_NHAP_RB11_CapNhatTonKho
--   RB11: lập phiếu thì số lượng tồn của từng mặt hàng tăng đúng bằng số lượng nhập
--         (sửa, xóa dòng nhập thì điều chỉnh theo chênh lệch); tồn kho không được âm.
--   Tính: MAT_HANG.SoLuongTon.
--   Chạy khi: INSERT, UPDATE, DELETE trên CHI_TIET_NHAP.
--   Mã lỗi: 50513.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_CHI_TIET_NHAP_RB11_CapNhatTonKho
ON dbo.CHI_TIET_NHAP
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BienDong TABLE (MaMatHang INT PRIMARY KEY, SoLuongChenhLech BIGINT NOT NULL);
    INSERT INTO @BienDong (MaMatHang, SoLuongChenhLech)
    SELECT x.MaMatHang, SUM(x.ChenhLech)
    FROM (
        SELECT MaMatHang, CAST(SoLuongNhap AS BIGINT) AS ChenhLech FROM inserted
        UNION ALL
        SELECT MaMatHang, -CAST(SoLuongNhap AS BIGINT) FROM deleted
    ) AS x
    GROUP BY x.MaMatHang
    HAVING SUM(x.ChenhLech) <> 0;

    IF EXISTS (SELECT 1
               FROM dbo.MAT_HANG AS mh WITH (UPDLOCK, HOLDLOCK)
               JOIN @BienDong AS bd ON bd.MaMatHang = mh.MaMatHang
               WHERE CAST(mh.SoLuongTon AS BIGINT) + bd.SoLuongChenhLech < 0
                  OR CAST(mh.SoLuongTon AS BIGINT) + bd.SoLuongChenhLech > 2147483647)
        THROW 50513, N'RB11 (MAT_HANG.SoLuongTon): Thay đổi dòng nhập làm số lượng tồn của mặt hàng âm hoặc vượt giới hạn.', 1;

    UPDATE mh
    SET mh.SoLuongTon = mh.SoLuongTon + bd.SoLuongChenhLech
    FROM dbo.MAT_HANG AS mh
    JOIN @BienDong AS bd ON bd.MaMatHang = mh.MaMatHang;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_PHIEU_NHAP_RB11_KhoaTongTien
--   RB11: không sửa tay TongTien; giá trị phải bằng tổng tính lại từ CHI_TIET_NHAP.
--   Chạy khi: UPDATE(TongTien) trên PHIEU_NHAP.
--   Mã lỗi: 50514.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PHIEU_NHAP_RB11_KhoaTongTien
ON dbo.PHIEU_NHAP
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(TongTien) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               OUTER APPLY (SELECT COALESCE(SUM(CAST(ct.SoLuongNhap AS DECIMAL(18,2)) * ct.DonGiaNhap), 0) AS TongTinhLai
                            FROM dbo.CHI_TIET_NHAP AS ct
                            WHERE ct.MaPhieuNhap = i.MaPhieuNhap) AS t
               WHERE i.TongTien <> t.TongTinhLai)
        THROW 50514, N'RB11 (PHIEU_NHAP.TongTien): Tổng tiền phiếu nhập phải bằng tổng số lượng nhân đơn giá của các dòng nhập.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HOA_DON_RB12_DieuKienLap
--   RB12: chỉ lập hóa đơn cho phiên đã kết thúc (có giờ kết thúc, có đoạn, mọi đoạn đã đóng);
--         người lập có chức vụ Thu ngân hoặc Quản lý.
--   Chạy khi: INSERT, UPDATE trên HOA_DON (người lập chỉ xét khi hóa đơn mới hoặc đổi người lập).
--   Mã lỗi: 50521, 50522.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB12_DieuKienLap
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = i.MaPhien
               WHERE p.GioKetThuc IS NULL OR p.TrangThai NOT IN (N'Đã kết thúc', N'Đã thanh toán'))
        THROW 50521, N'RB12 (HOA_DON.MaPhien): Chỉ được lập hóa đơn cho phiên đã kết thúc.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaPhien = i.MaPhien)
                  OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                             WHERE d.MaPhien = i.MaPhien AND d.GioKetThucDung IS NULL))
        THROW 50521, N'RB12 (HOA_DON.MaPhien): Phiên chưa có đoạn sử dụng bàn hoặc còn đoạn chưa đóng, chưa lập hóa đơn được.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d   ON d.MaHoaDon = i.MaHoaDon
               JOIN dbo.NHAN_VIEN AS nv ON nv.MaNV = i.MaNVLap
               WHERE (d.MaHoaDon IS NULL OR d.MaNVLap <> i.MaNVLap)
                 AND nv.ChucVu NOT IN (N'Thu ngân', N'Quản lý'))
        THROW 50522, N'RB12 (HOA_DON.MaNVLap): Người lập hóa đơn phải có chức vụ Thu ngân hoặc Quản lý.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DOAN_SU_DUNG_BAN_RB12_ChanThemSauHoaDon, trg_DONG_GOI_MON_RB12_ChanThemSauHoaDon
--   RB12: sau khi lập hóa đơn không được thêm đoạn sử dụng bàn hay dòng gọi món vào phiên.
--   Chạy khi: INSERT trên DOAN_SU_DUNG_BAN, DONG_GOI_MON.
--   Mã lỗi: 50523, 50524.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DOAN_SU_DUNG_BAN_RB12_ChanThemSauHoaDon
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS i JOIN dbo.HOA_DON AS hd ON hd.MaPhien = i.MaPhien)
        THROW 50523, N'RB12 (DOAN_SU_DUNG_BAN.MaPhien): Phiên đã có hóa đơn, không được thêm đoạn sử dụng bàn.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DONG_GOI_MON_RB12_ChanThemSauHoaDon
ON dbo.DONG_GOI_MON
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS i JOIN dbo.HOA_DON AS hd ON hd.MaPhien = i.MaPhien)
        THROW 50524, N'RB12 (DONG_GOI_MON.MaPhien): Phiên đã có hóa đơn, không được thêm dòng gọi món.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HOA_DON_RB12_TienGioTienMon
--   RB12, RB9: tiền giờ chơi bằng tổng tiền giờ các đoạn đã làm tròn đến đồng;
--              tiền món bằng tổng thành tiền các dòng gọi món chưa hủy.
--   Chạy khi: INSERT, UPDATE trên HOA_DON.
--   Mã lỗi: 50525, 50526.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB12_TienGioTienMon
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               OUTER APPLY (SELECT CAST(ROUND(COALESCE(SUM(d.TienGio), 0), 0) AS DECIMAL(18,2)) AS TongTienGio
                            FROM dbo.DOAN_SU_DUNG_BAN AS d
                            WHERE d.MaPhien = i.MaPhien) AS tg
               WHERE i.TienGioChoi <> tg.TongTienGio)
        THROW 50525, N'RB12 (HOA_DON.TienGioChoi): Tiền giờ chơi phải bằng tổng tiền giờ các đoạn sử dụng bàn đã làm tròn.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               OUTER APPLY (SELECT COALESCE(SUM(gm.ThanhTien), 0) AS TongTienMon
                            FROM dbo.DONG_GOI_MON AS gm
                            WHERE gm.MaPhien = i.MaPhien AND gm.TrangThaiPhucVu <> N'Đã hủy') AS tm
               WHERE i.TienMon <> tm.TongTienMon)
        THROW 50526, N'RB12 (HOA_DON.TienMon): Tiền món phải bằng tổng thành tiền các dòng gọi món chưa hủy.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_DOAN_SU_DUNG_BAN_RB12_RB14_KhoaTienGio, trg_DONG_GOI_MON_RB12_RB14_KhoaTienMon
--   RB12: phiên đã lập hóa đơn thì không sửa, xóa dữ liệu tính tiền giờ, tiền món.
--   RB14: hóa đơn đã thanh toán thì càng không (mã riêng để báo đúng tình huống).
--   Dòng món chỉ đổi trạng thái phục vụ mà không chạm 'Đã hủy' thì không làm đổi tiền, được phép.
--   Chạy khi: UPDATE, DELETE trên DOAN_SU_DUNG_BAN, DONG_GOI_MON.
--   Mã lỗi: 50545, 50527 (tiền giờ); 50546, 50528 (tiền món).
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_DOAN_SU_DUNG_BAN_RB12_RB14_KhoaTienGio
ON dbo.DOAN_SU_DUNG_BAN
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Các phiên có đoạn bị xóa, bị đổi khóa, hoặc bị sửa cột dùng để tính tiền giờ
    DECLARE @PhienBiSua TABLE (MaPhien INT PRIMARY KEY);
    INSERT INTO @PhienBiSua (MaPhien)
    SELECT d.MaPhien
    FROM deleted AS d
    LEFT JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDoan = d.SoThuTuDoan
    WHERE i.MaPhien IS NULL
       OR EXISTS (SELECT d.TienGio, d.ThoiLuong, d.DonGiaApDung, d.GioBatDauDung, d.GioKetThucDung,
                         d.MaBan, d.MaLoaiBan, d.SoThuTuKhung
                  EXCEPT
                  SELECT i.TienGio, i.ThoiLuong, i.DonGiaApDung, i.GioBatDauDung, i.GioKetThucDung,
                         i.MaBan, i.MaLoaiBan, i.SoThuTuKhung)
    UNION
    SELECT i.MaPhien
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
    WHERE d.MaPhien IS NULL;

    IF EXISTS (SELECT 1
               FROM @PhienBiSua AS p
               JOIN dbo.HOA_DON AS hd ON hd.MaPhien = p.MaPhien
               WHERE hd.TrangThaiThanhToan = N'Đã thanh toán')
        THROW 50545, N'RB14 (DOAN_SU_DUNG_BAN): Phiên đã thanh toán, không được sửa hoặc xóa dữ liệu tính tiền giờ.', 1;

    IF EXISTS (SELECT 1 FROM @PhienBiSua AS p JOIN dbo.HOA_DON AS hd ON hd.MaPhien = p.MaPhien)
        THROW 50527, N'RB12 (DOAN_SU_DUNG_BAN): Phiên đã lập hóa đơn, không được sửa hoặc xóa dữ liệu tính tiền giờ.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DONG_GOI_MON_RB12_RB14_KhoaTienMon
ON dbo.DONG_GOI_MON
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Các phiên có dòng món bị xóa, bị đổi khóa, bị sửa cột tính tiền, hoặc chuyển vào/ra trạng thái 'Đã hủy'
    DECLARE @PhienBiSua TABLE (MaPhien INT PRIMARY KEY);
    INSERT INTO @PhienBiSua (MaPhien)
    SELECT d.MaPhien
    FROM deleted AS d
    LEFT JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDong = d.SoThuTuDong
    WHERE i.MaPhien IS NULL
       OR EXISTS (SELECT d.SoLuong, d.DonGiaTaiThoiDiemGoi, d.ThanhTien, d.MaMatHang,
                         CASE WHEN d.TrangThaiPhucVu = N'Đã hủy' THEN 1 ELSE 0 END
                  EXCEPT
                  SELECT i.SoLuong, i.DonGiaTaiThoiDiemGoi, i.ThanhTien, i.MaMatHang,
                         CASE WHEN i.TrangThaiPhucVu = N'Đã hủy' THEN 1 ELSE 0 END)
    UNION
    SELECT i.MaPhien
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDong = i.SoThuTuDong
    WHERE d.MaPhien IS NULL;

    IF EXISTS (SELECT 1
               FROM @PhienBiSua AS p
               JOIN dbo.HOA_DON AS hd ON hd.MaPhien = p.MaPhien
               WHERE hd.TrangThaiThanhToan = N'Đã thanh toán')
        THROW 50546, N'RB14 (DONG_GOI_MON): Hóa đơn đã thanh toán, không được sửa hoặc xóa dữ liệu tính tiền món.', 1;

    IF EXISTS (SELECT 1 FROM @PhienBiSua AS p JOIN dbo.HOA_DON AS hd ON hd.MaPhien = p.MaPhien)
        THROW 50528, N'RB12 (DONG_GOI_MON): Phiên đã lập hóa đơn, không được sửa hoặc xóa dữ liệu tính tiền món.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HOA_DON_RB13_KhuyenMaiHieuLuc
--   RB13: khuyến mãi áp dụng phải còn hiệu lực tại ngày lập hóa đơn (NgayBatDau <= ngày lập <= NgayKetThuc).
--   Chạy khi: INSERT, UPDATE trên HOA_DON có MaKM.
--   Mã lỗi: 50531.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB13_KhuyenMaiHieuLuc
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.KHUYEN_MAI AS km ON km.MaKM = i.MaKM
               WHERE CAST(i.ThoiDiemLap AS DATE) < km.NgayBatDau
                  OR CAST(i.ThoiDiemLap AS DATE) > km.NgayKetThuc)
        THROW 50531, N'RB13 (HOA_DON.MaKM): Khuyến mãi không còn hiệu lực tại ngày lập hóa đơn.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_KHUYEN_MAI_RB13_KhoaThoiHan
--   RB13: đổi thời hạn khuyến mãi không được làm hóa đơn đã áp dụng nằm ngoài thời hạn mới.
--   Chạy khi: UPDATE(NgayBatDau, NgayKetThuc) trên KHUYEN_MAI.
--   Mã lỗi: 50532.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_KHUYEN_MAI_RB13_KhoaThoiHan
ON dbo.KHUYEN_MAI
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(NgayBatDau) OR UPDATE(NgayKetThuc)) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS km
               JOIN dbo.HOA_DON AS hd ON hd.MaKM = km.MaKM
               WHERE CAST(hd.ThoiDiemLap AS DATE) < km.NgayBatDau
                  OR CAST(hd.ThoiDiemLap AS DATE) > km.NgayKetThuc)
        THROW 50532, N'RB13 (KHUYEN_MAI.NgayKetThuc): Thời hạn mới của khuyến mãi không còn chứa ngày lập của các hóa đơn đã áp dụng.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HOA_DON_RB13_TienGiam
--   RB13: chỉ hội viên (đăng ký trước ngày lập hóa đơn) được giảm theo hạng; giảm theo hạng bằng phần trăm
--         của hạng nhân tiền giờ chơi, làm tròn đến đồng; có giảm khuyến mãi thì phải gắn MaKM.
--         Tổng giảm không vượt tiền giờ cộng tiền món nằm ở CHECK CK_HoaDon_Tien.
--   Chạy khi: INSERT, UPDATE các cột tính khoản giảm trên HOA_DON. Không xét lại ở lệnh UPDATE khác, vì hạng
--         của hội viên có thể đổi sau khi lập hóa đơn (RB15 nâng hạng lúc thanh toán).
--   Mã lỗi: 50533, 50534, 50535.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB13_TienGiam
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(TienGiamTheoHang) OR UPDATE(TienGiamKhuyenMai) OR UPDATE(TienGioChoi)
                OR UPDATE(MaPhien) OR UPDATE(MaKM) OR UPDATE(ThoiDiemLap)) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEN_CHOI AS p     ON p.MaPhien = i.MaPhien
               LEFT JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = p.MaKH
               WHERE i.TienGiamTheoHang > 0
                 AND (hv.MaKH IS NULL OR hv.NgayDangKy > i.ThoiDiemLap))
        THROW 50533, N'RB13 (HOA_DON.TienGiamTheoHang): Chỉ hội viên đã đăng ký trước ngày lập hóa đơn mới được giảm theo hạng.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEN_CHOI AS p       ON p.MaPhien = i.MaPhien
               JOIN dbo.HOI_VIEN AS hv        ON hv.MaKH = p.MaKH
               JOIN dbo.HANG_THANH_VIEN AS h  ON h.MaHang = hv.MaHang
               WHERE i.TienGiamTheoHang > 0
                 AND i.TienGiamTheoHang <> CAST(ROUND(i.TienGioChoi * h.PhanTramGiamGia / 100.0, 0) AS DECIMAL(18,2)))
        THROW 50534, N'RB13 (HOA_DON.TienGiamTheoHang): Tiền giảm theo hạng phải bằng phần trăm giảm của hạng nhân tiền giờ chơi.', 1;

    IF EXISTS (SELECT 1 FROM inserted WHERE TienGiamKhuyenMai > 0 AND MaKM IS NULL)
        THROW 50535, N'RB13 (HOA_DON.TienGiamKhuyenMai): Có tiền giảm khuyến mãi thì hóa đơn phải gắn khuyến mãi.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_GIAO_DICH_THANH_TOAN_RB14_ThanhToan
--   RB14: không thêm, sửa, xóa giao dịch của hóa đơn đã thanh toán; tổng giao dịch thành công không vượt
--         tổng phải trả. Số tiền > 0 nằm ở CHECK CK_GiaoDich_SoTien.
--   Tính: HOA_DON.TrangThaiThanhToan theo tổng đã trả (bằng tổng phải trả -> 'Đã thanh toán', > 0 -> 'Thanh toán
--         một phần', còn lại 'Chưa thanh toán'); hóa đơn trả đủ thì PHIEN_CHOI.TrangThai -> 'Đã thanh toán'.
--   Chạy khi: INSERT, UPDATE, DELETE trên GIAO_DICH_THANH_TOAN.
--   Mã lỗi: 50542, 50541.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_GIAO_DICH_THANH_TOAN_RB14_ThanhToan
ON dbo.GIAO_DICH_THANH_TOAN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM (SELECT MaHoaDon FROM deleted UNION SELECT MaHoaDon FROM inserted) AS x
               JOIN dbo.HOA_DON AS hd ON hd.MaHoaDon = x.MaHoaDon
               WHERE hd.TrangThaiThanhToan = N'Đã thanh toán')
        THROW 50542, N'RB14 (GIAO_DICH_THANH_TOAN.MaHoaDon): Hóa đơn đã thanh toán, không được thêm, sửa hoặc xóa giao dịch.', 1;

    DECLARE @HoaDonBiAnhHuong TABLE (MaHoaDon INT PRIMARY KEY);
    INSERT INTO @HoaDonBiAnhHuong (MaHoaDon)
    SELECT MaHoaDon FROM inserted
    UNION
    SELECT MaHoaDon FROM deleted;

    IF EXISTS (SELECT 1
               FROM dbo.HOA_DON AS hd WITH (UPDLOCK, HOLDLOCK)
               JOIN @HoaDonBiAnhHuong AS a ON a.MaHoaDon = hd.MaHoaDon
               OUTER APPLY (SELECT COALESCE(SUM(gd.SoTien), 0) AS DaTra
                            FROM dbo.GIAO_DICH_THANH_TOAN AS gd
                            WHERE gd.MaHoaDon = hd.MaHoaDon AND gd.TrangThai = N'Thành công') AS tt
               WHERE tt.DaTra > hd.TongPhaiTra)
        THROW 50541, N'RB14 (GIAO_DICH_THANH_TOAN.SoTien): Tổng các giao dịch thành công vượt quá tổng phải trả của hóa đơn.', 1;

    UPDATE hd
    SET hd.TrangThaiThanhToan = CASE WHEN tt.DaTra = hd.TongPhaiTra THEN N'Đã thanh toán'
                                     WHEN tt.DaTra > 0 THEN N'Thanh toán một phần'
                                     ELSE N'Chưa thanh toán' END
    FROM dbo.HOA_DON AS hd
    JOIN @HoaDonBiAnhHuong AS a ON a.MaHoaDon = hd.MaHoaDon
    OUTER APPLY (SELECT COALESCE(SUM(gd.SoTien), 0) AS DaTra
                 FROM dbo.GIAO_DICH_THANH_TOAN AS gd
                 WHERE gd.MaHoaDon = hd.MaHoaDon AND gd.TrangThai = N'Thành công') AS tt;

    UPDATE p
    SET p.TrangThai = N'Đã thanh toán'
    FROM dbo.PHIEN_CHOI AS p
    JOIN dbo.HOA_DON AS hd      ON hd.MaPhien = p.MaPhien
    JOIN @HoaDonBiAnhHuong AS a ON a.MaHoaDon = hd.MaHoaDon
    WHERE hd.TrangThaiThanhToan = N'Đã thanh toán'
      AND p.TrangThai <> N'Đã thanh toán';
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HOA_DON_RB14_KhoaHoaDonDaTra
--   RB14: hóa đơn đã thanh toán không được sửa, xóa thông tin tiền; tổng phải trả mới không nhỏ hơn số đã trả;
--         chỉ đánh dấu 'Đã thanh toán' khi tổng giao dịch thành công bằng tổng phải trả.
--   Chạy khi: INSERT, UPDATE, DELETE trên HOA_DON.
--   Mã lỗi: 50543, 50541, 50544.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB14_KhoaHoaDonDaTra
ON dbo.HOA_DON
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM deleted AS d
               LEFT JOIN inserted AS i ON i.MaHoaDon = d.MaHoaDon
               WHERE d.TrangThaiThanhToan = N'Đã thanh toán'
                 AND (i.MaHoaDon IS NULL
                      OR EXISTS (SELECT d.TienGioChoi, d.TienMon, d.TienGiam, d.TienGiamTheoHang, d.TienGiamKhuyenMai,
                                        d.TongPhaiTra, d.MaPhien, d.MaKM, d.ThoiDiemLap, d.TrangThaiThanhToan
                                 EXCEPT
                                 SELECT i.TienGioChoi, i.TienMon, i.TienGiam, i.TienGiamTheoHang, i.TienGiamKhuyenMai,
                                        i.TongPhaiTra, i.MaPhien, i.MaKM, i.ThoiDiemLap, i.TrangThaiThanhToan)))
        THROW 50543, N'RB14 (HOA_DON): Hóa đơn đã thanh toán, không được sửa hoặc xóa thông tin tiền.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               OUTER APPLY (SELECT COALESCE(SUM(gd.SoTien), 0) AS DaTra
                            FROM dbo.GIAO_DICH_THANH_TOAN AS gd
                            WHERE gd.MaHoaDon = i.MaHoaDon AND gd.TrangThai = N'Thành công') AS tt
               WHERE tt.DaTra > i.TongPhaiTra)
        THROW 50541, N'RB14 (HOA_DON.TongPhaiTra): Tổng phải trả mới nhỏ hơn số tiền đã thanh toán thành công.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               OUTER APPLY (SELECT COALESCE(SUM(gd.SoTien), 0) AS DaTra
                            FROM dbo.GIAO_DICH_THANH_TOAN AS gd
                            WHERE gd.MaHoaDon = i.MaHoaDon AND gd.TrangThai = N'Thành công') AS tt
               WHERE i.TrangThaiThanhToan = N'Đã thanh toán' AND tt.DaTra <> i.TongPhaiTra)
        THROW 50544, N'RB14 (HOA_DON.TrangThaiThanhToan): Chưa thanh toán đủ, không được đánh dấu Đã thanh toán.', 1;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_PHIEN_CHOI_RB14_KhoaPhienDaTra
--   RB14: phiên đã thanh toán không được đổi trạng thái, giờ chơi, khách hàng; trạng thái 'Đã thanh toán'
--         của phiên phải khớp với hóa đơn đã thanh toán.
--   Chạy khi: UPDATE trên PHIEN_CHOI.
--   Mã lỗi: 50547.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PHIEN_CHOI_RB14_KhoaPhienDaTra
ON dbo.PHIEN_CHOI
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN deleted AS d         ON d.MaPhien = i.MaPhien
               LEFT JOIN dbo.HOA_DON AS hd ON hd.MaPhien = i.MaPhien
               WHERE (d.TrangThai = N'Đã thanh toán'
                      AND (i.TrangThai <> N'Đã thanh toán'
                           OR EXISTS (SELECT d.GioBatDau, d.GioKetThuc, d.MaKH, d.TongThoiGianChoi
                                      EXCEPT
                                      SELECT i.GioBatDau, i.GioKetThuc, i.MaKH, i.TongThoiGianChoi)))
                  OR (hd.TrangThaiThanhToan = N'Đã thanh toán' AND i.TrangThai <> N'Đã thanh toán')
                  OR (i.TrangThai = N'Đã thanh toán'
                      AND (hd.MaHoaDon IS NULL OR hd.TrangThaiThanhToan <> N'Đã thanh toán')))
        THROW 50547, N'RB14 (PHIEN_CHOI.TrangThai): Phiên đã thanh toán không được sửa, và trạng thái Đã thanh toán của phiên phải khớp với hóa đơn.', 1;
END;
GO


-- ############################################################################
-- PHẦN 5. PHONG: RB15
-- Điểm tối thiểu khác nhau, điểm tối thiểu >= 0, phần trăm giảm 0-100 và điểm tích lũy >= 0 nằm ở CHECK, UNIQUE
-- của HANG_THANH_VIEN và HOI_VIEN.
-- ############################################################################

-- ----------------------------------------------------------------------------
-- trg_HOI_VIEN_RB15_CapNhatHang
--   RB15: hạng của hội viên là hạng có điểm tối thiểu lớn nhất không vượt quá điểm tích lũy.
--   Tính: HOI_VIEN.MaHang (kể cả khi ai đó sửa tay MaHang sai).
--   Chạy khi: INSERT, UPDATE(DiemTichLuy, MaHang) trên HOI_VIEN.
--   Mã lỗi: 50218 không có hạng nào phù hợp.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOI_VIEN_RB15_CapNhatHang
ON dbo.HOI_VIEN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(DiemTichLuy) OR UPDATE(MaHang)) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               WHERE NOT EXISTS (SELECT 1 FROM dbo.HANG_THANH_VIEN AS h WHERE h.DiemToiThieu <= i.DiemTichLuy))
        THROW 50218, N'RB15 (HOI_VIEN.DiemTichLuy): Không có hạng thành viên nào phù hợp với điểm tích lũy của hội viên.', 1;

    WITH HangChuan AS (
        SELECT i.MaKH,
               (SELECT TOP (1) h.MaHang
                FROM dbo.HANG_THANH_VIEN AS h
                WHERE h.DiemToiThieu <= i.DiemTichLuy
                ORDER BY h.DiemToiThieu DESC) AS MaHangChuan
        FROM inserted AS i
    )
    UPDATE hv
    SET hv.MaHang = hc.MaHangChuan
    FROM dbo.HOI_VIEN AS hv
    JOIN HangChuan AS hc ON hc.MaKH = hv.MaKH
    WHERE hv.MaHang <> hc.MaHangChuan;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HANG_THANH_VIEN_RB15_XoaHang  (INSTEAD OF DELETE)
--   RB15: không xóa hạng đang có hội viên; hạng không ai dùng thì xóa bình thường.
--   Chạy khi: DELETE trên HANG_THANH_VIEN.
--   Mã lỗi: 50219.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HANG_THANH_VIEN_RB15_XoaHang
ON dbo.HANG_THANH_VIEN
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.HOI_VIEN AS hv JOIN deleted AS d ON d.MaHang = hv.MaHang)
        THROW 50219, N'RB15 (HANG_THANH_VIEN.MaHang): Không xóa được hạng thành viên đang có hội viên.', 1;

    DELETE h
    FROM dbo.HANG_THANH_VIEN AS h
    JOIN deleted AS d ON d.MaHang = h.MaHang;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HANG_THANH_VIEN_RB15_DongBoHang
--   RB15: thêm hạng mới hoặc đổi mốc điểm tối thiểu thì xếp lại hạng cho mọi hội viên.
--   Tính: HOI_VIEN.MaHang của các hội viên đang lệch.
--   Chạy khi: INSERT, UPDATE(DiemToiThieu) trên HANG_THANH_VIEN.
--   Mã lỗi: 50218 có hội viên không còn hạng phù hợp.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HANG_THANH_VIEN_RB15_DongBoHang
ON dbo.HANG_THANH_VIEN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(DiemToiThieu) RETURN;

    IF EXISTS (SELECT 1
               FROM dbo.HOI_VIEN AS hv
               WHERE NOT EXISTS (SELECT 1 FROM dbo.HANG_THANH_VIEN AS h WHERE h.DiemToiThieu <= hv.DiemTichLuy))
        THROW 50218, N'RB15 (HANG_THANH_VIEN.DiemToiThieu): Sau khi đổi mốc điểm có hội viên không còn hạng thành viên phù hợp.', 1;

    WITH HangChuan AS (
        SELECT hv.MaKH,
               (SELECT TOP (1) h.MaHang
                FROM dbo.HANG_THANH_VIEN AS h
                WHERE h.DiemToiThieu <= hv.DiemTichLuy
                ORDER BY h.DiemToiThieu DESC) AS MaHangChuan
        FROM dbo.HOI_VIEN AS hv
    )
    UPDATE hv
    SET hv.MaHang = hc.MaHangChuan
    FROM dbo.HOI_VIEN AS hv
    JOIN HangChuan AS hc ON hc.MaKH = hv.MaKH
    WHERE hv.MaHang <> hc.MaHangChuan;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HOA_DON_RB15_TichDiemHoiVien
--   RB15: hóa đơn của khách không phải hội viên không được cộng điểm; hóa đơn đã thanh toán của hội viên có
--         điểm cộng bằng 1 điểm cho mỗi 10.000 đồng tổng phải trả (lấy phần nguyên).
--   Tính: khi hóa đơn của hội viên chuyển sang 'Đã thanh toán': ghi HOA_DON.DiemCong trước, rồi cộng vào
--         HOI_VIEN.DiemTichLuy (trg_HOI_VIEN_RB15_CapNhatHang tự nâng hạng). Ghi DiemCong trước để
--         trg_HOA_DON_RB13_TienGiam không so khoản giảm với phần trăm của hạng mới.
--   Chạy khi: INSERT, UPDATE trên HOA_DON.
--   Mã lỗi: 50216, 50217.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB15_TichDiemHoiVien
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN dbo.PHIEN_CHOI AS pc    ON pc.MaPhien = i.MaPhien
               LEFT JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = pc.MaKH
               WHERE hv.MaKH IS NULL AND i.DiemCong > 0)
        THROW 50216, N'RB15 (HOA_DON.DiemCong): Hóa đơn của khách không phải hội viên không được cộng điểm.', 1;

    -- Chỉ xét hóa đơn đã thanh toán từ trước lệnh này; hóa đơn vừa chuyển sang 'Đã thanh toán' được ghi
    -- DiemCong đúng công thức ở bước dưới
    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN deleted AS d       ON d.MaHoaDon = i.MaHoaDon
               JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
               JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = pc.MaKH
               WHERE d.TrangThaiThanhToan = N'Đã thanh toán'
                 AND i.TrangThaiThanhToan = N'Đã thanh toán'
                 AND i.DiemCong <> 0
                 AND i.DiemCong <> FLOOR(i.TongPhaiTra / 10000.0))
        THROW 50217, N'RB15 (HOA_DON.DiemCong): Điểm cộng phải bằng 1 điểm cho mỗi 10.000 đồng tổng phải trả.', 1;

    IF NOT UPDATE(TrangThaiThanhToan) RETURN;

    UPDATE hd
    SET hd.DiemCong = FLOOR(hd.TongPhaiTra / 10000.0)
    FROM dbo.HOA_DON AS hd
    JOIN inserted AS i        ON i.MaHoaDon = hd.MaHoaDon
    LEFT JOIN deleted AS d    ON d.MaHoaDon = i.MaHoaDon
    JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
    JOIN dbo.HOI_VIEN AS hv   ON hv.MaKH = pc.MaKH
    WHERE i.TrangThaiThanhToan = N'Đã thanh toán'
      AND (d.MaHoaDon IS NULL OR d.TrangThaiThanhToan <> N'Đã thanh toán')
      AND hd.DiemCong <> FLOOR(hd.TongPhaiTra / 10000.0);

    WITH HoaDonMoiThanhToan AS (
        SELECT pc.MaKH, FLOOR(i.TongPhaiTra / 10000.0) AS DiemDuocCong
        FROM inserted AS i
        LEFT JOIN deleted AS d    ON d.MaHoaDon = i.MaHoaDon
        JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
        JOIN dbo.HOI_VIEN AS hv   ON hv.MaKH = pc.MaKH
        WHERE i.TrangThaiThanhToan = N'Đã thanh toán'
          AND (d.MaHoaDon IS NULL OR d.TrangThaiThanhToan <> N'Đã thanh toán')
    )
    UPDATE hv
    SET hv.DiemTichLuy = hv.DiemTichLuy + x.TongDiemThem
    FROM dbo.HOI_VIEN AS hv
    JOIN (SELECT MaKH, SUM(DiemDuocCong) AS TongDiemThem
          FROM HoaDonMoiThanhToan
          WHERE DiemDuocCong > 0
          GROUP BY MaKH) AS x ON x.MaKH = hv.MaKH;
END;
GO

-- ----------------------------------------------------------------------------
-- trg_HOA_DON_RB15_BaoVeDiemCong
--   RB15: hóa đơn đã thanh toán chỉ được đổi DiemCong sang đúng giá trị dẫn xuất
--         (hội viên: FLOOR(TongPhaiTra / 10000); khách không phải hội viên: 0).
--   Chạy khi: UPDATE(DiemCong) trên HOA_DON.
--   Mã lỗi: 50217.
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB15_BaoVeDiemCong
ON dbo.HOA_DON
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(DiemCong) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN deleted AS d            ON d.MaHoaDon = i.MaHoaDon
               JOIN dbo.PHIEN_CHOI AS pc    ON pc.MaPhien = i.MaPhien
               LEFT JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = pc.MaKH
               WHERE d.TrangThaiThanhToan = N'Đã thanh toán'
                 AND i.DiemCong <> d.DiemCong
                 AND i.DiemCong <> CASE WHEN hv.MaKH IS NOT NULL THEN FLOOR(i.TongPhaiTra / 10000.0) ELSE 0 END)
        THROW 50217, N'RB15 (HOA_DON.DiemCong): Không được sửa điểm cộng của hóa đơn đã thanh toán.', 1;
END;
GO
