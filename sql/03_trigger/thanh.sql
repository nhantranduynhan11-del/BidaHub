-- ============================================================================
-- 03_trigger/thanh.sql (Thành): Ràng buộc ngữ nghĩa RB4, RB5, RB6
-- Dải mã lỗi của Thành: 50300 - 50399
--
-- Danh sách mã lỗi:
--   50301 (RB4): Khung giá cùng loại bàn và cùng loại ngày áp dụng bị chồng lấn giờ.
--   50302 (RB5): Khách hàng có quá 3 phiếu đặt bàn ở trạng thái 'Chờ xác nhận'.
--   50303 (RB5): Phiếu đặt bàn 'Đã xác nhận' phải giữ ít nhất 1 bàn.
--   50304 (RB5): Không được giữ bàn đang ở trạng thái 'Đang bảo trì' hoặc 'Ngưng sử dụng'.
--   50305 (RB5): Một bàn không được giữ cho 2 phiếu 'Đã xác nhận' có khoảng giờ dự kiến chồng lấn.
--   50306 (RB6): Phiếu ở trạng thái 'Đã hủy', 'Không đến' hoặc 'Đã chuyển thành phiên' (hoặc chưa xác nhận)
--                không được dùng để mở thêm phiên chơi khác.
--   50307 (RB6): Phiên chơi xuất phát từ phiếu đặt bàn phải thuộc đúng khách hàng của phiếu đó.
--   50308 (RB6): Đoạn sử dụng bàn đầu tiên của phiên xuất phát từ phiếu đặt bàn phải dùng một trong
--                các bàn đã được giữ của phiếu đó.
-- ============================================================================

USE BidaHub;
GO

-- ============================================================================
-- 1. TRIGGER RB4: Các khung giá của cùng loại bàn và cùng loại ngày áp dụng
--    không được chồng lấn về giờ.
--    (GioKetThuc > GioBatDau và DonGiaMoiGio > 0 đã kiểm tra bằng CHECK ở bảng KHUNG_GIA)
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_KhungGia_RB4
ON dbo.KHUNG_GIA
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Hai khoảng giờ [GioBatDau, GioKetThuc) chồng lấn khi:
    -- A.GioBatDau < B.GioKetThuc AND B.GioBatDau < A.GioKetThuc
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.KHUNG_GIA AS k
          ON k.MaLoaiBan = i.MaLoaiBan
         AND k.LoaiNgayApDung = i.LoaiNgayApDung
         AND k.SoThuTuKhung <> i.SoThuTuKhung
        WHERE i.GioBatDau < k.GioKetThuc
          AND k.GioBatDau < i.GioKetThuc
    )
    BEGIN
        THROW 50301, N'RB4 (KHUNG_GIA): Khoảng giờ (GioBatDau - GioKetThuc) bị chồng lấn với một khung giá khác của cùng loại bàn và cùng loại ngày áp dụng.', 1;
    END
END;
GO

