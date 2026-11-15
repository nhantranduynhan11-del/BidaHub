-- ============================================================================
-- sql/02_du_lieu/nap_tat_ca_du_lieu.sql: dữ liệu mẫu của cả 27 bảng (5 phần của 5 thành viên gộp lại)
--
-- Chạy SAU sql/01_bang/tao_tat_ca_bang.sql (các bảng còn rỗng) và TRƯỚC sql/03_trigger.
-- Thứ tự nạp theo khóa ngoại: Nhân -> Phong -> Thành -> Dũng -> Khang.
-- Mã tự sinh (IDENTITY) cố định theo thứ tự dòng nên các phần dùng trực tiếp mã của nhau:
--   Nhân : MaTK 1-11 là nhân viên (MaNV = MaTK), MaTK 12-16 là hội viên
--   Phong: MaKH 1-10 (MaKH 1-5 khớp MaTK 12-16)
--   Thành: MaBan 1-12, MaDatBan 1-9
--   Dũng : MaMatHang 1-14, MaPhien 1-10
--   Khang: MaHoaDon 1-6 (phiên 1-6 đã thanh toán)
-- Sửa dữ liệu: chỉ sửa trong phần của mình; nhớ giữ các số liên quan khớp với phần của người khác
-- (khối kiểm tra ở cuối file sẽ chỉ ra chỗ lệch).
-- ============================================================================
USE BidaHub;
GO

-- ############################################################################
-- PHẦN 1/5 · NHÂN · VAI_TRO, TAI_KHOAN, DUOC_CAP, NHAN_VIEN, NV_TOAN_THOI_GIAN, NV_BAN_THOI_GIAN
-- ############################################################################
-- Mã (IDENTITY) do SQL Server cấp theo thứ tự dòng. CSDL được dựng lại từ đầu mỗi lần chạy nên mã cố định,
-- người khác có thể dùng trực tiếp trong file 02_du_lieu của mình:
--   VAI_TRO    : 1 Quản lý, 2 Thu ngân, 3 Phục vụ, 4 Pha chế, 5 Thủ kho, 6 Hội viên
--   TAI_KHOAN  : MaTK 1-11 là 11 nhân viên, MaTK 12-16 là 5 hội viên (HOI_VIEN.MaTK của Phong dùng 12-16)
--   NHAN_VIEN  : MaNV = MaTK với 11 nhân viên (MaNV 1-11)
--     Quản lý  : 1, 2          Thu ngân: 3, 4, 11       Phục vụ: 5, 8, 9
--     Pha chế  : 6, 10         Thủ kho : 7
--     Đang làm : 1-7, 9-11     Đã nghỉ : 8 (tài khoản 8 cũng bị khóa, dùng để demo RB2)
-- Mật khẩu mẫu của mọi tài khoản là 'Bida@' + tên đăng nhập (lưu SHA-256, chỉ để demo).

INSERT INTO dbo.VAI_TRO (TenVaiTro, MoTa) VALUES
(N'Quản lý',  N'Cấu hình toàn quán, quản lý nhân sự và khuyến mãi, xem báo cáo doanh thu'),
(N'Thu ngân', N'Mở phiên, chuyển bàn, lập hóa đơn, nhận thanh toán, tiếp nhận đặt bàn'),
(N'Phục vụ',  N'Nhận món đã gọi và cập nhật trạng thái phục vụ'),
(N'Pha chế',  N'Chuẩn bị đồ uống và cập nhật trạng thái chế biến'),
(N'Thủ kho',  N'Lập phiếu nhập, theo dõi tồn kho'),
(N'Hội viên', N'Xem thực đơn và bảng giá, đặt và hủy đặt bàn, xem lịch sử phiên chơi');
GO

-- ORDER BY stt bảo đảm MaTK được cấp đúng thứ tự dòng.
INSERT INTO dbo.TAI_KHOAN (TenDangNhap, MatKhau, Email, TrangThai, NgayTao)
SELECT v.ten,
       CONVERT(CHAR(64), HASHBYTES('SHA2_256', CAST(N'Bida@' + v.ten AS VARCHAR(100))), 2),
       v.email, v.trang_thai, CAST(v.ngay AS DATETIME2(0))
