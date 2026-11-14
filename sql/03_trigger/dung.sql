-- RB9 đã làm bằng cột tính toán DOAN_SU_DUNG_BAN.TienGio (01_bang), làm tròn ở hóa đơn (RB12), không cần trigger.

USE BidaHub;
GO

-- RB7: MỖI BÀN CHỈ THUỘC TỐI ĐA MỘT ĐOẠN ĐANG DIỄN RA
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_DoanSuDungBan_BanDangDung'
               AND object_id = OBJECT_ID(N'dbo.DOAN_SU_DUNG_BAN'))
    CREATE UNIQUE INDEX UQ_DoanSuDungBan_BanDangDung
    ON dbo.DOAN_SU_DUNG_BAN(MaBan) WHERE GioKetThucDung IS NULL;
GO

-- RB7.1: KIỂM TRA ĐOẠN SỬ DỤNG BÀN
-- Điều kiện:
--    1. Không mở đoạn mới trên bàn 'Đang bảo trì' hoặc 'Ngưng sử dụng'.
--    2. Đoạn nằm trong khoảng thời gian của phiên.
--    3. Các đoạn của cùng một phiên không chồng lấn.
--    4. Một bàn không thuộc hai đoạn chồng lấn thời gian.
-- Mã lỗi:
--    50471, 50472, 50473, 50474
CREATE OR ALTER TRIGGER dbo.trg_RB7_KiemTraDoanSuDungBan
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS i
        LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
        JOIN dbo.BAN AS b ON b.MaBan = i.MaBan
        WHERE d.MaPhien IS NULL AND b.TrangThai IN (N'Đang bảo trì', N'Ngưng sử dụng'))
    BEGIN
        THROW 50471, N'RB7: Không được mở đoạn sử dụng trên bàn đang bảo trì hoặc ngưng sử dụng.', 1;
    END;

    IF EXISTS (SELECT 1 FROM inserted AS i
        JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = i.MaPhien
        WHERE i.GioBatDauDung < p.GioBatDau
           OR (p.GioKetThuc IS NOT NULL AND (i.GioKetThucDung IS NULL OR i.GioKetThucDung > p.GioKetThuc)))
    BEGIN
        THROW 50472, N'RB7: Đoạn sử dụng bàn phải nằm trong khoảng thời gian của phiên.', 1;
    END;

    IF EXISTS (SELECT 1 FROM inserted AS i
        JOIN dbo.DOAN_SU_DUNG_BAN AS o ON o.MaPhien = i.MaPhien AND o.SoThuTuDoan <> i.SoThuTuDoan
        WHERE o.GioBatDauDung < ISNULL(i.GioKetThucDung, '9999-12-31')
          AND i.GioBatDauDung < ISNULL(o.GioKetThucDung, '9999-12-31'))
    BEGIN
        THROW 50473, N'RB7: Các đoạn sử dụng bàn của cùng một phiên không được chồng lấn.', 1;
    END;

    IF EXISTS (SELECT 1 FROM inserted AS i
        JOIN dbo.DOAN_SU_DUNG_BAN AS o ON o.MaBan = i.MaBan
         AND NOT (o.MaPhien = i.MaPhien AND o.SoThuTuDoan = i.SoThuTuDoan)
        WHERE o.GioBatDauDung < ISNULL(i.GioKetThucDung, '9999-12-31')
          AND i.GioBatDauDung < ISNULL(o.GioKetThucDung, '9999-12-31'))
    BEGIN
        THROW 50474, N'RB7: Bàn đã thuộc một đoạn sử dụng khác trong khoảng thời gian này.', 1;
    END;
END;
GO

-- RB7.2: CẬP NHẬT TRẠNG THÁI BÀN THEO ĐOẠN SỬ DỤNG
-- Bàn có đoạn đang diễn ra: 'Đang chơi'; còn phiếu 'Đã xác nhận' giữ bàn: 'Đã đặt'; còn lại: 'Trống'.
-- Không đổi bàn 'Đang bảo trì', 'Ngưng sử dụng' (chỉ quản lý đặt).
CREATE OR ALTER TRIGGER dbo.trg_RB7_CapNhatTrangThaiBan
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH BanBiAnhHuong AS (
        SELECT MaBan FROM inserted
        UNION
        SELECT MaBan FROM deleted
    )
    UPDATE b
    SET b.TrangThai = CASE
            WHEN EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                         WHERE d.MaBan = b.MaBan AND d.GioKetThucDung IS NULL) THEN N'Đang chơi'
            WHEN EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g
                         JOIN dbo.PHIEU_DAT_BAN AS pd ON pd.MaDatBan = g.MaDatBan
                         WHERE g.MaBan = b.MaBan AND pd.TrangThai = N'Đã xác nhận') THEN N'Đã đặt'
            ELSE N'Trống'
        END
    FROM dbo.BAN AS b
    JOIN BanBiAnhHuong AS a ON a.MaBan = b.MaBan
    WHERE b.TrangThai NOT IN (N'Đang bảo trì', N'Ngưng sử dụng');