-- ============================================================================
-- 2. TRIGGER RB5 & RB6 TRÊN PHIEU_DAT_BAN:
--    - RB5: Mỗi khách hàng có tối đa 3 phiếu đang ở trạng thái 'Chờ xác nhận'.
--    - RB5: Phiếu 'Đã xác nhận' phải giữ ít nhất một bàn và không giữ bàn
--           'Đang bảo trì' / 'Ngưng sử dụng', không chồng lấn giờ với phiếu 'Đã xác nhận' khác.
--    - RB6: Nếu phiếu đã gắn với phiên chơi thì không được đổi MaKH lệch với phiên chơi.
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_PhieuDatBan_RB5_RB6
ON dbo.PHIEU_DAT_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- RB5 (1): Mỗi khách hàng có tối đa 3 phiếu đang ở trạng thái 'Chờ xác nhận'
    IF EXISTS (
        SELECT 1
        FROM dbo.PHIEU_DAT_BAN AS p
        WHERE p.TrangThai = N'Chờ xác nhận'
          AND p.MaKH IN (SELECT DISTINCT MaKH FROM inserted WHERE TrangThai = N'Chờ xác nhận')
        GROUP BY p.MaKH
        HAVING COUNT(*) > 3
    )
    BEGIN
        THROW 50302, N'RB5 (PHIEU_DAT_BAN.TrangThai): Mỗi khách hàng chỉ được có tối đa 3 phiếu đặt bàn đang ở trạng thái Chờ xác nhận.', 1;
    END

    -- RB5 (2): Phiếu ở trạng thái 'Đã xác nhận' phải giữ ít nhất một bàn trong GIU_BAN
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE i.TrangThai = N'Đã xác nhận'
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.GIU_BAN AS g
              WHERE g.MaDatBan = i.MaDatBan
          )
    )
    BEGIN
        THROW 50303, N'RB5 (PHIEU_DAT_BAN.TrangThai): Phiếu đặt bàn ở trạng thái Đã xác nhận phải giữ ít nhất một bàn trong bảng GIU_BAN.', 1;
    END

    -- RB5 (3): Phiếu 'Đã xác nhận' không được giữ bàn đang bảo trì hoặc ngưng sử dụng
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.GIU_BAN AS g ON g.MaDatBan = i.MaDatBan
        JOIN dbo.BAN AS b ON b.MaBan = g.MaBan
        WHERE i.TrangThai = N'Đã xác nhận'
          AND b.TrangThai IN (N'Đang bảo trì', N'Ngưng sử dụng')
    )
    BEGIN
        THROW 50304, N'RB5 (PHIEU_DAT_BAN): Phiếu đã xác nhận không được giữ bàn đang bảo trì hoặc ngưng sử dụng.', 1;
    END

    -- RB5 (4): Một bàn không được giữ cho hai phiếu 'Đã xác nhận' có khoảng giờ dự kiến chồng lấn nhau
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.GIU_BAN AS g1 ON g1.MaDatBan = i.MaDatBan
        JOIN dbo.GIU_BAN AS g2 ON g2.MaBan = g1.MaBan AND g2.MaDatBan <> i.MaDatBan
        JOIN dbo.PHIEU_DAT_BAN AS p2 ON p2.MaDatBan = g2.MaDatBan
        WHERE i.TrangThai = N'Đã xác nhận'
          AND p2.TrangThai = N'Đã xác nhận'
          AND i.GioBatDauDuKien < p2.GioKetThucDuKien
          AND p2.GioBatDauDuKien < i.GioKetThucDuKien
    )
    BEGIN
        THROW 50305, N'RB5 (PHIEU_DAT_BAN): Khoảng giờ dự kiến bị chồng lấn với một phiếu đặt bàn Đã xác nhận khác trên cùng một bàn.', 1;
    END

    -- RB6: Nếu phiếu đặt bàn đã có phiên chơi xuất phát từ đó thì MaKH phải trùng khớp
    IF UPDATE(MaKH) AND EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.PHIEN_CHOI AS pc ON pc.MaDatBan = i.MaDatBan
        WHERE pc.MaKH IS NULL OR pc.MaKH <> i.MaKH
    )
    BEGIN
        THROW 50307, N'RB6 (PHIEU_DAT_BAN.MaKH): Không thể đổi khách hàng của phiếu đặt bàn khác với khách hàng của phiên chơi đã mở từ phiếu đó.', 1;
    END
END;
GO