FROM (VALUES
    (1,  N'quanly.minh',  N'minh.nguyen@bidahub.vn',  N'Hoạt động', '2025-01-10'),
    (2,  N'quanly.huong', N'huong.le@bidahub.vn',     N'Hoạt động', '2025-01-10'),
    (3,  N'thungan.lan',  N'lan.pham@bidahub.vn',     N'Hoạt động', '2025-02-01'),
    (4,  N'thungan.hung', N'hung.tran@bidahub.vn',    N'Hoạt động', '2025-03-15'),
    (5,  N'phucvu.nam',   N'nam.vo@bidahub.vn',       N'Hoạt động', '2025-03-15'),
    (6,  N'phache.trang', N'trang.dang@bidahub.vn',   N'Hoạt động', '2025-04-01'),
    (7,  N'thukho.duc',   N'duc.bui@bidahub.vn',      N'Hoạt động', '2025-04-01'),
    (8,  N'phucvu.vy',    N'vy.ho@bidahub.vn',        N'Bị khóa',   '2025-05-20'),
    (9,  N'phucvu.tuan',  N'tuan.ngo@bidahub.vn',     N'Hoạt động', '2025-06-01'),
    (10, N'phache.mai',   N'mai.ly@bidahub.vn',       N'Hoạt động', '2025-06-15'),
    (11, N'thungan.bao',  N'bao.duong@bidahub.vn',    N'Hoạt động', '2025-09-01'),
    (12, N'tranbinh92',   N'binh.tran92@gmail.com',   N'Hoạt động', '2025-06-02'),
    (13, N'lethanh.bida', N'thanh.le@gmail.com',      N'Hoạt động', '2025-06-18'),
    (14, N'ngocanh_hv',   N'ngocanh.pham@gmail.com',  N'Hoạt động', '2025-07-05'),
    (15, N'minhkhoi99',   N'khoi.nguyen99@gmail.com', N'Hoạt động', '2025-08-12'),
    (16, N'hoangyen.hv',  N'yen.hoang@gmail.com',     N'Hoạt động', '2025-10-01')
) AS v(stt, ten, email, trang_thai, ngay)
ORDER BY v.stt;
GO

-- Một tài khoản có thể giữ nhiều vai trò (MaTK 1: Quản lý và Thu ngân).
-- Vai trò Quản lý chỉ cấp cho nhân viên chức vụ Quản lý; vai trò Hội viên chỉ cấp cho hội viên (RB1).
INSERT INTO dbo.DUOC_CAP (MaTK, MaVaiTro, NgayCap) VALUES
(1, 1, '2025-01-10'), (1, 2, '2025-01-10'),
(2, 1, '2025-01-10'),
(3, 2, '2025-02-01'),
(4, 2, '2025-03-15'),
(5, 3, '2025-03-15'),
(6, 4, '2025-04-01'),
(7, 5, '2025-04-01'),
(8, 3, '2025-05-20'),
(9, 3, '2025-06-01'),
(10, 4, '2025-06-15'),
(11, 2, '2025-09-01'),
(12, 6, '2025-06-02'),
(13, 6, '2025-06-18'),
(14, 6, '2025-07-05'),
(15, 6, '2025-08-12'),
(16, 6, '2025-10-01');
GO

-- Quản lý 1 đứng đầu (MaNVGiamSat NULL); quản lý 2 do quản lý 1 giám sát;
-- nhân viên còn lại đều có người giám sát là quản lý (RB3). Mọi người đủ 18 tuổi tại ngày vào làm.
INSERT INTO dbo.NHAN_VIEN
    (Ho, TenDem, Ten, NgaySinh, GioiTinh, SoNha, Duong, PhuongXa, QuanHuyen, TinhThanhPho,
     SoDienThoai, ChucVu, NgayVaoLam, TinhTrangLamViec, MaNVGiamSat, MaTK) VALUES
