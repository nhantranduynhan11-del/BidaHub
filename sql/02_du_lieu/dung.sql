-- 1. DANH_MUC (MaDanhMuc 1-5):
--    1: Nước giải khát   2: Cà phê - Trà   3: Bia   4: Đồ ăn nhẹ   5: Dịch vụ khác
--
-- 2. MAT_HANG (MaMatHang 1-14):
--    SoLuongTon là tồn hiện tại, đã trừ các dòng gọi món trong file này (dòng đã hủy được hoàn kho).
--    MaMatHang 4 : Red Bull, tồn 3 (dùng để demo RB10: gọi vượt tồn bị chặn)
--    MaMatHang 9 : Bia Sài Gòn Special, 'Ngừng bán' (dùng để demo RB10: không được gọi)
--
-- 3. PHIEN_CHOI (MaPhien 1-10), từ 19/10/2025 (Chủ nhật) đến 25/10/2025 (Thứ Bảy):
--    MaPhien 1-6 : 'Đã thanh toán'  -> Khang lập HOA_DON đã thanh toán đủ cho các phiên này
--    MaPhien 7, 8: 'Đã kết thúc'    -> chưa có hóa đơn, dùng để demo lập hóa đơn (RB12)
--    MaPhien 9-10: 'Đang chơi'      -> đoạn còn mở, chưa được lập hóa đơn (RB12)
--    MaPhien 2, 3, 4 xuất phát từ MaDatBan 1, 2, 3 của Thành, đúng khách và bàn đã giữ (RB6)
--    MaPhien 5, 9: khách vãng lai không để lại hồ sơ (MaKH NULL)
--    MaNVMoPhien: Thu ngân, Quản lý đang làm của Nhân (1, 3, 4, 11), không dùng MaNV 8 đã nghỉ (RB2)
--
-- 4. DOAN_SU_DUNG_BAN (12 đoạn):
--    Khung giá đúng loại bàn và loại ngày của Thành, đơn giá áp dụng bằng DonGiaMoiGio của khung (RB8)
--    MaPhien 1, 3: đi qua mốc 18:00 nên tách 2 đoạn theo khung giá (RB8)
--    MaPhien 4   : chuyển từ bàn C01 sang bàn P06, đoạn cũ kết thúc đúng lúc đoạn mới bắt đầu (RB7)
--    Không dùng bàn 11 (đang bảo trì) và bàn 12 (ngưng sử dụng) (RB7)
--
-- 5. DONG_GOI_MON (22 dòng): rải từ 19/10 đến 25/10 để có lịch sử bán cho fn_DuBaoSoNgayTonKho
--    Đơn giá tại thời điểm gọi bằng đơn giá niêm yết, thời điểm gọi nằm trong phiên (RB8, RB10)
--    Dòng (3, 4): 'Đã hủy' trước khi chế biến

USE BidaHub;
GO

-- 1. BẢNG DANH_MUC (5 danh mục: MaDanhMuc 1 -> 5)
INSERT INTO dbo.DANH_MUC (TenDanhMuc) VALUES
(N'Nước giải khát'),   -- MaDanhMuc = 1
(N'Cà phê - Trà'),     -- MaDanhMuc = 2
(N'Bia'),              -- MaDanhMuc = 3
(N'Đồ ăn nhẹ'),        -- MaDanhMuc = 4
(N'Dịch vụ khác');     -- MaDanhMuc = 5
GO

-- 2. BẢNG MAT_HANG (14 mặt hàng: MaMatHang 1 -> 14)
INSERT INTO dbo.MAT_HANG (TenMatHang, DonViTinh, DonGiaNiemYet, TrangThaiKinhDoanh, SoLuongTon, MaDanhMuc) VALUES
(N'Nước suối Aquafina 500ml', N'Chai', 10000, N'Đang bán',  116, 1), -- MaMatHang = 1
(N'Coca-Cola lon 330ml',      N'Lon',  15000, N'Đang bán',   89, 1), -- MaMatHang = 2
(N'Sting dâu 330ml',          N'Chai', 15000, N'Đang bán',   77, 1), -- MaMatHang = 3
(N'Red Bull lon 250ml',       N'Lon',  20000, N'Đang bán',    3, 1), -- MaMatHang = 4  (tồn thấp, demo RB10)
(N'Cà phê sữa đá',            N'Ly',   25000, N'Đang bán',   56, 2), -- MaMatHang = 5
(N'Trà đào cam sả',           N'Ly',   35000, N'Đang bán',   35, 2), -- MaMatHang = 6
(N'Bia Tiger lon 330ml',      N'Lon',  22000, N'Đang bán',  132, 3), -- MaMatHang = 7
(N'Bia Heineken lon 330ml',   N'Lon',  25000, N'Đang bán',   46, 3), -- MaMatHang = 8
(N'Bia Sài Gòn Special',      N'Chai', 20000, N'Ngừng bán',   0, 3), -- MaMatHang = 9  (ngừng bán, demo RB10)
(N'Đậu phộng rang',           N'Đĩa',  20000, N'Đang bán',   25, 4), -- MaMatHang = 10
(N'Khô gà lá chanh',          N'Hộp',  45000, N'Đang bán',   24, 4), -- MaMatHang = 11
(N'Mì xào bò',                N'Đĩa',  45000, N'Đang bán',   19, 4), -- MaMatHang = 12
(N'Thuê gậy carom cao cấp',   N'Lượt', 30000, N'Đang bán',    8, 5), -- MaMatHang = 13
(N'Thuê găng tay bida',       N'Lượt', 10000, N'Đang bán',   13, 5); -- MaMatHang = 14
GO

