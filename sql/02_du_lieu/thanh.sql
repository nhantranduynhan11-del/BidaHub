-- ============================================================================
-- 02_du_lieu/thanh.sql (Thành): KHU_VUC, LOAI_BAN, KHUNG_GIA, BAN, PHIEU_DAT_BAN, GIU_BAN
--
-- Dữ liệu mẫu chuẩn theo thống nhất của nhóm (khóa chính kiểu INT IDENTITY).
-- Mã tự sinh (IDENTITY) cố định theo thứ tự chèn để Dũng (PHIEN_CHOI, DOAN_SU_DUNG_BAN)
-- và kịch bản demo dùng trực tiếp:
--
-- 1. KHU_VUC (MaKhuVuc 1-5):
--    1: Tầng 1 - Khu Phổ Thông
--    2: Tầng 1 - Khu Thi Đấu
--    3: Tầng 2 - Khu Máy Lạnh
--    4: Tầng 2 - Khu Carom & Snooker
--    5: Tầng 3 - Phòng VIP
--
-- 2. LOAI_BAN (MaLoaiBan 1-5):
--    1: Pool 9 bi tiêu chuẩn
--    2: Pool 9 bi thi đấu
--    3: Carom 3 băng
--    4: Carom Libre
--    5: Snooker 12 feet
--
-- 3. KHUNG_GIA:
--    Mỗi loại bàn (MaLoaiBan 1-5) có 6 khung giá (SoThuTuKhung 1-6), phủ kín từ 08:00 đến 23:59:59,
--    không chồng lấn trong cùng (MaLoaiBan, LoaiNgayApDung) (tuân thủ RB4, RB8):
--      Khung 1: Ngày thường 08:00 - 12:00 (Khung sáng)
--      Khung 2: Ngày thường 12:00 - 18:00 (Khung chiều)
--      Khung 3: Ngày thường 18:00 - 23:59:59 (Khung tối - Giờ vàng)
--      Khung 4: Cuối tuần   08:00 - 18:00 (Khung ngày cuối tuần)
--      Khung 5: Cuối tuần   18:00 - 23:59:59 (Khung tối cuối tuần)
--      Khung 6: Ngày lễ     08:00 - 23:59:59 (Khung cả ngày lễ)
--
-- 4. BAN (MaBan 1-12):
--    MaBan 1-3  : Loại 1 (Pool 9 bi tiêu chuẩn), Khu vực 1
--    MaBan 4-5  : Loại 2 (Pool 9 bi thi đấu), Khu vực 2
--    MaBan 6    : Loại 2 (Pool 9 bi thi đấu), Khu vực 3
--    MaBan 7    : Loại 3 (Carom 3 băng), Khu vực 3
--    MaBan 8    : Loại 3 (Carom 3 băng), Khu vực 4
--    MaBan 9    : Loại 4 (Carom Libre), Khu vực 4
--    MaBan 10   : Loại 5 (Snooker 12 feet), Khu vực 5
--    MaBan 11   : Loại 1, Khu vực 1 - Đang bảo trì (dùng để demo RB5, RB7)
--    MaBan 12   : Loại 4, Khu vực 4 - Ngưng sử dụng (dùng để demo RB5, RB7)
--
-- 5. PHIEU_DAT_BAN (MaDatBan 1-9) & 6. GIU_BAN:
--    Liên kết MaKH 1-10 (của Phong) và MaNVTiepNhan 1, 2, 3, 4, 11 (Quản lý/Thu ngân đang làm của Nhân):
--    - MaDatBan 1, 2, 3: 'Đã chuyển thành phiên' (giữ bàn 1, 4, 7) -> Dũng dùng mở PHIEN_CHOI (RB6)
--    - MaDatBan 4, 5, 6: 'Đã xác nhận' (giữ bàn 3, 5, 8; bàn 5 có thêm bàn 6) -> test fn_DemBanTrong & RB5
--    - MaDatBan 7      : 'Chờ xác nhận' (hội viên MaKH 4 đặt qua Ứng dụng, MaNVTiepNhan NULL)
--    - MaDatBan 8      : 'Đã hủy' (khách báo hủy trước giờ chơi)
--    - MaDatBan 9      : 'Không đến' (quá giờ hẹn khách không tới)
-- ============================================================================

USE BidaHub;
GO

-- ----------------------------------------------------------------------------
-- 1. BẢNG KHU_VUC (5 khu vực: MaKhuVuc 1 -> 5)
-- ----------------------------------------------------------------------------
INSERT INTO dbo.KHU_VUC (TenKhuVuc) VALUES
(N'Tầng 1 - Khu Phổ Thông'),       -- MaKhuVuc = 1
(N'Tầng 1 - Khu Thi Đấu'),         -- MaKhuVuc = 2
(N'Tầng 2 - Khu Máy Lạnh'),        -- MaKhuVuc = 3
(N'Tầng 2 - Khu Carom & Snooker'), -- MaKhuVuc = 4
(N'Tầng 3 - Phòng VIP');           -- MaKhuVuc = 5
GO