(N'Nguyễn', N'Văn',   N'Minh',  '1985-03-12', N'Nam', N'12',  N'Nguyễn Trãi',          N'Phường 2',  N'Quận 5',          N'TP. Hồ Chí Minh', '0901000001', N'Quản lý',  '2025-01-10', N'Đang làm', NULL, 1),
(N'Lê',     N'Thị',   N'Hương', '1990-07-25', N'Nữ',  N'45',  N'Lê Hồng Phong',        N'Phường 4',  N'Quận 10',         N'TP. Hồ Chí Minh', '0901000002', N'Quản lý',  '2025-01-10', N'Đang làm', 1,    2),
(N'Phạm',   N'Thị',   N'Lan',   '1998-11-02', N'Nữ',  N'8',   N'Cách Mạng Tháng Tám',  N'Phường 5',  N'Quận 3',          N'TP. Hồ Chí Minh', '0901000003', N'Thu ngân', '2025-02-01', N'Đang làm', 1,    3),
(N'Trần',   N'Quốc',  N'Hùng',  '2003-05-19', N'Nam', N'101', N'Võ Văn Tần',           N'Phường 6',  N'Quận 3',          N'TP. Hồ Chí Minh', '0901000004', N'Thu ngân', '2025-03-15', N'Đang làm', 2,    4),
(N'Võ',     N'Hoàng', N'Nam',   '2004-09-30', N'Nam', N'33',  N'Trần Hưng Đạo',        N'Phường 1',  N'Quận 5',          N'TP. Hồ Chí Minh', '0901000005', N'Phục vụ',  '2025-03-15', N'Đang làm', 2,    5),
(N'Đặng',   N'Thu',   N'Trang', '1996-01-14', N'Nữ',  N'27',  N'Hoàng Văn Thụ',        N'Phường 9',  N'Quận Phú Nhuận',  N'TP. Hồ Chí Minh', '0901000006', N'Pha chế',  '2025-04-01', N'Đang làm', 1,    6),
(N'Bùi',    N'Anh',   N'Đức',   '1992-12-08', N'Nam', N'66',  N'Nguyễn Thị Minh Khai', N'Phường 6',  N'Quận 3',          N'TP. Hồ Chí Minh', '0901000007', N'Thủ kho',  '2025-04-01', N'Đang làm', 2,    7),
(N'Hồ',     NULL,     N'Vy',    '2005-02-17', N'Nữ',  N'5',   N'Lý Thường Kiệt',       N'Phường 7',  N'Quận 10',         N'TP. Hồ Chí Minh', '0901000008', N'Phục vụ',  '2025-05-20', N'Đã nghỉ',  2,    8),
(N'Ngô',    N'Minh',  N'Tuấn',  '1999-06-21', N'Nam', N'19',  N'Điện Biên Phủ',        N'Phường 15', N'Quận Bình Thạnh', N'TP. Hồ Chí Minh', '0901000009', N'Phục vụ',  '2025-06-01', N'Đang làm', 2,    9),
(N'Lý',     N'Ngọc',  N'Mai',   '2002-08-09', N'Nữ',  N'74',  N'Phan Đăng Lưu',        N'Phường 3',  N'Quận Bình Thạnh', N'TP. Hồ Chí Minh', '0901000010', N'Pha chế',  '2025-06-15', N'Đang làm', 1,    10),
(N'Dương',  N'Gia',   N'Bảo',   '2001-04-03', N'Nam', N'52',  N'Nguyễn Văn Cừ',        N'Phường 4',  N'Quận 5',          N'TP. Hồ Chí Minh', '0901000011', N'Thu ngân', '2025-09-01', N'Đang làm', 2,    11);
GO

-- Toàn thời gian: nhân viên 1, 2, 3, 6, 7. Bán thời gian: 4, 5, 8, 9, 10, 11. Mỗi nhân viên thuộc đúng một nhóm.
INSERT INTO dbo.NV_TOAN_THOI_GIAN (MaNV, LuongCoBanThang) VALUES
(1, 18000000),
(2, 16000000),
(3,  9000000),
(6, 10000000),
(7,  9500000);
GO

INSERT INTO dbo.NV_BAN_THOI_GIAN (MaNV, DonGiaCongGio) VALUES
(4,  28000),
(5,  25000),
(8,  25000),
(9,  26000),
(10, 27000),
(11, 28000);
GO

-- ############################################################################
-- PHẦN 2/5 · PHONG · HANG_THANH_VIEN, KHACH_HANG, KHACH_HANG_SDT, HOI_VIEN
-- ############################################################################
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