-- ============================================================================
-- 3. TRIGGER RB5 TRÊN GIU_BAN (KHI THÊM / SỬA BÀN GIỮ):
--    - Không được giữ bàn đang bảo trì hoặc ngưng sử dụng.
--    - Một bàn không được giữ cho hai phiếu 'Đã xác nhận' có khoảng giờ dự kiến chồng lấn.
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_GiuBan_RB5_ThemSua
ON dbo.GIU_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- RB5 (1): Không được giữ bàn đang ở trạng thái 'Đang bảo trì' hoặc 'Ngưng sử dụng'
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = i.MaDatBan
        JOIN dbo.BAN AS b ON b.MaBan = i.MaBan
        WHERE p.TrangThai IN (N'Chờ xác nhận', N'Đã xác nhận')
          AND b.TrangThai IN (N'Đang bảo trì', N'Ngưng sử dụng')
    )
    BEGIN
        THROW 50304, N'RB5 (GIU_BAN.MaBan): Không được giữ bàn đang ở trạng thái Đang bảo trì hoặc Ngưng sử dụng.', 1;
    END

    -- RB5 (2): Một bàn không được giữ cho hai phiếu 'Đã xác nhận' có khoảng giờ dự kiến chồng lấn nhau
    -- (khoảng giờ tính gồm giờ bắt đầu, không gồm giờ kết thúc: [GioBatDauDuKien, GioKetThucDuKien))
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.PHIEU_DAT_BAN AS p1 ON p1.MaDatBan = i.MaDatBan
        JOIN dbo.GIU_BAN AS g2 ON g2.MaBan = i.MaBan AND g2.MaDatBan <> i.MaDatBan
        JOIN dbo.PHIEU_DAT_BAN AS p2 ON p2.MaDatBan = g2.MaDatBan
        WHERE p1.TrangThai = N'Đã xác nhận'
          AND p2.TrangThai = N'Đã xác nhận'
          AND p1.GioBatDauDuKien < p2.GioKetThucDuKien
          AND p2.GioBatDauDuKien < p1.GioKetThucDuKien
    )
    BEGIN
        THROW 50305, N'RB5 (GIU_BAN): Bàn này đã được giữ cho một phiếu đặt bàn Đã xác nhận khác có khoảng giờ dự kiến chồng lấn.', 1;
    END
END;
GO

-- ============================================================================
-- 4. TRIGGER RB5 TRÊN GIU_BAN (KHI XÓA / ĐỔI PHIẾU):
--    - Phiếu 'Đã xác nhận' phải luôn giữ ít nhất một bàn (không được xóa bàn cuối cùng).
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_GiuBan_RB5_Xoa
ON dbo.GIU_BAN
AFTER DELETE, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted AS d
        JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = d.MaDatBan
        WHERE p.TrangThai = N'Đã xác nhận'
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.GIU_BAN AS g
              WHERE g.MaDatBan = p.MaDatBan
          )
    )
    BEGIN
        THROW 50303, N'RB5 (GIU_BAN): Phiếu đặt bàn Đã xác nhận phải giữ ít nhất một bàn, không được xóa bàn cuối cùng của phiếu.', 1;
    END
END;
GO

-- ============================================================================
-- 5. TRIGGER RB5 TRÊN BAN:
--    - Không được chuyển bàn sang 'Đang bảo trì' hoặc 'Ngưng sử dụng' khi bàn đó
--      đang được giữ bởi một phiếu đặt bàn 'Đã xác nhận'.
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_Ban_RB5
ON dbo.BAN
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(TrangThai) AND EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.GIU_BAN AS g ON g.MaBan = i.MaBan
        JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = g.MaDatBan
        WHERE i.TrangThai IN (N'Đang bảo trì', N'Ngưng sử dụng')
          AND p.TrangThai = N'Đã xác nhận'
    )
    BEGIN
        THROW 50304, N'RB5 (BAN.TrangThai): Không thể chuyển bàn sang Đang bảo trì hoặc Ngưng sử dụng khi bàn đang được giữ bởi phiếu đặt bàn Đã xác nhận.', 1;
    END
END;
GO