-- 3. BẢNG PHIEN_CHOI (10 phiên: MaPhien 1 -> 10)
-- MaDatBan 1, 2, 3 của Thành; MaKH 1-10 của Phong; MaNVMoPhien 1, 3, 4, 11 của Nhân.
INSERT INTO dbo.PHIEN_CHOI (GioBatDau, GioKetThuc, TrangThai, GhiChu, MaDatBan, MaNVMoPhien, MaKH) VALUES
('2025-10-19 17:00:00', '2025-10-19 19:00:00', N'Đã thanh toán', NULL,                                  NULL, 11, 8),    -- MaPhien = 1  (CN, qua mốc 18:00)
('2025-10-20 09:05:00', '2025-10-20 11:20:00', N'Đã thanh toán', N'Khách đến từ phiếu đặt qua ứng dụng', 1,    3,  1),    -- MaPhien = 2  (từ MaDatBan 1, bàn P01)
('2025-10-21 14:00:00', '2025-10-21 18:45:00', N'Đã thanh toán', N'Khách chơi quá giờ đặt 45 phút',      2,    4,  2),    -- MaPhien = 3  (từ MaDatBan 2, bàn P04, qua mốc 18:00)
('2025-10-22 18:30:00', '2025-10-22 21:10:00', N'Đã thanh toán', N'Khách xin chuyển sang bàn Pool P06',  3,    11, 6),    -- MaPhien = 4  (từ MaDatBan 3, bàn C01 rồi chuyển bàn)
('2025-10-23 10:15:00', '2025-10-23 11:45:00', N'Đã thanh toán', NULL,                                  NULL, 3,  NULL), -- MaPhien = 5  (khách vãng lai)
('2025-10-24 19:00:00', '2025-10-24 21:30:00', N'Đã thanh toán', NULL,                                  NULL, 4,  7),    -- MaPhien = 6
('2025-10-24 20:00:00', '2025-10-24 22:30:00', N'Đã kết thúc',   N'Hội viên chơi Snooker phòng VIP',    NULL, 11, 4),    -- MaPhien = 7  (chưa lập hóa đơn)
('2025-10-25 09:30:00', '2025-10-25 11:00:00', N'Đã kết thúc',   NULL,                                  NULL, 1,  5),    -- MaPhien = 8  (chưa lập hóa đơn)
('2025-10-25 15:00:00', NULL,                  N'Đang chơi',     NULL,                                  NULL, 3,  NULL), -- MaPhien = 9  (khách vãng lai, bàn P02)
('2025-10-25 15:30:00', NULL,                  N'Đang chơi',     NULL,                                  NULL, 4,  3);    -- MaPhien = 10 (bàn L01)
GO