-- ############################################################################
-- PHẦN 3/5 · THÀNH · KHU_VUC, LOAI_BAN, KHUNG_GIA, BAN, PHIEU_DAT_BAN, GIU_BAN
-- ############################################################################
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
--    Trạng thái bàn theo RB7.2 (có đoạn đang mở: Đang chơi; có phiếu Đã xác nhận giữ: Đã đặt; còn lại: Trống):
--      Đang chơi: bàn 2, 9 (phiên 9, 10 của Dũng) | Đã đặt: bàn 3, 5, 6, 8 | Trống: bàn 1, 4, 7, 10
--
-- 5. PHIEU_DAT_BAN (MaDatBan 1-9) & 6. GIU_BAN:
--    Liên kết MaKH 1-10 (của Phong) và MaNVTiepNhan 1, 2, 3, 4, 11 (Quản lý/Thu ngân đang làm của Nhân):
--    - MaDatBan 1, 2, 3: 'Đã chuyển thành phiên' (giữ bàn 1, 4, 7) -> Dũng dùng mở PHIEN_CHOI (RB6)
--    - MaDatBan 4, 5, 6: 'Đã xác nhận' (giữ bàn 3, 5, 8; bàn 5 có thêm bàn 6) -> test fn_DemBanTrong & RB5
--    - MaDatBan 7      : 'Chờ xác nhận' (hội viên MaKH 4 đặt qua Ứng dụng, MaNVTiepNhan NULL)
--    - MaDatBan 8      : 'Đã hủy' (khách báo hủy trước giờ chơi)
--    - MaDatBan 9      : 'Không đến' (quá giờ hẹn khách không tới)

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
(N'Bàn P02', 4, N'Đang chơi',     1, 1), -- MaBan = 2  (Pool tiêu chuẩn, Tầng 1 - đang có phiên 9 của Dũng)
(N'Bàn P03', 6, N'Đã đặt',        1, 1), -- MaBan = 3  (Pool tiêu chuẩn, Tầng 1 - có phiếu đặt xác nhận)
(N'Bàn P04', 4, N'Trống',         2, 2), -- MaBan = 4  (Pool thi đấu, Khu Thi Đấu)
(N'Bàn P05', 4, N'Đã đặt',        2, 2), -- MaBan = 5  (Pool thi đấu, Khu Thi Đấu - có phiếu đặt xác nhận)
(N'Bàn P06', 6, N'Đã đặt',        3, 2), -- MaBan = 6  (Pool thi đấu, Khu Máy Lạnh - phiếu 5 giữ thêm bàn này)
(N'Bàn C01', 4, N'Trống',         3, 3), -- MaBan = 7  (Carom 3 băng, Khu Máy Lạnh)
(N'Bàn C02', 4, N'Đã đặt',        4, 3), -- MaBan = 8  (Carom 3 băng, Khu Carom - có phiếu đặt xác nhận)
(N'Bàn L01', 4, N'Đang chơi',     4, 4), -- MaBan = 9  (Carom Libre, Khu Carom - đang có phiên 10 của Dũng)
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

-- ############################################################################
-- PHẦN 4/5 · DŨNG · DANH_MUC, MAT_HANG, PHIEN_CHOI, DOAN_SU_DUNG_BAN, DONG_GOI_MON
-- ############################################################################
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
-- 4. DOAN_SU_DUNG_BAN (13 đoạn):
--    Khung giá đúng loại bàn và loại ngày của Thành, đơn giá áp dụng bằng DonGiaMoiGio của khung (RB8)
--    MaPhien 1, 3: đi qua mốc 18:00 nên tách 2 đoạn theo khung giá (RB8)
--    MaPhien 4   : chuyển từ bàn C01 sang bàn P06, đoạn cũ kết thúc đúng lúc đoạn mới bắt đầu (RB7)
--    Không dùng bàn 11 (đang bảo trì) và bàn 12 (ngưng sử dụng) (RB7)
--
-- 5. DONG_GOI_MON (22 dòng): rải từ 19/10 đến 25/10 để có lịch sử bán cho fn_DuBaoSoNgayTonKho
--    Đơn giá tại thời điểm gọi bằng đơn giá niêm yết, thời điểm gọi nằm trong phiên (RB8, RB10)
--    Dòng (3, 4): 'Đã hủy' trước khi chế biến

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

-- 4. BẢNG DOAN_SU_DUNG_BAN (13 đoạn)
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

-- ############################################################################
-- PHẦN 5/5 · KHANG · NHA_CUNG_CAP, KHUYEN_MAI, PHIEU_NHAP, CHI_TIET_NHAP, HOA_DON, GIAO_DICH_THANH_TOAN
-- ############################################################################
-- 1. NHA_CUNG_CAP (MaNCC 1-5):
--    1: Công ty Thiết bị Bida An Phát
--    2: Công ty Đồ uống Minh Long
--    3: Nhà cung cấp Thực phẩm Hưng Thịnh
--    4: Công ty Phụ kiện Bida Hoàng Gia
--    5: Công ty Thương mại Đại Phát

-- 2. KHUYEN_MAI (MaKM 1-5):
--    1: Ưu đãi cuối tuần - Giảm theo phần trăm
--    2: Khuyến mãi giờ vàng - Giảm theo số tiền
--    3: Tri ân khách hàng - Giảm theo phần trăm
--    4: Ưu đãi đặc biệt - Giảm theo số tiền
--    5: Khuyến mãi đã hết hạn - Dùng kiểm thử RB13
--    Thời gian khuyến mãi được bố trí quanh giai đoạn 19/10/2025 - 25/10/2025, phù hợp dữ liệu PHIEN_CHOI của Dũng.