END;
GO

-- RB7.3: KIỂM TRA THỜI GIAN PHIÊN KHI SỬA GIỜ BẮT ĐẦU, GIỜ KẾT THÚC
-- Mã lỗi:
--    50475: Có đoạn sử dụng bàn nằm ngoài khoảng thời gian mới của phiên.
CREATE OR ALTER TRIGGER dbo.trg_RB7_KiemTraThoiGianPhien
ON dbo.PHIEN_CHOI
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS p
        JOIN deleted AS d ON d.MaPhien = p.MaPhien
        JOIN dbo.DOAN_SU_DUNG_BAN AS o ON o.MaPhien = p.MaPhien
        WHERE (p.GioBatDau <> d.GioBatDau
               OR ISNULL(p.GioKetThuc, '9999-12-31') <> ISNULL(d.GioKetThuc, '9999-12-31'))
          AND (o.GioBatDauDung < p.GioBatDau
               OR (p.GioKetThuc IS NOT NULL AND o.GioKetThucDung > p.GioKetThuc)))
    BEGIN
        THROW 50475, N'RB7: Có đoạn sử dụng bàn nằm ngoài khoảng thời gian của phiên.', 1;
    END;
END;
GO

-- RB8.1: KIỂM TRA KHUNG GIÁ CỦA ĐOẠN
-- Điều kiện:
--    1. Khung giá thuộc đúng loại bàn của bàn được sử dụng.
--    2. Khung giá chứa thời điểm bắt đầu đoạn, đúng loại ngày
--       ('Ngày thường': Thứ Hai - Thứ Sáu, 'Cuối tuần': Thứ Bảy, Chủ nhật, 'Ngày lễ': không có lịch lễ nên không kiểm tra).
--    3. Đoạn không đi qua thời điểm đổi khung giá.
-- Mã lỗi:
--    50481, 50482, 50483
CREATE OR ALTER TRIGGER dbo.trg_RB8_KiemTraKhungGia
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS i
        LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
        JOIN dbo.BAN AS b ON b.MaBan = i.MaBan
        WHERE d.MaPhien IS NULL AND b.MaLoaiBan <> i.MaLoaiBan)
    BEGIN
        THROW 50481, N'RB8: Khung giá của đoạn phải thuộc đúng loại bàn của bàn được sử dụng.', 1;
    END;

    -- 1900-01-01 là Thứ Hai: ThuTrongTuan 0 - 4 là Thứ Hai - Thứ Sáu, 5 - 6 là Thứ Bảy, Chủ nhật (không phụ thuộc DATEFIRST)
    IF EXISTS (SELECT 1 FROM inserted AS i
        LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
        JOIN dbo.KHUNG_GIA AS k ON k.MaLoaiBan = i.MaLoaiBan AND k.SoThuTuKhung = i.SoThuTuKhung
        CROSS APPLY (SELECT DATEDIFF(DAY, '19000101', CAST(i.GioBatDauDung AS DATE)) % 7 AS ThuTrongTuan) AS t
        WHERE d.MaPhien IS NULL
          AND (CAST(i.GioBatDauDung AS TIME(0)) < k.GioBatDau
               OR CAST(i.GioBatDauDung AS TIME(0)) >= k.GioKetThuc
               OR (k.LoaiNgayApDung = N'Ngày thường' AND t.ThuTrongTuan >= 5)
               OR (k.LoaiNgayApDung = N'Cuối tuần' AND t.ThuTrongTuan < 5)))
    BEGIN
        THROW 50482, N'RB8: Khung giá phải chứa thời điểm bắt đầu đoạn và đúng loại ngày áp dụng.', 1;
    END;

    IF EXISTS (SELECT 1 FROM inserted AS i
        JOIN dbo.KHUNG_GIA AS k ON k.MaLoaiBan = i.MaLoaiBan AND k.SoThuTuKhung = i.SoThuTuKhung
        WHERE i.GioKetThucDung IS NOT NULL
          AND (CAST(i.GioKetThucDung AS DATE) <> CAST(i.GioBatDauDung AS DATE)
               OR CAST(i.GioKetThucDung AS TIME(0)) > k.GioKetThuc))
    BEGIN
        THROW 50483, N'RB8: Đoạn không được đi qua thời điểm đổi khung giá, cần kết thúc đoạn và mở đoạn mới.', 1;
    END;