-- ----------------------------------------------------------------------------
-- 2. BẢNG LOAI_BAN (5 loại bàn: MaLoaiBan 1 -> 5)
-- ----------------------------------------------------------------------------
INSERT INTO dbo.LOAI_BAN (TenLoai, MoTa) VALUES
(N'Pool 9 bi tiêu chuẩn', N'Bàn lỗ 9 feet tiêu chuẩn phục vụ khách chơi giải trí phổ thông'),          -- MaLoaiBan = 1
(N'Pool 9 bi thi đấu',    N'Bàn lỗ 9 feet chuẩn thi đấu quốc tế, mặt đá phẳng, vải nỉ Simonis 860'),   -- MaLoaiBan = 2
(N'Carom 3 băng',         N'Bàn phăng 3 băng tiêu chuẩn Hàn Quốc có hệ thống sưởi nhiệt mặt bàn'),     -- MaLoaiBan = 3
(N'Carom Libre',          N'Bàn phăng tự do (Libre/1 băng) phục vụ khách luyện cơ và giải trí'),       -- MaLoaiBan = 4
(N'Snooker 12 feet',      N'Bàn Snooker kích thước lớn 12 feet chuẩn Anh dành cho phòng VIP');         -- MaLoaiBan = 5
GO

-- ----------------------------------------------------------------------------
-- 3. BẢNG KHUNG_GIA (Mỗi loại bàn có 6 khung giá không chồng lấn - RB4)
-- ----------------------------------------------------------------------------
INSERT INTO dbo.KHUNG_GIA (MaLoaiBan, SoThuTuKhung, TenKhung, LoaiNgayApDung, GioBatDau, GioKetThuc, DonGiaMoiGio) VALUES
-- Loại 1: Pool 9 bi tiêu chuẩn
(1, 1, N'Khung sáng ngày thường',       N'Ngày thường', '08:00:00', '12:00:00',  60000),
(1, 2, N'Khung chiều ngày thường',      N'Ngày thường', '12:00:00', '18:00:00',  75000),
(1, 3, N'Khung tối giờ vàng',           N'Ngày thường', '18:00:00', '23:59:59',  90000),
(1, 4, N'Khung ngày cuối tuần',         N'Cuối tuần',   '08:00:00', '18:00:00',  85000),
(1, 5, N'Khung tối cuối tuần',          N'Cuối tuần',   '18:00:00', '23:59:59', 100000),
(1, 6, N'Khung ngày lễ',                N'Ngày lễ',     '08:00:00', '23:59:59', 110000),

-- Loại 2: Pool 9 bi thi đấu
(2, 1, N'Khung sáng ngày thường',       N'Ngày thường', '08:00:00', '12:00:00',  80000),
(2, 2, N'Khung chiều ngày thường',      N'Ngày thường', '12:00:00', '18:00:00', 100000),
(2, 3, N'Khung tối giờ vàng',           N'Ngày thường', '18:00:00', '23:59:59', 120000),
(2, 4, N'Khung ngày cuối tuần',         N'Cuối tuần',   '08:00:00', '18:00:00', 110000),
(2, 5, N'Khung tối cuối tuần',          N'Cuối tuần',   '18:00:00', '23:59:59', 135000),
(2, 6, N'Khung ngày lễ',                N'Ngày lễ',     '08:00:00', '23:59:59', 150000),

-- Loại 3: Carom 3 băng
(3, 1, N'Khung sáng ngày thường',       N'Ngày thường', '08:00:00', '12:00:00',  90000),
(3, 2, N'Khung chiều ngày thường',      N'Ngày thường', '12:00:00', '18:00:00', 110000),
(3, 3, N'Khung tối giờ vàng',           N'Ngày thường', '18:00:00', '23:59:59', 130000),
(3, 4, N'Khung ngày cuối tuần',         N'Cuối tuần',   '08:00:00', '18:00:00', 120000),
(3, 5, N'Khung tối cuối tuần',          N'Cuối tuần',   '18:00:00', '23:59:59', 145000),
(3, 6, N'Khung ngày lễ',                N'Ngày lễ',     '08:00:00', '23:59:59', 160000),

