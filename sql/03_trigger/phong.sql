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
--   - Đã kiểm tra trong bảng (01_bang/tao_tat_ca_bang.sql):
--       UQ_HangThanhVien_DiemToiThieu: Điểm tối thiểu giữa các hạng phải khác nhau.
--       CK_HangThanhVien_DiemToiThieu: Điểm tối thiểu >= 0.
--       CK_HangThanhVien_PhanTramGiamGia: Phần trăm giảm giá từ 0 đến 100.
--       CK_HoiVien_DiemTichLuy: Điểm tích lũy >= 0.
--
--   - Trigger trong file này:
--       1. trg_HOI_VIEN_RB15_CapNhatHang: Tự động cập nhật MaHang phù hợp theo DiemTichLuy.
--       2. trg_HANG_THANH_VIEN_RB15_XoaHang: Chặn xóa hạng thành viên đang có hội viên sử dụng (INSTEAD OF DELETE).
--       3. trg_HANG_THANH_VIEN_RB15_DongBoHang: Đồng bộ lại hạng cho hội viên khi đổi mốc điểm tối thiểu.
--       4. trg_HOA_DON_RB15_TichDiemHoiVien: Tính thuộc tính dẫn xuất DiemCong và tích lũy điểm khi thanh toán hóa đơn.
--       5. trg_HOA_DON_RB15_BaoVeDiemCong: Khóa, không cho sửa điểm cộng của hóa đơn đã thanh toán.
--
-- Dải mã lỗi của Phong: 50200 - 50299
--   50215 (RB15): Điểm tích lũy của hội viên không được là số âm.
--   50216 (RB15): Hóa đơn của khách hàng không phải hội viên không được cộng điểm.
--   50217 (RB15): Điểm cộng không khớp công thức 1 điểm / 10.000 VNĐ hoặc sửa điểm hóa đơn đã thanh toán.
--   50218 (RB15): Không tìm thấy hạng thành viên phù hợp với điểm tích lũy của hội viên.
--   50219 (RB15): Không thể xóa hạng thành viên đang có hội viên sử dụng.
-- ============================================================================

USE BidaHub;
GO

-- ============================================================================
-- 1. TRIGGER TRÊN BẢNG HOI_VIEN: Tự động cập nhật hạng theo điểm tích lũy
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_HOI_VIEN_RB15_CapNhatHang
ON dbo.HOI_VIEN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Kiểm tra điểm tích lũy không âm
    IF EXISTS (SELECT 1 FROM inserted WHERE DiemTichLuy < 0)
    BEGIN
        THROW 50215, N'RB15: Điểm tích lũy của hội viên không được là số âm.', 1;
    END;

    -- Kiểm tra xem có hạng thành viên phù hợp (DiemToiThieu <= DiemTichLuy) không
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.HANG_THANH_VIEN AS h
            WHERE h.DiemToiThieu <= i.DiemTichLuy
        )
    )
    BEGIN
        THROW 50218, N'RB15: Không tìm thấy hạng thành viên phù hợp với điểm tích lũy của hội viên.', 1;
    END;

    -- Tự động cập nhật MaHang = hạng có DiemToiThieu lớn nhất mà <= DiemTichLuy
    IF TRIGGER_NESTLEVEL() <= 2
    BEGIN
        ;WITH HangChuan AS (
            SELECT 
                i.MaKH,
                (
                    SELECT TOP (1) h.MaHang
                    FROM dbo.HANG_THANH_VIEN AS h
                    WHERE h.DiemToiThieu <= i.DiemTichLuy
                    ORDER BY h.DiemToiThieu DESC
                ) AS MaHangChuan
            FROM inserted AS i
        )
        UPDATE hv
        SET hv.MaHang = hc.MaHangChuan
        FROM dbo.HOI_VIEN AS hv
        JOIN HangChuan AS hc ON hc.MaKH = hv.MaKH
        WHERE hc.MaHangChuan IS NOT NULL 
          AND (hv.MaHang IS NULL OR hv.MaHang <> hc.MaHangChuan);
    END;
END;
GO

-- ============================================================================
-- 2. TRIGGER TRÊN BẢNG HANG_THANH_VIEN: Chặn xóa hạng đang có hội viên
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_HANG_THANH_VIEN_RB15_XoaHang
ON dbo.HANG_THANH_VIEN
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Chặn xóa nếu có bất kỳ hội viên nào đang thuộc về hạng bị xóa
    IF EXISTS (
        SELECT 1
        FROM dbo.HOI_VIEN AS hv
        JOIN deleted AS d ON d.MaHang = hv.MaHang
    )
    BEGIN
        THROW 50219, N'RB15: Không thể xóa hạng thành viên đang có hội viên sử dụng.', 1;
    END;

    -- Nếu không có hội viên nào dùng thì thực hiện xóa
    DELETE h
    FROM dbo.HANG_THANH_VIEN AS h
    JOIN deleted AS d ON d.MaHang = h.MaHang;
END;
GO