-- 3. PHIEU_NHAP (MaPhieuNhap 1-5):
--    1: Nhập hàng từ nhà cung cấp 1
--    2: Nhập hàng từ nhà cung cấp 2
--    3: Nhập hàng từ nhà cung cấp 3
--    4: Nhập hàng từ nhà cung cấp 4
--    5: Nhập hàng từ nhà cung cấp 5

-- 4. CHI_TIET_NHAP:
--    Khóa chính ghép (MaPhieuNhap, MaMatHang)
--    MaPhieuNhap 1-5: liên kết PHIEU_NHAP của Khang.
--    MaMatHang 1-14 : liên kết MAT_HANG của Dũng.
--    Mỗi phiếu nhập dự kiến có 2 mặt hàng khác nhau.
--    Mỗi chi tiết gồm:
--       - SoLuongNhap > 0
--       - DonGiaNhap  > 0
--    Thành tiền từng dòng = SoLuongNhap * DonGiaNhap.
--    Tổng tiền phiếu nhập = tổng thành tiền các chi tiết.
--    Dữ liệu phục vụ kiểm thử:
--       - Cập nhật số lượng tồn kho khi nhập hàng
--       - Tính tổng tiền phiếu nhập

-- 5. HOA_DON (MaHoaDon 1-6): mỗi phiên 'Đã thanh toán' của Dũng (MaPhien 1-6) có đúng một hóa đơn.
--    Phiên 7, 8 ('Đã kết thúc') và 9, 10 ('Đang chơi') chưa có hóa đơn, dành cho demo RB12.
--    Tiền giờ và tiền món lấy đúng từ DOAN_SU_DUNG_BAN và DONG_GOI_MON của Dũng; nhân viên lập: MaNV 3, 4 (Thu ngân).
-- 6. GIAO_DICH_THANH_TOAN (MaGD 1-9): hóa đơn 2 và 6 trả hai lần, hóa đơn 4 có một giao dịch thất bại
--    (không tính vào số đã trả). Phương thức: 'Tiền mặt', 'Chuyển khoản/QR', 'Ví điện tử'.

-- BANG 1: NHA_CUNG_CAP (5 nhà cung cấp: MaNCC: 1-5)
INSERT INTO dbo.NHA_CUNG_CAP
    (TenNhaCungCap, DiaChi, SoDienThoai, Email)
VALUES
    (N'Công ty Thiết bị Bida An Phát', N'TP. Hồ Chí Minh', N'02838111001', N'anphat@example.com'), -- MaNCC 1: Công ty Thiết bị Bida An Phát

    (N'Công ty Đồ uống Minh Long', N'Đồng Nai', N'02513822002', N'minhlong@example.com'), -- MaNCC 2: Công ty Đồ uống Minh Long

    (N'Nhà cung cấp Thực phẩm Hưng Thịnh', N'Bình Dương', N'02743833003', N'hungthinh@example.com'), -- MaNCC 3: Nhà cung cấp Thực phẩm Hưng Thịnh

    (N'Công ty Phụ kiện Bida Hoàng Gia', N'Hà Nội', N'02437844004', N'hoanggia@example.com'), -- MaNCC 4: Công ty Phụ kiện Bida Hoàng Gia

    (N'Công ty Thương mại Đại Phát', N'Đà Nẵng', N'02363855005', N'daiphat@example.com'); -- MaNCC 5: Công ty Thương mại Đại Phát

GO

-- BANG 2: KHUYEN_MAI( 5 mã khuyến mãi: MaKM: 1-5)
INSERT INTO dbo.KHUYEN_MAI
    (TenChuongTrinh, HinhThucGiam, GiaTriGiam, NgayBatDau, NgayKetThuc)
VALUES
    (N'Ưu đãi cuối tuần', N'Phần trăm', 10.00, '2025-10-19', '2025-10-26'), -- MaKM 1: Ưu đãi cuối tuần: giảm 10%

    (N'Khuyến mãi giờ vàng', N'Số tiền', 20000.00, '2025-10-19', '2025-10-22'), -- MaKM 2: Khuyến mãi giờ vàng: giảm 20.000 đồng

    (N'Tri ân khách hàng', N'Phần trăm', 5.00, '2025-10-20', '2025-10-31'), -- MaKM 3: Tri ân khách hàng: giảm 5%

    (N'Ưu đãi đặc biệt', N'Số tiền', 30000.00, '2025-10-23', '2025-10-26'), -- MaKM 4: Ưu đãi đặc biệt: giảm 30.000 đồng

    (N'Khuyến mãi đã hết hạn', N'Phần trăm', 15.00, '2025-10-01', '2025-10-18'); -- MaKM 5: Khuyến mãi đã hết hạn: giảm 15%
GO