-- ============================================================================
-- 6. TRIGGER RB6 TRÊN PHIEN_CHOI:
--    - Phiếu ở trạng thái 'Đã hủy', 'Không đến' hoặc 'Đã chuyển thành phiên'
--      (hoặc 'Chờ xác nhận') thì không được dùng để mở thêm phiên khác.
--    - Phiên xuất phát từ một phiếu đặt bàn phải thuộc đúng khách hàng (MaKH) của phiếu đó.
--    - Khi mở phiên hợp lệ từ phiếu 'Đã xác nhận', tự động chuyển trạng thái phiếu sang
--      'Đã chuyển thành phiên'.
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_PhienChoi_RB6
ON dbo.PHIEN_CHOI
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Chỉ kiểm tra các dòng có gắn MaDatBan
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE MaDatBan IS NOT NULL)
        RETURN;

    -- RB6 (1): Kiểm tra trạng thái phiếu khi mở phiên mới hoặc khi đổi MaDatBan sang phiếu khác
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien
        JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = i.MaDatBan
        WHERE i.MaDatBan IS NOT NULL
          AND (d.MaPhien IS NULL OR ISNULL(d.MaDatBan, -1) <> i.MaDatBan)
          AND (
              p.TrangThai IN (N'Đã hủy', N'Không đến', N'Chờ xác nhận')
              OR (
                  p.TrangThai = N'Đã chuyển thành phiên'
                  AND EXISTS (
                      SELECT 1
                      FROM dbo.PHIEN_CHOI AS pc2
                      WHERE pc2.MaDatBan = i.MaDatBan
                        AND pc2.MaPhien <> i.MaPhien
                  )
              )
          )
    )
    BEGIN
        THROW 50306, N'RB6 (PHIEN_CHOI.MaDatBan): Phiếu đặt bàn ở trạng thái Đã hủy, Không đến, Chờ xác nhận hoặc Đã chuyển thành phiên thì không được dùng để mở thêm phiên khác.', 1;
    END

    -- Trường hợp phiếu đã ở trạng thái 'Đã chuyển thành phiên' trước khi mở phiên (không có phiên cũ)
    -- nhưng thực hiện INSERT phiên mới khi phiếu không phải 'Đã xác nhận'
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien
        JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = i.MaDatBan
        WHERE i.MaDatBan IS NOT NULL
          AND d.MaPhien IS NULL
          AND p.TrangThai = N'Đã chuyển thành phiên'
    )
    BEGIN
        THROW 50306, N'RB6 (PHIEN_CHOI.MaDatBan): Phiếu đặt bàn đã ở trạng thái Đã chuyển thành phiên, không được dùng để mở thêm phiên khác.', 1;
    END

    -- RB6 (2): Phiên xuất phát từ một phiếu đặt bàn phải thuộc đúng khách hàng của phiếu đó
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.PHIEU_DAT_BAN AS p ON p.MaDatBan = i.MaDatBan
        WHERE i.MaDatBan IS NOT NULL
          AND (i.MaKH IS NULL OR i.MaKH <> p.MaKH)
    )
    BEGIN
        THROW 50307, N'RB6 (PHIEN_CHOI.MaKH): Phiên chơi xuất phát từ một phiếu đặt bàn phải thuộc đúng khách hàng (MaKH) của phiếu đặt bàn đó.', 1;
    END

    -- Tự động cập nhật trạng thái phiếu từ 'Đã xác nhận' sang 'Đã chuyển thành phiên'
    UPDATE p
    SET p.TrangThai = N'Đã chuyển thành phiên'
    FROM dbo.PHIEU_DAT_BAN AS p
    JOIN inserted AS i ON i.MaDatBan = p.MaDatBan
    WHERE p.TrangThai = N'Đã xác nhận';
END;
GO

-- ============================================================================
-- 7. TRIGGER RB6 TRÊN DOAN_SU_DUNG_BAN:
--    - Đoạn sử dụng bàn đầu tiên (SoThuTuDoan = 1) của phiên xuất phát từ phiếu đặt bàn
--      phải dùng một trong các bàn đã được giữ trong GIU_BAN của phiếu đó.
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.trg_DoanSuDungBan_RB6
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.PHIEN_CHOI AS pc ON pc.MaPhien = i.MaPhien
        WHERE pc.MaDatBan IS NOT NULL
          AND i.SoThuTuDoan = 1
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.GIU_BAN AS g
              WHERE g.MaDatBan = pc.MaDatBan
                AND g.MaBan = i.MaBan
          )
    )
    BEGIN
        THROW 50308, N'RB6 (DOAN_SU_DUNG_BAN.MaBan): Đoạn sử dụng bàn đầu tiên của phiên xuất phát từ phiếu đặt bàn phải dùng một trong các bàn đã được giữ của phiếu đó.', 1;
    END
END;
GO

