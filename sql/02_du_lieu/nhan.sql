-- 02_du_lieu/nhan.sql (Nhân): VAI_TRO, TAI_KHOAN, DUOC_CAP, NHAN_VIEN, NV_TOAN_THOI_GIAN, NV_BAN_THOI_GIAN
--
-- Mã (IDENTITY) do SQL Server cấp theo thứ tự dòng. CSDL được dựng lại từ đầu mỗi lần chạy nên mã cố định,
-- người khác có thể dùng trực tiếp trong file 02_du_lieu của mình:
--   VAI_TRO    : 1 Quản lý, 2 Thu ngân, 3 Phục vụ, 4 Pha chế, 5 Thủ kho, 6 Hội viên
--   TAI_KHOAN  : MaTK 1-11 là 11 nhân viên, MaTK 12-16 là 5 hội viên (HOI_VIEN.MaTK của Phong dùng 12-16)
--   NHAN_VIEN  : MaNV = MaTK với 11 nhân viên (MaNV 1-11)
--     Quản lý  : 1, 2          Thu ngân: 3, 4, 11       Phục vụ: 5, 8, 9
--     Pha chế  : 6, 10         Thủ kho : 7
--     Đang làm : 1-7, 9-11     Đã nghỉ : 8 (tài khoản 8 cũng bị khóa, dùng để demo RB2)
-- Mật khẩu mẫu của mọi tài khoản là 'Bida@' + tên đăng nhập (lưu SHA-256, chỉ để demo).
USE BidaHub;
GO

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