-- BANG 3: PHIEU_NHAP( MaPhieuNhap 1-5)
-- MaNCC 1-5; MaNVlap NHAN_VIEN của Nhân
DECLARE @MaNVLap INT = 7;

INSERT INTO dbo.PHIEU_NHAP
    (NgayNhap, GhiChu, MaNCC, MaNVLap)
VALUES
    ('2025-10-15', N'Nhập phụ kiện và thiết bị bida đợt đầu', 1, @MaNVLap), -- MaPhieuNhap 1: Nhập phụ kiện bida từ NCC 1, ngày 15/10/2025.

    ('2025-10-17', N'Nhập nước giải khát phục vụ khách hàng', 2, @MaNVLap), -- MaPhieuNhap 2: Nhập đồ uống từ NCC 2, ngày 17/10/2025.

    ('2025-10-19',N'Nhập thực phẩm và đồ ăn nhẹ', 3, @MaNVLap), -- MaPhieuNhap 3: Nhập thực phẩm từ NCC 3, ngày 19/10/2025.

    ('2025-10-21', N'Nhập bổ sung phụ kiện bida', 4, @MaNVLap), -- MaPhieuNhap 4: Nhập phụ kiện bida từ NCC 4, ngày 21/10/2025.

    ('2025-10-23', N'Nhập bổ sung hàng hóa cho câu lạc bộ', 5, @MaNVLap); -- MaPhieuNhap 5: Nhập hàng bổ sung từ NCC 5, ngày 23/10/2025.

GO

-- BANG 4: CHI_TIET_NHAP( MaPhieuNhap MaMatHang)
--    MaPhieuNhap: PHIEU_NHAP của Khang (5 phiếu); MaMatHang: MAT_HANG của Dũng (MaMatHang 1-14)
-- Tìm mã phiếu nhập thực tế theo NCC và ngày nhập.
DECLARE @P1 INT, @P2 INT, @P3 INT, @P4 INT, @P5 INT;

SELECT @P1 = MaPhieuNhap FROM dbo.PHIEU_NHAP
WHERE MaNCC = 1 AND NgayNhap = '2025-10-15'; -- Phiếu 1 (NCC 1): MaMatHang 1, 2

SELECT @P2 = MaPhieuNhap FROM dbo.PHIEU_NHAP
WHERE MaNCC = 2 AND NgayNhap = '2025-10-17'; -- Phiếu 2 (NCC 2): MaMatHang 3, 4

SELECT @P3 = MaPhieuNhap FROM dbo.PHIEU_NHAP
WHERE MaNCC = 3 AND NgayNhap = '2025-10-19'; -- Phiếu 3 (NCC 3): MaMatHang 5, 6

SELECT @P4 = MaPhieuNhap FROM dbo.PHIEU_NHAP
WHERE MaNCC = 4 AND NgayNhap = '2025-10-21'; -- Phiếu 4 (NCC 4): MaMatHang 7, 8

SELECT @P5 = MaPhieuNhap FROM dbo.PHIEU_NHAP
WHERE MaNCC = 5 AND NgayNhap = '2025-10-23'; -- Phiếu 5 (NCC 5): MaMatHang 11, 10

IF @P1 IS NULL OR @P2 IS NULL OR @P3 IS NULL
   OR @P4 IS NULL OR @P5 IS NULL
BEGIN
    THROW 50590, N'Không tìm thấy đủ 5 phiếu nhập của Khang.', 1;
END;

IF (SELECT COUNT(*) FROM dbo.MAT_HANG
    WHERE MaMatHang BETWEEN 1 AND 11) <> 11
BEGIN
    THROW 50591, N'Không tìm thấy đủ mặt hàng có mã từ 1 đến 11.', 1;
END;

INSERT INTO dbo.CHI_TIET_NHAP
    (MaPhieuNhap, MaMatHang, SoLuongNhap, DonGiaNhap)
VALUES
    (@P1,  1, 10, 20000.00),
    (@P1,  2,  5, 50000.00),

    (@P2,  3, 20, 15000.00),
    (@P2,  4,  3, 18000.00),  -- Red Bull chỉ nhập 3 lon, khớp tồn 3 của Dũng (demo RB10)

    (@P3,  5, 10, 30000.00),
    (@P3,  6, 12, 25000.00),

    (@P4,  7,  8, 40000.00),
    (@P4,  8, 10, 35000.00),

    (@P5, 11, 15, 22000.00),  -- Khô gà lá chanh (Bia Sài Gòn đã ngừng bán nên không nhập)
    (@P5, 10, 10, 45000.00);
GO