END;
GO

-- RB8.2: CHỐT ĐƠN GIÁ CỦA ĐOẠN
-- Điều kiện:
--    1. Đoạn mới: DonGiaApDung = KHUNG_GIA.DonGiaMoiGio.
--    2. Đoạn đã ghi chỉ được cập nhật GioKetThucDung (chuyển bàn, đổi khung thì mở đoạn mới).
-- Mã lỗi:
--    50484, 50485
CREATE OR ALTER TRIGGER dbo.trg_RB8_ChotDonGiaDoan
ON dbo.DOAN_SU_DUNG_BAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted AS d
        LEFT JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDoan = d.SoThuTuDoan
        WHERE i.MaPhien IS NULL
           OR EXISTS (SELECT d.GioBatDauDung, d.DonGiaApDung, d.MaBan, d.MaLoaiBan, d.SoThuTuKhung
                      EXCEPT
                      SELECT i.GioBatDauDung, i.DonGiaApDung, i.MaBan, i.MaLoaiBan, i.SoThuTuKhung))
    BEGIN
        THROW 50485, N'RB8: Đoạn đã ghi chỉ được cập nhật GioKetThucDung, đơn giá áp dụng đã được chốt.', 1;
    END;

    IF EXISTS (SELECT 1 FROM inserted AS i
        LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDoan = i.SoThuTuDoan
        JOIN dbo.KHUNG_GIA AS k ON k.MaLoaiBan = i.MaLoaiBan AND k.SoThuTuKhung = i.SoThuTuKhung
        WHERE d.MaPhien IS NULL AND i.DonGiaApDung <> k.DonGiaMoiGio)
    BEGIN
        THROW 50484, N'RB8: DonGiaApDung phải bằng đơn giá mỗi giờ của khung giá.', 1;
    END;
END;
GO

-- RB8.3: PHIÊN KẾT THÚC THÌ CÁC ĐOẠN PHẢI PHỦ KÍN PHIÊN
-- Điều kiện (khi phiên có GioKetThuc):
--    1. Phiên có ít nhất một đoạn và mọi đoạn đã đóng.
--    2. Có đoạn bắt đầu đúng GioBatDau, có đoạn kết thúc đúng GioKetThuc, các đoạn nối liền nhau.
-- Mã lỗi:
--    50486, 50487
CREATE OR ALTER TRIGGER dbo.trg_RB8_KiemTraPhuKinPhien
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

    IF EXISTS (SELECT 1 FROM @PhienKetThuc AS p
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o WHERE o.MaPhien = p.MaPhien)
           OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                      WHERE o.MaPhien = p.MaPhien AND o.GioKetThucDung IS NULL))
    BEGIN
        THROW 50486, N'RB8: Phiên kết thúc phải có ít nhất một đoạn và mọi đoạn sử dụng bàn đã đóng.', 1;
    END;

    IF EXISTS (SELECT 1 FROM @PhienKetThuc AS p
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                          WHERE o.MaPhien = p.MaPhien AND o.GioBatDauDung = p.GioBatDau)
           OR NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                          WHERE o.MaPhien = p.MaPhien AND o.GioKetThucDung = p.GioKetThuc)
           OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS s
                      WHERE s.MaPhien = p.MaPhien AND s.GioBatDauDung <> p.GioBatDau
                        AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS t
                                        WHERE t.MaPhien = s.MaPhien AND t.GioKetThucDung = s.GioBatDauDung)))
    BEGIN
        THROW 50487, N'RB8: Các đoạn sử dụng bàn phải phủ kín toàn bộ thời gian của phiên.', 1;
    END;
END;
GO