-- ============================================================================
-- 3. TRIGGER TRÊN BẢNG HANG_THANH_VIEN: Đồng bộ hạng khi đổi mốc điểm tối thiểu
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_HANG_THANH_VIEN_RB15_DongBoHang
ON dbo.HANG_THANH_VIEN
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Nếu có cập nhật mốc DiemToiThieu thì đồng bộ lại toàn bộ hội viên
    IF UPDATE(DiemToiThieu) AND TRIGGER_NESTLEVEL() <= 2
    BEGIN
        ;WITH HangChuanChoTatCa AS (
            SELECT 
                hv.MaKH,
                (
                    SELECT TOP (1) h.MaHang
                    FROM dbo.HANG_THANH_VIEN AS h
                    WHERE h.DiemToiThieu <= hv.DiemTichLuy
                    ORDER BY h.DiemToiThieu DESC
                ) AS MaHangMoi
            FROM dbo.HOI_VIEN AS hv
        )
        UPDATE hv
        SET hv.MaHang = hc.MaHangMoi
        FROM dbo.HOI_VIEN AS hv
        JOIN HangChuanChoTatCa AS hc ON hc.MaKH = hv.MaKH
        WHERE hc.MaHangMoi IS NOT NULL AND hv.MaHang <> hc.MaHangMoi;
    END;
END;
GO

-- ============================================================================
-- 4. TRIGGER TRÊN BẢNG HOA_DON: Tích điểm khi hóa đơn chuyển sang 'Đã thanh toán'
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB15_TichDiemHoiVien
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 4.1. Kiểm tra khách không phải hội viên thì DiemCong không được > 0
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
        LEFT JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = pc.MaKH
        WHERE hv.MaKH IS NULL AND i.DiemCong > 0
    )
    BEGIN
        THROW 50216, N'RB15: Hóa đơn của khách hàng không phải hội viên không được cộng điểm.', 1;
    END;

    -- 4.2. Kiểm tra nếu là hội viên và đã thanh toán thì điểm cộng không được sai lệch công thức
    -- (Áp dụng khi người dùng cố ý nhập DiemCong khác 0 và khác FLOOR(TongPhaiTra / 10000.0))
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
        JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = pc.MaKH
        WHERE i.TrangThaiThanhToan = N'Đã thanh toán'
          AND i.DiemCong <> 0
          AND i.DiemCong <> FLOOR(i.TongPhaiTra / 10000.0)
    )
    BEGIN
        THROW 50217, N'RB15: Điểm cộng trên hóa đơn không khớp với quy tắc 1 điểm cho mỗi 10.000 đồng tổng phải trả.', 1;
    END;

    -- 4.3. Khi hóa đơn chuyển sang trạng thái 'Đã thanh toán':
    -- Tự động tích lũy điểm cho hội viên và gán giá trị dẫn xuất DiemCong trên hóa đơn
    IF UPDATE(TrangThaiThanhToan) OR NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        -- Danh sách các hóa đơn vừa chuyển sang 'Đã thanh toán' của hội viên
        ;WITH HoaDonMoiThanhToan AS (
            SELECT 
                i.MaHoaDon,
                pc.MaKH,
                FLOOR(i.TongPhaiTra / 10000.0) AS DiemDuocCong
            FROM inserted AS i
            LEFT JOIN deleted AS d ON d.MaHoaDon = i.MaHoaDon
            JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
            JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = pc.MaKH
            WHERE i.TrangThaiThanhToan = N'Đã thanh toán'
              AND (d.MaHoaDon IS NULL OR d.TrangThaiThanhToan <> N'Đã thanh toán')
        )
        -- Tích điểm cho hội viên (khi DiemTichLuy tăng, trigger 1 sẽ tự động thăng hạng nếu đủ mốc)
        UPDATE hv
        SET hv.DiemTichLuy = hv.DiemTichLuy + hd.TongDiemThem
        FROM dbo.HOI_VIEN AS hv
        JOIN (
            SELECT MaKH, SUM(DiemDuocCong) AS TongDiemThem
            FROM HoaDonMoiThanhToan
            WHERE DiemDuocCong > 0
            GROUP BY MaKH
        ) AS hd ON hd.MaKH = hv.MaKH;

        -- Tự động cập nhật thuộc tính dẫn xuất DiemCong trên HOA_DON nếu chưa gán
        IF TRIGGER_NESTLEVEL() <= 2
        BEGIN
            UPDATE hd
            SET hd.DiemCong = FLOOR(hd.TongPhaiTra / 10000.0)
            FROM dbo.HOA_DON AS hd
            JOIN inserted AS i ON i.MaHoaDon = hd.MaHoaDon
            LEFT JOIN deleted AS d ON d.MaHoaDon = i.MaHoaDon
            JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
            JOIN dbo.HOI_VIEN AS hv ON hv.MaKH = pc.MaKH
            WHERE i.TrangThaiThanhToan = N'Đã thanh toán'
              AND (d.MaHoaDon IS NULL OR d.TrangThaiThanhToan <> N'Đã thanh toán')
              AND hd.DiemCong <> FLOOR(hd.TongPhaiTra / 10000.0);
        END;
    END;
END;
GO

-- ============================================================================
-- 5. TRIGGER BẢO VỆ ĐIỂM CỘNG: Khóa không cho sửa DiemCong khi hóa đơn đã thanh toán
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_RB15_BaoVeDiemCong
ON dbo.HOA_DON
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Bỏ qua nếu lệnh UPDATE được thực hiện từ trigger cấp trên (tự động tính điểm)
    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF UPDATE(DiemCong) AND EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d ON d.MaHoaDon = i.MaHoaDon
        WHERE d.TrangThaiThanhToan = N'Đã thanh toán'
          AND i.DiemCong <> d.DiemCong
    )
    BEGIN
        THROW 50217, N'RB15: Không thể thay đổi điểm cộng của hóa đơn đã thanh toán.', 1;
    END;
END;
GO