-- PHIEU_NHAP.TongTien = tổng SoLuongNhap * DonGiaNhap của các chi tiết (RB11).
UPDATE pn
SET pn.TongTien = ct.Tong
FROM dbo.PHIEU_NHAP AS pn
JOIN (SELECT MaPhieuNhap, SUM(SoLuongNhap * DonGiaNhap) AS Tong
      FROM dbo.CHI_TIET_NHAP
      GROUP BY MaPhieuNhap) AS ct ON ct.MaPhieuNhap = pn.MaPhieuNhap;
GO

-- BANG 5: HOA_DON (MaHoaDon 1-6, mỗi phiên 'Đã thanh toán' của Dũng - MaPhien 1-6 - có đúng một hóa đơn)
-- MaPhien: PHIEN_CHOI của Dũng; MaNVLap: Thu ngân 3, 4 của Nhân; MaKM: KHUYEN_MAI của Khang (còn hạn tại ThoiDiemLap, RB13).
-- Số tiền khớp dữ liệu của Dũng theo RB12:
--   TienGioChoi = làm tròn tổng TienGio các đoạn của phiên; TienMon = tổng ThanhTien các dòng món chưa hủy.
--   TienGiam: KM theo phần trăm tính trên TienGioChoi, KM theo số tiền trừ thẳng; TongPhaiTra = TienGioChoi + TienMon - TienGiam.
INSERT INTO dbo.HOA_DON
    (ThoiDiemLap, DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM, TienGioChoi, TienMon, TienGiam, TongPhaiTra)
VALUES
    ('2025-10-26T08:00:00', 0, N'Đã thanh toán', 1, 3, 1,    245000.00, 188000.00, 24500.00, 408500.00), -- MaHoaDon 1: phiên 1, KM 10% trên tiền giờ (24.500)

    ('2025-10-26T08:30:00', 0, N'Đã thanh toán', 2, 4, 3,    135000.00,  70000.00,  6750.00, 198250.00), -- MaHoaDon 2: phiên 2, KM 5% trên tiền giờ (6.750)

    ('2025-10-26T09:00:00', 0, N'Đã thanh toán', 3, 3, NULL, 490000.00, 180000.00,     0.00, 670000.00), -- MaHoaDon 3: phiên 3, không khuyến mãi (dòng món đã hủy không tính)

    ('2025-10-26T09:30:00', 0, N'Đã thanh toán', 4, 4, 4,    331667.00,  89000.00, 30000.00, 390667.00), -- MaHoaDon 4: phiên 4, giảm cố định 30.000 (2 đoạn giờ, tiền giờ đã làm tròn)

    ('2025-10-26T10:00:00', 0, N'Đã thanh toán', 5, 3, NULL,  90000.00,  20000.00,     0.00, 110000.00), -- MaHoaDon 5: phiên 5, không khuyến mãi

    ('2025-10-26T10:30:00', 0, N'Đã thanh toán', 6, 4, NULL, 212500.00, 217000.00,     0.00, 429500.00); -- MaHoaDon 6: phiên 6, không khuyến mãi
GO

-- BANG 6: GIAO_DICH_THANH_TOAN (MaGD 1-9)
-- Tổng các giao dịch 'Thành công' của mỗi hóa đơn đúng bằng TongPhaiTra (RB14); giao dịch 'Thất bại' không được tính.
-- MaHoaDon: HOA_DON của Khang; MaNVXacNhan: Thu ngân 3, 4 của Nhân.
INSERT INTO dbo.GIAO_DICH_THANH_TOAN
    (ThoiDiemThanhToan, SoTien, PhuongThuc,
     MaThamChieu, TrangThai, MaHoaDon, MaNVXacNhan)
VALUES
    ('2025-10-26T08:05:00', 408500.00, N'Tiền mặt',        NULL,             N'Thành công', 1, 3), -- MaHoaDon 1: thanh toán đủ một lần bằng tiền mặt

    ('2025-10-26T08:35:00', 100000.00, N'Chuyển khoản/QR', N'CK20251026001', N'Thành công', 2, 4), -- MaHoaDon 2: lần 1, chuyển khoản 100.000

    ('2025-10-26T08:40:00',  98250.00, N'Tiền mặt',        NULL,             N'Thành công', 2, 4), -- MaHoaDon 2: lần 2, tiền mặt phần còn lại 98.250

    ('2025-10-26T09:05:00', 670000.00, N'Ví điện tử',      N'VDT20251026001', N'Thành công', 3, 3), -- MaHoaDon 3: thanh toán đủ bằng ví điện tử

    ('2025-10-26T09:34:00',  50000.00, N'Chuyển khoản/QR', N'CK20251026002', N'Thất bại',    4, 4), -- MaHoaDon 4: giao dịch thất bại, không tính vào số đã trả

    ('2025-10-26T09:35:00', 390667.00, N'Chuyển khoản/QR', N'CK20251026003', N'Thành công', 4, 4), -- MaHoaDon 4: thanh toán đủ sau lần thất bại

    ('2025-10-26T10:05:00', 110000.00, N'Tiền mặt',        NULL,             N'Thành công', 5, 3), -- MaHoaDon 5: thanh toán đủ bằng tiền mặt

    ('2025-10-26T10:35:00', 200000.00, N'Tiền mặt',        NULL,             N'Thành công', 6, 4), -- MaHoaDon 6: lần 1, tiền mặt 200.000

    ('2025-10-26T10:40:00', 229500.00, N'Chuyển khoản/QR', N'CK20251026004', N'Thành công', 6, 4); -- MaHoaDon 6: lần 2, chuyển khoản phần còn lại 229.500