-- RB8.4: GIỮ PHỦ KÍN KHI THÊM, SỬA, XÓA ĐOẠN CỦA PHIÊN ĐÃ KẾT THÚC
-- Mã lỗi:
--    50486, 50487 (như RB8.3)
CREATE OR ALTER TRIGGER dbo.trg_RB8_PhuKinKhiSuaDoan
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

    IF EXISTS (SELECT 1 FROM @PhienKetThuc AS p
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o WHERE o.MaPhien = p.MaPhien)
           OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                      WHERE o.MaPhien = p.MaPhien AND o.GioKetThucDung IS NULL))
    BEGIN
        THROW 50486, N'RB8: Phiên kết thúc phải có ít nhất một đoạn và mọi đoạn sử dụng bàn đã đóng.', 1;
    END;

    IF EXISTS (SELECT 1 FROM @PhienKetThuc AS p
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                          WHERE o.MaPhien = p.MaPhien AND o.GioBatDauDung = p.GioBatDau)
           OR NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS o
                          WHERE o.MaPhien = p.MaPhien AND o.GioKetThucDung = p.GioKetThuc)
           OR EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS s
                      WHERE s.MaPhien = p.MaPhien AND s.GioBatDauDung <> p.GioBatDau
                        AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS t
                                        WHERE t.MaPhien = s.MaPhien AND t.GioKetThucDung = s.GioBatDauDung)))
    BEGIN
        THROW 50487, N'RB8: Các đoạn sử dụng bàn phải phủ kín toàn bộ thời gian của phiên.', 1;
    END;
END;
GO

-- RB10.1: KIỂM TRA DÒNG GỌI MÓN MỚI
-- Điều kiện:
--    1. Mặt hàng đang bán.
--    2. Phiên đang chơi, thời điểm gọi không trước giờ bắt đầu phiên.
--    3. DonGiaTaiThoiDiemGoi = MAT_HANG.DonGiaNiemYet (RB8: chốt giá khi gọi).
--    4. Dòng mới không được ở trạng thái 'Đã hủy'.
-- Mã lỗi:
--    50401, 50402, 50403, 50404
CREATE OR ALTER TRIGGER dbo.trg_RB10_KiemTraGoiMon
ON dbo.DONG_GOI_MON
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted AS i
        JOIN dbo.MAT_HANG AS mh ON mh.MaMatHang = i.MaMatHang
        WHERE mh.TrangThaiKinhDoanh <> N'Đang bán')
    BEGIN
        THROW 50401, N'RB10: Chỉ được gọi mặt hàng đang bán.', 1;
    END;

    IF EXISTS (SELECT 1 FROM inserted AS i
        JOIN dbo.PHIEN_CHOI AS p ON p.MaPhien = i.MaPhien
        WHERE p.TrangThai <> N'Đang chơi' OR i.ThoiDiemGoi < p.GioBatDau)
    BEGIN
        THROW 50402, N'RB10: Chỉ được ghi dòng gọi món trong phiên đang chơi.', 1;
    END;

    IF EXISTS (SELECT 1 FROM inserted AS i
        JOIN dbo.MAT_HANG AS mh ON mh.MaMatHang = i.MaMatHang
        WHERE i.DonGiaTaiThoiDiemGoi <> mh.DonGiaNiemYet)
    BEGIN
        THROW 50403, N'RB10: DonGiaTaiThoiDiemGoi phải bằng đơn giá niêm yết của mặt hàng.', 1;
    END;

    IF EXISTS (SELECT 1 FROM inserted WHERE TrangThaiPhucVu = N'Đã hủy')
    BEGIN
        THROW 50404, N'RB10: Dòng gọi món mới không được ở trạng thái Đã hủy.', 1;
    END;
END;
GO

-- RB10.2: KHÓA DÒNG GỌI MÓN ĐÃ GHI
-- Điều kiện:
--    1. Không được xóa dòng gọi món (giữ lịch sử bán).
--    2. Không được sửa thời điểm gọi, số lượng, đơn giá, mặt hàng, nhân viên ghi nhận.
--    3. Chỉ chuyển 'Chờ chế biến' sang 'Đã phục vụ' hoặc 'Đã hủy'.
-- Mã lỗi:
--    50405, 50406, 50407
CREATE OR ALTER TRIGGER dbo.trg_RB10_KhoaDongGoiMon
ON dbo.DONG_GOI_MON
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN
        THROW 50405, N'RB10: Không được xóa dòng gọi món, chỉ được hủy khi còn chờ chế biến.', 1;
    END;

    IF EXISTS (SELECT 1 FROM deleted AS d
        LEFT JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDong = d.SoThuTuDong
        WHERE i.MaPhien IS NULL
           OR EXISTS (SELECT d.ThoiDiemGoi, d.SoLuong, d.DonGiaTaiThoiDiemGoi, d.MaMatHang, d.MaNVGhiNhan
                      EXCEPT
                      SELECT i.ThoiDiemGoi, i.SoLuong, i.DonGiaTaiThoiDiemGoi, i.MaMatHang, i.MaNVGhiNhan))
    BEGIN
        THROW 50406, N'RB10: Dòng gọi món đã ghi chỉ được đổi trạng thái phục vụ và ghi chú.', 1;
    END;

    IF EXISTS (SELECT 1 FROM deleted AS d
        JOIN inserted AS i ON i.MaPhien = d.MaPhien AND i.SoThuTuDong = d.SoThuTuDong
        WHERE i.TrangThaiPhucVu <> d.TrangThaiPhucVu AND d.TrangThaiPhucVu <> N'Chờ chế biến')
    BEGIN
        THROW 50407, N'RB10: Chỉ được chuyển dòng đang chờ chế biến sang Đã phục vụ hoặc Đã hủy.', 1;
    END;
