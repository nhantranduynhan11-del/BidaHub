-- ============================================================================
-- 03_trigger/phong.sql (Phong): Ràng buộc ngữ nghĩa RB15 (Điểm tích lũy và hạng thành viên)
--
-- Nội dung RB15:
--   "Khi hóa đơn của hội viên chuyển sang đã thanh toán, điểm tích lũy của hội viên
--    tăng thêm 1 điểm cho mỗi 10.000 đồng của tổng phải trả (lấy phần nguyên);
--    hóa đơn của khách không phải hội viên không được cộng điểm.
--    Hạng của hội viên phải là hạng có điểm tối thiểu lớn nhất mà không vượt quá điểm tích lũy.
--    Điểm tối thiểu của các hạng phải khác nhau và phần trăm giảm giá của hạng nằm trong khoảng từ 0 đến 100."
--
-- Phân chia xử lý:
--   - Đã kiểm tra trong CREATE TABLE (01_bang/tao_tat_ca_bang.sql):
--       UQ_HangThanhVien_DiemToiThieu: Điểm tối thiểu giữa các hạng phải khác nhau.
--       CK_HangThanhVien_DiemToiThieu: Điểm tối thiểu >= 0.
--       CK_HangThanhVien_PhanTramGiamGia: Phần trăm giảm giá từ 0 đến 100.
--       CK_HoiVien_DiemTichLuy: Điểm tích lũy >= 0.
--
--   - Trigger trong file này (đồng bộ với PHẦN 5 của 03_trigger/tao_tat_ca_trigger.sql):
--       1. trg_HOI_VIEN_RB15_CapNhatHang: Tự động cập nhật MaHang phù hợp theo DiemTichLuy.
--       2. trg_HANG_THANH_VIEN_RB15_XoaHang: Chặn xóa hạng thành viên đang có hội viên (INSTEAD OF DELETE).
--       3. trg_HANG_THANH_VIEN_RB15_DongBoHang: Đồng bộ lại hạng cho hội viên khi thêm hạng hoặc đổi mốc điểm.
--       4. trg_HOA_DON_RB15_TichDiemHoiVien: Ghi DiemCong và tích điểm khi hóa đơn chuyển sang 'Đã thanh toán'.
--       5. trg_HOA_DON_RB15_BaoVeDiemCong: Khóa không cho sửa sai DiemCong của hóa đơn đã thanh toán.
--
-- Dải mã lỗi của Phong: 50200 - 50299 (RB15 dùng 50216 - 50219):
--   50216 (RB15): Hóa đơn của khách không phải hội viên không được cộng điểm.
--   50217 (RB15): Điểm cộng không khớp công thức 1 điểm / 10.000 đồng hoặc sửa điểm hóa đơn đã thanh toán.
--   50218 (RB15): Không có hạng thành viên nào phù hợp với điểm tích lũy của hội viên.
--   50219 (RB15): Không xóa được hạng thành viên đang có hội viên.
-- ============================================================================

USE BidaHub;
GO

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
               JOIN deleted AS d         ON d.MaHoaDon = i.MaHoaDon
               JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
               JOIN dbo.HOI_VIEN AS hv   ON hv.MaKH = pc.MaKH
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