-- Loại 4: Carom Libre
(4, 1, N'Khung sáng ngày thường',       N'Ngày thường', '08:00:00', '12:00:00',  55000),
(4, 2, N'Khung chiều ngày thường',      N'Ngày thường', '12:00:00', '18:00:00',  70000),
(4, 3, N'Khung tối giờ vàng',           N'Ngày thường', '18:00:00', '23:59:59',  85000),
(4, 4, N'Khung ngày cuối tuần',         N'Cuối tuần',   '08:00:00', '18:00:00',  75000),
(4, 5, N'Khung tối cuối tuần',          N'Cuối tuần',   '18:00:00', '23:59:59',  95000),
(4, 6, N'Khung ngày lễ',                N'Ngày lễ',     '08:00:00', '23:59:59', 105000),

-- Loại 5: Snooker 12 feet
(5, 1, N'Khung sáng ngày thường',       N'Ngày thường', '08:00:00', '12:00:00', 120000),
(5, 2, N'Khung chiều ngày thường',      N'Ngày thường', '12:00:00', '18:00:00', 150000),
(5, 3, N'Khung tối giờ vàng',           N'Ngày thường', '18:00:00', '23:59:59', 180000),
(5, 4, N'Khung ngày cuối tuần',         N'Cuối tuần',   '08:00:00', '18:00:00', 160000),
(5, 5, N'Khung tối cuối tuần',          N'Cuối tuần',   '18:00:00', '23:59:59', 200000),
(5, 6, N'Khung ngày lễ',                N'Ngày lễ',     '08:00:00', '23:59:59', 220000);
GO

-- ----------------------------------------------------------------------------
-- 4. BẢNG BAN (12 bàn: MaBan 1 -> 12)
-- ----------------------------------------------------------------------------
INSERT INTO dbo.BAN (TenBan, SucChuaDeXuat, TrangThai, MaKhuVuc, MaLoaiBan) VALUES
(N'Bàn P01', 4, N'Trống',         1, 1), -- MaBan = 1  (Pool tiêu chuẩn, Tầng 1)
(N'Bàn P02', 4, N'Trống',         1, 1), -- MaBan = 2  (Pool tiêu chuẩn, Tầng 1)
(N'Bàn P03', 6, N'Đã đặt',        1, 1), -- MaBan = 3  (Pool tiêu chuẩn, Tầng 1 - có phiếu đặt xác nhận)
(N'Bàn P04', 4, N'Trống',         2, 2), -- MaBan = 4  (Pool thi đấu, Khu Thi Đấu)
(N'Bàn P05', 4, N'Đã đặt',        2, 2), -- MaBan = 5  (Pool thi đấu, Khu Thi Đấu - có phiếu đặt xác nhận)
(N'Bàn P06', 6, N'Trống',         3, 2), -- MaBan = 6  (Pool thi đấu, Khu Máy Lạnh)
(N'Bàn C01', 4, N'Trống',         3, 3), -- MaBan = 7  (Carom 3 băng, Khu Máy Lạnh)
(N'Bàn C02', 4, N'Đã đặt',        4, 3), -- MaBan = 8  (Carom 3 băng, Khu Carom - có phiếu đặt xác nhận)
(N'Bàn L01', 4, N'Trống',         4, 4), -- MaBan = 9  (Carom Libre, Khu Carom)
(N'Bàn S01', 6, N'Trống',         5, 5), -- MaBan = 10 (Snooker 12ft, Phòng VIP)
(N'Bàn P07', 4, N'Đang bảo trì',  1, 1), -- MaBan = 11 (Đang thay vải nỉ - không được đặt/mở phiên theo RB5, RB7)
(N'Bàn L02', 4, N'Ngưng sử dụng', 4, 4); -- MaBan = 12 (Ngưng khai thác - không được đặt/mở phiên theo RB5, RB7)
GO

-- ----------------------------------------------------------------------------
-- 5. BẢNG PHIEU_DAT_BAN (9 phiếu đặt bàn: MaDatBan 1 -> 9)
-- MaKH 1-10 từ bảng KHACH_HANG của Phong; MaNVTiepNhan 3, 4, 11 (Thu ngân), 1, 2 (Quản lý) của Nhân.
-- ----------------------------------------------------------------------------
INSERT INTO dbo.PHIEU_DAT_BAN
    (ThoiDiemLap, GioBatDauDuKien, GioKetThucDuKien, SoNguoi, KenhTiepNhan, TrangThai, GhiChu, MaKH, MaNVTiepNhan)
