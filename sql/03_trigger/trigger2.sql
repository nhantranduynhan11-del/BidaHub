
USE BidaHub;
GO

-- ============================================================================
-- TRIGGER 2: TU DONG TINH THUOC TINH DAN XUAT TONG PHAI TRA
-- ============================================================================
-- Nguoi phu trach: Khang
-- Bang tac dong: HOA_DON
-- Su kien: AFTER INSERT, UPDATE
--
-- Thuoc tinh dan xuat: TongPhaiTra
-- Cong thuc:
--    TongPhaiTra = TienGioChoi + TienMon - TienGiam
--
-- Dieu kien:
--    1. Tu dong tinh TongPhaiTra khi them hoac sua hoa don.
--    2. Khong tinh lai hoa don da thanh toan.
--    3. Khong cap nhat neu gia tri da chinh xac.
--    4. Ho tro nhieu hoa don trong mot lenh.
--    5. Khong thay doi DiemCong cua Phong.
--
-- Ma loi:
--    50581: Gia tri tien hoa don khong hop le.
--    50582: TongPhaiTra sai tren hoa don da thanh toan.
-- ============================================================================

CREATE OR ALTER TRIGGER dbo.trg_HOA_DON_TinhTongPhaiTra
ON dbo.HOA_DON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    --Kiem tra du lieu tinh tien hop le
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE i.TienGioChoi IS NULL
           OR i.TienMon IS NULL
           OR i.TienGiam IS NULL
           OR i.TienGioChoi < 0
           OR i.TienMon < 0
           OR i.TienGiam < 0
           OR i.TienGiam > i.TienGioChoi + i.TienMon
    )
    BEGIN
        THROW 50581,
              N'Trigger 2: Gia tri tinh tien hoa don khong hop le.',
              1;
    END;

    --Khong duoc de sai tong tien cua hoa don da thanh toan
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE i.TrangThaiThanhToan = N'Đã thanh toán'
          AND (
              i.TongPhaiTra IS NULL
              OR i.TongPhaiTra <>
                  i.TienGioChoi + i.TienMon - i.TienGiam
          )
    )
    BEGIN
        THROW 50582,
              N'Trigger 2: Hoa don da thanh toan co TongPhaiTra khong hop le.',
              1;
    END;

    --Chi cap nhat khi TongPhaiTra chua chinh xac
    -- Tranh UPDATE khong can thiet va tranh kich hoat trigger lap
    IF EXISTS (
        SELECT 1
        FROM dbo.HOA_DON AS hd
        JOIN inserted AS i
            ON hd.MaHoaDon = i.MaHoaDon
        WHERE (
                hd.TrangThaiThanhToan IS NULL
                OR hd.TrangThaiThanhToan <> N'Đã thanh toán'
              )
          AND (
                hd.TongPhaiTra IS NULL
                OR hd.TongPhaiTra <>
                    hd.TienGioChoi + hd.TienMon - hd.TienGiam
              )
    )
    BEGIN
        UPDATE hd
        SET hd.TongPhaiTra =
            hd.TienGioChoi + hd.TienMon - hd.TienGiam
        FROM dbo.HOA_DON AS hd
        JOIN inserted AS i
            ON hd.MaHoaDon = i.MaHoaDon
        WHERE (
                hd.TrangThaiThanhToan IS NULL
                OR hd.TrangThaiThanhToan <> N'Đã thanh toán'
              )
          AND (
                hd.TongPhaiTra IS NULL
                OR hd.TongPhaiTra <>
                    hd.TienGioChoi + hd.TienMon - hd.TienGiam
              );
    END;
END;
GO