END;
GO

-- RB10.3: CẬP NHẬT SỐ LƯỢNG TỒN KHI GỌI MÓN, HỦY MÓN
-- Gọi món: SoLuongTon giảm đúng SoLuong; hủy dòng đang chờ chế biến: hoàn lại SoLuong.
-- Mã lỗi:
--    50408: Không đủ số lượng tồn.
CREATE OR ALTER TRIGGER dbo.trg_RB10_CapNhatTonKho
ON dbo.DONG_GOI_MON
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BienDong TABLE (MaMatHang INT PRIMARY KEY, SoLuongChenhLech INT NOT NULL);

    INSERT INTO @BienDong (MaMatHang, SoLuongChenhLech)
    SELECT x.MaMatHang, SUM(x.ChenhLech)
    FROM (
        -- dòng mới: trừ kho
        SELECT i.MaMatHang, -i.SoLuong AS ChenhLech
        FROM inserted AS i
        LEFT JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDong = i.SoThuTuDong
        WHERE d.MaPhien IS NULL AND i.TrangThaiPhucVu <> N'Đã hủy'
        UNION ALL
        -- dòng chuyển sang 'Đã hủy': hoàn kho
        SELECT i.MaMatHang, i.SoLuong AS ChenhLech
        FROM inserted AS i
        JOIN deleted AS d ON d.MaPhien = i.MaPhien AND d.SoThuTuDong = i.SoThuTuDong
        WHERE d.TrangThaiPhucVu = N'Chờ chế biến' AND i.TrangThaiPhucVu = N'Đã hủy'
    ) AS x GROUP BY x.MaMatHang HAVING SUM(x.ChenhLech) <> 0;

    IF EXISTS (SELECT 1 FROM dbo.MAT_HANG AS mh WITH (UPDLOCK, HOLDLOCK)
        JOIN @BienDong AS bd ON bd.MaMatHang = mh.MaMatHang
        WHERE mh.SoLuongTon + bd.SoLuongChenhLech < 0)
    BEGIN
        THROW 50408, N'RB10: Số lượng tồn của mặt hàng không đủ cho dòng gọi món.', 1;
    END;

    UPDATE mh
    SET mh.SoLuongTon = mh.SoLuongTon + bd.SoLuongChenhLech
    FROM dbo.MAT_HANG AS mh
    JOIN @BienDong AS bd ON bd.MaMatHang = mh.MaMatHang;
END;
GO

-- RB7: ĐỒNG BỘ TRẠNG THÁI BÀN CỦA DỮ LIỆU MẪU (nạp trước trigger)
-- Chỉ sửa bàn lệch trạng thái 'Đang chơi' so với đoạn đang diễn ra.
UPDATE b
SET b.TrangThai = CASE
        WHEN EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                     WHERE d.MaBan = b.MaBan AND d.GioKetThucDung IS NULL) THEN N'Đang chơi'
        WHEN EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g
                     JOIN dbo.PHIEU_DAT_BAN AS pd ON pd.MaDatBan = g.MaDatBan
                     WHERE g.MaBan = b.MaBan AND pd.TrangThai = N'Đã xác nhận') THEN N'Đã đặt'
        ELSE N'Trống'
    END
FROM dbo.BAN AS b
WHERE b.TrangThai NOT IN (N'Đang bảo trì', N'Ngưng sử dụng')
  AND ((b.TrangThai <> N'Đang chơi'
        AND EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaBan = b.MaBan AND d.GioKetThucDung IS NULL))
    OR (b.TrangThai = N'Đang chơi'
        AND NOT EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d WHERE d.MaBan = b.MaBan AND d.GioKetThucDung IS NULL)));
GO