VALUES
-- MaDatBan = 1..3: Đã chuyển thành phiên (khách đã đến nhận bàn, Dũng có thể nối vào PHIEN_CHOI.MaDatBan)
('2025-10-20 08:15:00', '2025-10-20 09:00:00', '2025-10-20 11:00:00', 4, N'Ứng dụng',    N'Đã chuyển thành phiên', N'Hội viên Trần Văn Bình đặt bàn Pool buổi sáng',         1, 3),
('2025-10-21 13:00:00', '2025-10-21 14:00:00', '2025-10-21 17:00:00', 4, N'Điện thoại',  N'Đã chuyển thành phiên', N'Hội viên Lê Quốc Thành đặt bàn thi đấu buổi chiều',     2, 4),
('2025-10-22 17:30:00', '2025-10-22 18:30:00', '2025-10-22 21:00:00', 2, N'Mạng xã hội', N'Đã chuyển thành phiên', N'Khách đặt bàn Carom 3 băng qua Zalo quán',              6, 11),

-- MaDatBan = 4..6: Đã xác nhận (đang giữ bàn cho khung giờ sắp tới, không chồng lấn giờ - RB5)
('2025-10-25 10:00:00', '2025-10-25 18:00:00', '2025-10-25 20:00:00', 5, N'Ứng dụng',    N'Đã xác nhận',           N'Hội viên Phạm Thị Ánh đặt bàn P03 tối cuối tuần',       3, 3),
('2025-10-25 11:20:00', '2025-10-25 18:30:00', '2025-10-25 21:30:00', 8, N'Điện thoại',  N'Đã xác nhận',           N'Nhóm 8 người đặt 2 bàn Pool thi đấu (P05 và P06)',      7, 4),
('2025-10-25 14:00:00', '2025-10-25 19:00:00', '2025-10-25 22:00:00', 4, N'Tại quầy',    N'Đã xác nhận',           N'Hội viên Hoàng Thị Yến đặt trực tiếp bàn Carom C02',    5, 11),

-- MaDatBan = 7: Chờ xác nhận (hội viên vừa đặt trên ứng dụng, chưa có nhân viên xác nhận -> MaNVTiepNhan NULL)
('2025-10-25 15:45:00', '2025-10-26 19:00:00', '2025-10-26 21:00:00', 4, N'Ứng dụng',    N'Chờ xác nhận',          N'Hội viên Nguyễn Minh Khôi đặt phòng VIP Snooker',       4, NULL),

-- MaDatBan = 8: Đã hủy (khách chủ động báo hủy trước giờ chơi)
('2025-10-18 09:30:00', '2025-10-18 15:00:00', '2025-10-18 17:00:00', 4, N'Điện thoại',  N'Đã hủy',                N'Khách bận việc đột xuất gọi báo hủy trước 3 tiếng',     8, 3),

-- MaDatBan = 9: Không đến (quá giờ hẹn khách không đến nhận bàn)
('2025-10-19 16:00:00', '2025-10-19 19:00:00', '2025-10-19 21:00:00', 4, N'Mạng xã hội', N'Không đến',             N'Quá giờ đặt 30 phút liên hệ không nghe máy, hủy giữ',   9, 4);
GO

-- ----------------------------------------------------------------------------
-- 6. BẢNG GIU_BAN (Gán bàn cho các phiếu đặt bàn - RB5, RB6)
-- Mọi phiếu 'Đã xác nhận' và 'Đã chuyển thành phiên' đều giữ ít nhất 1 bàn hợp lệ (MaBan 1..10).
-- Phiếu 5 giữ 2 bàn (bàn 5 và bàn 6) để minh họa quan hệ M:N (1 phiếu giữ nhiều bàn).
-- Bàn 1 cũng được giữ cho cả phiếu 1 (ngày 20/10) và phiếu 8 (ngày 18/10) ở hai khoảng giờ khác nhau.
-- ----------------------------------------------------------------------------
INSERT INTO dbo.GIU_BAN (MaDatBan, MaBan) VALUES
(1, 1),  -- Phiếu 1 (20/10 09:00-11:00) giữ Bàn P01 (MaBan = 1)
(2, 4),  -- Phiếu 2 (21/10 14:00-17:00) giữ Bàn P04 (MaBan = 4)
(3, 7),  -- Phiếu 3 (22/10 18:30-21:00) giữ Bàn C01 (MaBan = 7)
(4, 3),  -- Phiếu 4 (25/10 18:00-20:00) giữ Bàn P03 (MaBan = 3)
(5, 5),  -- Phiếu 5 (25/10 18:30-21:30) giữ Bàn P05 (MaBan = 5)
(5, 6),  -- Phiếu 5 (25/10 18:30-21:30) giữ thêm Bàn P06 (MaBan = 6)
(6, 8),  -- Phiếu 6 (25/10 19:00-22:00) giữ Bàn C02 (MaBan = 8)
(8, 1),  -- Phiếu 8 (18/10 15:00-17:00 - Đã hủy) từng giữ Bàn P01 (MaBan = 1)
(9, 2);  -- Phiếu 9 (19/10 19:00-21:00 - Không đến) từng giữ Bàn P02 (MaBan = 2)
GO