GO

-- ############################################################################
-- KIỂM TRA SAU KHI NẠP (không thay đổi dữ liệu): truy vấn dưới đây phải trả về 0 dòng.
-- Mỗi dòng trả về là một chỗ dữ liệu của các thành viên chưa khớp nhau.
-- ############################################################################
SELECT N'Hóa đơn ' + CAST(hd.MaHoaDon AS NVARCHAR(10)) + N': tiền giờ hoặc tiền món không khớp dữ liệu phiên' AS LoiDuLieu
FROM dbo.HOA_DON AS hd
WHERE hd.TienGioChoi <> CAST(ROUND(COALESCE((SELECT SUM(d.TienGio) FROM dbo.DOAN_SU_DUNG_BAN AS d
                                             WHERE d.MaPhien = hd.MaPhien), 0), 0) AS DECIMAL(18,2))
   OR hd.TienMon <> COALESCE((SELECT SUM(m.ThanhTien) FROM dbo.DONG_GOI_MON AS m
                              WHERE m.MaPhien = hd.MaPhien AND m.TrangThaiPhucVu <> N'Đã hủy'), 0)
UNION ALL
SELECT N'Phiên ' + CAST(p.MaPhien AS NVARCHAR(10)) + N' đã thanh toán nhưng chưa có hóa đơn'
FROM dbo.PHIEN_CHOI AS p
WHERE p.TrangThai = N'Đã thanh toán'
  AND NOT EXISTS (SELECT 1 FROM dbo.HOA_DON AS hd WHERE hd.MaPhien = p.MaPhien)
UNION ALL
SELECT N'Hóa đơn ' + CAST(hd.MaHoaDon AS NVARCHAR(10)) + N': tổng giao dịch thành công khác TongPhaiTra'
FROM dbo.HOA_DON AS hd
WHERE hd.TrangThaiThanhToan = N'Đã thanh toán'
  AND hd.TongPhaiTra <> COALESCE((SELECT SUM(g.SoTien) FROM dbo.GIAO_DICH_THANH_TOAN AS g
                                  WHERE g.MaHoaDon = hd.MaHoaDon AND g.TrangThai = N'Thành công'), 0)
UNION ALL
SELECT N'Phiếu nhập ' + CAST(pn.MaPhieuNhap AS NVARCHAR(10)) + N': TongTien khác tổng chi tiết'
FROM dbo.PHIEU_NHAP AS pn
WHERE pn.TongTien <> COALESCE((SELECT SUM(c.SoLuongNhap * c.DonGiaNhap) FROM dbo.CHI_TIET_NHAP AS c
                               WHERE c.MaPhieuNhap = pn.MaPhieuNhap), 0)
UNION ALL
SELECT N'Bàn ' + CAST(b.MaBan AS NVARCHAR(10)) + N': trạng thái ' + b.TrangThai + N' không khớp đoạn đang mở hoặc phiếu đã xác nhận'
FROM dbo.BAN AS b
WHERE b.TrangThai IN (N'Trống', N'Đang chơi', N'Đã đặt')
  AND b.TrangThai <> CASE
        WHEN EXISTS (SELECT 1 FROM dbo.DOAN_SU_DUNG_BAN AS d
                     WHERE d.MaBan = b.MaBan AND d.GioKetThucDung IS NULL) THEN N'Đang chơi'
        WHEN EXISTS (SELECT 1 FROM dbo.GIU_BAN AS g
                     JOIN dbo.PHIEU_DAT_BAN AS pd ON pd.MaDatBan = g.MaDatBan
                     WHERE g.MaBan = b.MaBan AND pd.TrangThai = N'Đã xác nhận') THEN N'Đã đặt'
        ELSE N'Trống' END;
GO