-- 4. BẢNG DOAN_SU_DUNG_BAN (12 đoạn)
-- 19/10, 25/10 là cuối tuần (khung 4, 5); 20/10 - 24/10 là ngày thường (khung 1, 2, 3).
INSERT INTO dbo.DOAN_SU_DUNG_BAN (MaPhien, SoThuTuDoan, GioBatDauDung, GioKetThucDung, DonGiaApDung, MaBan, MaLoaiBan, SoThuTuKhung) VALUES
(1,  1, '2025-10-19 17:00:00', '2025-10-19 18:00:00', 110000, 4,  2, 4), -- Bàn P04, khung ngày cuối tuần
(1,  2, '2025-10-19 18:00:00', '2025-10-19 19:00:00', 135000, 4,  2, 5), -- Bàn P04, sang khung tối cuối tuần (RB8)
(2,  1, '2025-10-20 09:05:00', '2025-10-20 11:20:00',  60000, 1,  1, 1), -- Bàn P01 đã giữ cho MaDatBan 1 (RB6)
(3,  1, '2025-10-21 14:00:00', '2025-10-21 18:00:00', 100000, 4,  2, 2), -- Bàn P04 đã giữ cho MaDatBan 2 (RB6)
(3,  2, '2025-10-21 18:00:00', '2025-10-21 18:45:00', 120000, 4,  2, 3), -- Bàn P04, sang khung tối giờ vàng (RB8)
(4,  1, '2025-10-22 18:30:00', '2025-10-22 19:40:00', 130000, 7,  3, 3), -- Bàn C01 đã giữ cho MaDatBan 3 (RB6)
(4,  2, '2025-10-22 19:40:00', '2025-10-22 21:10:00', 120000, 6,  2, 3), -- Chuyển sang bàn P06 (RB7)
(5,  1, '2025-10-23 10:15:00', '2025-10-23 11:45:00',  60000, 2,  1, 1), -- Bàn P02
(6,  1, '2025-10-24 19:00:00', '2025-10-24 21:30:00',  85000, 9,  4, 3), -- Bàn L01
(7,  1, '2025-10-24 20:00:00', '2025-10-24 22:30:00', 180000, 10, 5, 3), -- Bàn S01
(8,  1, '2025-10-25 09:30:00', '2025-10-25 11:00:00',  85000, 1,  1, 4), -- Bàn P01
(9,  1, '2025-10-25 15:00:00', NULL,                   85000, 2,  1, 4), -- Bàn P02, đoạn đang diễn ra
(10, 1, '2025-10-25 15:30:00', NULL,                   75000, 9,  4, 4); -- Bàn L01, đoạn đang diễn ra
GO

-- 5. BẢNG DONG_GOI_MON (22 dòng)
-- MaNVGhiNhan: Thu ngân 3, 4, 11 và Phục vụ 5, 9 đang làm của Nhân.
INSERT INTO dbo.DONG_GOI_MON (MaPhien, SoThuTuDong, ThoiDiemGoi, SoLuong, DonGiaTaiThoiDiemGoi, TrangThaiPhucVu, GhiChu, MaMatHang, MaNVGhiNhan) VALUES
(1,  1, '2025-10-19 17:10:00', 4, 15000, N'Đã phục vụ',   NULL,                                  2,  9),
(1,  2, '2025-10-19 17:40:00', 2, 20000, N'Đã phục vụ',   NULL,                                  10, 9),
(1,  3, '2025-10-19 18:20:00', 4, 22000, N'Đã phục vụ',   NULL,                                  7,  5),
(2,  1, '2025-10-20 09:15:00', 2, 25000, N'Đã phục vụ',   N'Ít đường',                           5,  5),
(2,  2, '2025-10-20 10:30:00', 2, 10000, N'Đã phục vụ',   NULL,                                  1,  5),
(3,  1, '2025-10-21 14:10:00', 3, 35000, N'Đã phục vụ',   NULL,                                  6,  9),
(3,  2, '2025-10-21 15:00:00', 1, 30000, N'Đã phục vụ',   NULL,                                  13, 4),
(3,  3, '2025-10-21 16:30:00', 3, 15000, N'Đã phục vụ',   NULL,                                  3,  9),
(3,  4, '2025-10-21 17:20:00', 1, 45000, N'Đã hủy',       N'Khách đổi ý trước khi bếp chế biến', 12, 9),  -- hoàn lại kho (RB10)
(4,  1, '2025-10-22 18:45:00', 2, 22000, N'Đã phục vụ',   NULL,                                  7,  11),
(4,  2, '2025-10-22 19:50:00', 1, 45000, N'Đã phục vụ',   N'Mang sang bàn P06 sau khi chuyển',  11, 5),
(5,  1, '2025-10-23 10:20:00', 2, 10000, N'Đã phục vụ',   NULL,                                  1,  3),
(6,  1, '2025-10-24 19:05:00', 6, 22000, N'Đã phục vụ',   NULL,                                  7,  4),
(6,  2, '2025-10-24 19:30:00', 2, 20000, N'Đã phục vụ',   NULL,                                  10, 9),
(6,  3, '2025-10-24 20:40:00', 1, 45000, N'Đã phục vụ',   NULL,                                  12, 9),
(7,  1, '2025-10-24 20:10:00', 2, 25000, N'Đã phục vụ',   NULL,                                  8,  11),
(7,  2, '2025-10-24 20:15:00', 2, 10000, N'Đã phục vụ',   NULL,                                  14, 11),
(8,  1, '2025-10-25 09:40:00', 2, 25000, N'Đã phục vụ',   NULL,                                  5,  5),
(9,  1, '2025-10-25 15:05:00', 3, 15000, N'Đã phục vụ',   NULL,                                  2,  3),
(9,  2, '2025-10-25 15:40:00', 1, 20000, N'Chờ chế biến', NULL,                                  10, 5),
(10, 1, '2025-10-25 15:35:00', 2, 35000, N'Chờ chế biến', N'Ít đá',                              6,  4),
(10, 2, '2025-10-25 15:35:00', 1, 30000, N'Đã phục vụ',   NULL,                                  13, 4);
GO
