-- ============================================================================
-- 02_du_lieu/phong.sql (Phong): HANG_THANH_VIEN, KHACH_HANG, KHACH_HANG_SDT, HOI_VIEN
--
-- Dữ liệu mẫu chuẩn theo thống nhất của nhóm (khóa chính kiểu INT IDENTITY, thời gian SYSDATETIME).
-- Mã tự sinh (IDENTITY) cố định theo thứ tự chèn, các thành viên khác dùng trực tiếp:
--
-- 1. HANG_THANH_VIEN:
--    MaHang 1: Đồng       (  0 điểm, giảm  0%)
--    MaHang 2: Bạc        (100 điểm, giảm  5%)
--    MaHang 3: Vàng       (300 điểm, giảm 10%)
--    MaHang 4: Bạch Kim   (600 điểm, giảm 15%)
--    MaHang 5: Kim Cương (1000 điểm, giảm 20%)
--
-- 2. KHACH_HANG (MaKH 1-10):
--    MaKH 1-5  : Hội viên có tài khoản ứng dụng (liên kết MaTK 12-16 của Nhân)
--    MaKH 6    : Hội viên đăng ký tại quầy (chưa có tài khoản app, MaTK NULL)
--    MaKH 7-10 : Khách hàng vãng lai (chưa đăng ký hội viên)
--    -> Thành (PHIEU_DAT_BAN) và Dũng (PHIEN_CHOI) có thể dùng MaKH 1-10.
--
-- 3. KHACH_HANG_SDT:
--    Mỗi khách hàng có ít nhất 1 số điện thoại 10 số (bắt đầu bằng 0).
--    Khách MaKH 1 và MaKH 4 có 2 số điện thoại (minh họa thuộc tính đa trị).
--
-- 4. HOI_VIEN (MaKH 1-6):
--    Điểm tích lũy và MaHang tuân thủ đúng ràng buộc RB15.
-- ============================================================================

USE BidaHub;
GO

-- ----------------------------------------------------------------------------
-- 1. BANG HANG_THANH_VIEN (5 hạng chuẩn)
-- ----------------------------------------------------------------------------
INSERT INTO dbo.HANG_THANH_VIEN (TenHang, DiemToiThieu, PhanTramGiamGia) VALUES
(N'Đồng',         0,  0.00),   -- MaHang = 1
(N'Bạc',        100,  5.00),   -- MaHang = 2
(N'Vàng',       300, 10.00),   -- MaHang = 3
(N'Bạch Kim',   600, 15.00),   -- MaHang = 4
(N'Kim Cương', 1000, 20.00);   -- MaHang = 5
GO

-- ----------------------------------------------------------------------------
-- 2. BANG KHACH_HANG (10 khách hàng)
-- MaKH 1-5 khớp với tài khoản MaTK 12-16 của Nhân; MaKH 6 đăng ký tại quầy; MaKH 7-10 vãng lai.
-- ----------------------------------------------------------------------------
INSERT INTO dbo.KHACH_HANG (Ho, TenDem, Ten, NgaySinh, GioiTinh) VALUES
(N'Trần',   N'Văn',   N'Bình', '1992-06-15', N'Nam'),   -- MaKH = 1  (tài khoản tranbinh92, MaTK 12)
(N'Lê',     N'Quốc',  N'Thành','1995-09-20', N'Nam'),   -- MaKH = 2  (tài khoản lethanh.bida, MaTK 13)
(N'Phạm',   N'Thị',   N'Ánh',  '1998-03-12', N'Nữ'),    -- MaKH = 3  (tài khoản ngocanh_hv, MaTK 14)
(N'Nguyễn', N'Minh',  N'Khôi', '1999-11-28', N'Nam'),   -- MaKH = 4  (tài khoản minhkhoi99, MaTK 15)
(N'Hoàng',  N'Thị',   N'Yến',  '2001-07-04', N'Nữ'),    -- MaKH = 5  (tài khoản hoangyen.hv, MaTK 16)
(N'Đỗ',     N'Tuấn',  N'Kiệt', '1996-04-18', N'Nam'),   -- MaKH = 6  (Hội viên quầy, chưa có tài khoản)
(N'Bùi',    N'Thu',   N'Trang','2002-01-20', N'Nữ'),    -- MaKH = 7  (Khách vãng lai)
(N'Đặng',   N'Đình',  N'Khôi', '1997-08-08', N'Nam'),   -- MaKH = 8  (Khách vãng lai)
(N'Ngô',    N'Thanh', N'Tùng', '1994-12-03', N'Nam'),   -- MaKH = 9  (Khách vãng lai)
(N'Vũ',     N'Thùy',  N'Linh', '2003-05-19', N'Nữ');    -- MaKH = 10 (Khách vãng lai)
GO

-- ----------------------------------------------------------------------------
-- 3. BANG KHACH_HANG_SDT (Số điện thoại - 10 chữ số bắt đầu bằng 0)
-- Khách 1 và 4 có 2 số điện thoại (thuộc tính đa trị)
-- ----------------------------------------------------------------------------
INSERT INTO dbo.KHACH_HANG_SDT (MaKH, SoDienThoai) VALUES
(1,  '0903123456'),
(1,  '0912123456'),
(2,  '0987654321'),
(3,  '0938112233'),
(4,  '0945223344'),
(4,  '0888223344'),
(5,  '0908334455'),
(6,  '0918445566'),
(7,  '0977556677'),
(8,  '0966778899'),
(9,  '0922889900'),
(10, '0933990011');
GO

-- ----------------------------------------------------------------------------
-- 4. BANG HOI_VIEN (6 hội viên)
-- Khách 1-5 có tài khoản MaTK 12-16; Khách 6 chưa có tài khoản (MaTK NULL).
-- Điểm và hạng tuân thủ đúng RB15: Hạng có DiemToiThieu lớn nhất mà <= DiemTichLuy.
-- ----------------------------------------------------------------------------
INSERT INTO dbo.HOI_VIEN (MaKH, NgayDangKy, DiemTichLuy, MaHang, MaTK) VALUES
(1, CAST('2025-06-02 08:30:00' AS DATETIME2(0)),  150, 2, 12),    -- 150 điểm  -> Hạng Bạc (MaHang 2)
(2, CAST('2025-06-18 14:15:00' AS DATETIME2(0)),  420, 3, 13),    -- 420 điểm  -> Hạng Vàng (MaHang 3)
(3, CAST('2025-07-05 09:00:00' AS DATETIME2(0)),   50, 1, 14),    -- 50 điểm   -> Hạng Đồng (MaHang 1)
(4, CAST('2025-08-12 18:45:00' AS DATETIME2(0)),  750, 4, 15),    -- 750 điểm  -> Hạng Bạch Kim (MaHang 4)
(5, CAST('2025-10-01 10:20:00' AS DATETIME2(0)), 1250, 5, 16),    -- 1250 điểm -> Hạng Kim Cương (MaHang 5)
(6, CAST('2025-10-15 16:00:00' AS DATETIME2(0)),    0, 1, NULL);  -- 0 điểm    -> Hạng Đồng (MaHang 1)
GO
