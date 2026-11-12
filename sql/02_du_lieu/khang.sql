-- ========================================================================================================================
-- 02_du_lieu/khang.sql:
-- NHA_CUNG_CAP, PHIEU_NHAP, CHI_TIET_NHAP, KHUYEN_MAI, HOA_DON, GIAO_DICH_THANH_TOAN
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

-- 5. HOA_DON (dự kiến MaHoaDon 1-5):
--    Theo dữ liệu mẫu của Dũng:
--       - MaPhien 1-6 : Trạng thái 'Đã thanh toán'
--       - MaPhien 7-8 : 'Đã kết thúc', chưa có hóa đơn
--       - MaPhien 9-10: 'Đang chơi'
--    Mỗi hóa đơn gồm:
--       - TienGioChoi : Tiền sử dụng bàn
--       - TienMon     : Tiền đồ ăn, thức uống
--       - TienGiam    : Tiền được giảm
--       - TongPhaiTra : Tổng số tiền phải thanh toán
--    Nhân viên lập hóa đơn:
--       - MaNV 3: Phạm Thị Lan - Thu ngân
--       - MaNV 4: Trần Quốc Hùng - Thu ngân
-- 6. GIAO_DICH_THANH_TOAN (dự kiến 6-8 dòng):
--    Mỗi giao dịch liên kết:
--       - MaHoaDon   : HOA_DON của Khang
--       - MaNVXacNhan: NHAN_VIEN của Nhân
--    Các phương thức thanh toán:
--       - 'Tiền mặt'
--       - 'Chuyển khoản/QR'
--       - 'Ví điện tử'
--    Các trạng thái giao dịch:
--       - 'Thành công'
--       - 'Thất bại'
--    Dự kiến tạo các tình huống:
--       - Hóa đơn được thanh toán đủ một lần
--       - Hóa đơn được thanh toán qua nhiều giao dịch
--       - Hóa đơn mới thanh toán một phần
--       - Giao dịch thất bại không được cộng vào số tiền đã trả
--    Nhân viên xác nhận thanh toán:
--       - MaNV 3: Phạm Thị Lan - Thu ngân
--       - MaNV 4: Trần Quốc Hùng - Thu ngân
-- ======================================================================================================================

USE BidaHub;
GO

-- BANG 1: NHA_CUNG_CAP (5 nhà cung cấp: MaNCC: 1-5)
INSERT INTO dbo.NHA_CUNG_CAP
    (TenNhaCungCap, DiaChi, SoDienThoai, Email)
VALUES
    (N'Công ty Thiết bị Bida An Phát', N'TP. Hồ Chí Minh', N'0901000001', N'anphat@example.com'), -- MaNCC 1: Công ty Thiết bị Bida An Phát

    (N'Công ty Đồ uống Minh Long', N'Đồng Nai', N'0901000002', N'minhlong@example.com'), -- MaNCC 2: Công ty Đồ uống Minh Long

    (N'Nhà cung cấp Thực phẩm Hưng Thịnh', N'Bình Dương', N'0901000003', N'hungthinh@example.com'), -- MaNCC 3: Nhà cung cấp Thực phẩm Hưng Thịnh

    (N'Công ty Phụ kiện Bida Hoàng Gia', N'Hà Nội', N'0901000004', N'hoanggia@example.com'), -- MaNCC 4: Công ty Phụ kiện Bida Hoàng Gia

    (N'Công ty Thương mại Đại Phát', N'Đà Nẵng', N'0901000005', N'daiphat@example.com'); -- MaNCC 5: Công ty Thương mại Đại Phát

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
WHERE MaNCC = 5 AND NgayNhap = '2025-10-23'; -- Phiếu 5 (NCC 5): MaMatHang 9, 10

IF @P1 IS NULL OR @P2 IS NULL OR @P3 IS NULL
   OR @P4 IS NULL OR @P5 IS NULL
BEGIN
    THROW 50590, N'Không tìm thấy đủ 5 phiếu nhập của Khang.', 1;
END;

IF (SELECT COUNT(*) FROM dbo.MAT_HANG
    WHERE MaMatHang BETWEEN 1 AND 10) <> 10
BEGIN
    THROW 50591, N'Không tìm thấy đủ mặt hàng có mã từ 1 đến 10.', 1;
END;

INSERT INTO dbo.CHI_TIET_NHAP
    (MaPhieuNhap, MaMatHang, SoLuongNhap, DonGiaNhap)
VALUES
    (@P1,  1, 10, 20000.00),
    (@P1,  2,  5, 50000.00),

    (@P2,  3, 20, 15000.00),
    (@P2,  4, 15, 18000.00),

    (@P3,  5, 10, 30000.00),
    (@P3,  6, 12, 25000.00),

    (@P4,  7,  8, 40000.00),
    (@P4,  8, 10, 35000.00),

    (@P5,  9, 15, 22000.00),
    (@P5, 10, 10, 45000.00);
GO

-- BANG 5: HOA_DON( MaHoaDon 1-5)
-- MaPhien  : PHIEN_CHOI của Dũng (1-5); MaNVLap  : NHAN_VIEN của Nhân; MaKM: KHUYEN_MAI của Khang
INSERT INTO dbo.HOA_DON
    (ThoiDiemLap, DiemCong, TrangThaiThanhToan, MaPhien, MaNVLap, MaKM, TienGioChoi, TienMon, TienGiam, TongPhaiTra)
VALUES
    ('2025-10-26T08:00:00', 0, N'Đã thanh toán', 1, 3, 1, 150000.00, 70000.00, 15000.00, 205000.00), -- MaPhien 1: Có khuyến mãi 10%, thanh toán đủ

    ('2025-10-26T08:30:00', 0, N'Đã thanh toán', 2, 4, 3, 200000.00, 80000.00, 10000.00, 270000.00), -- MaPhien 2: Có khuyến mãi 5%, thanh toán đủ

    ('2025-10-26T09:00:00', 0, N'Đã thanh toán', 3, 3, NULL, 120000.00, 50000.00, 0.00, 170000.00), -- MaPhien 3: Không khuyến mãi, thanh toán đủ

    ('2025-10-26T09:30:00', 0, N'Đã thanh toán', 4, 4, 4, 240000.00, 100000.00, 30000.00, 310000.00), -- MaPhien 4: Giảm cố định 30.000 đồng, thanh toán đủ

    ('2025-10-26T10:00:00', 0, N'Đã thanh toán', 5, 3, NULL, 180000.00, 45000.00, 0.00, 225000.00); -- MaPhien 5: Không khuyến mãi, thanh toán đủ

GO

-- BANG 6: GIAO_DICH_THANH_TOAN( MaGD: 1-7)
-- MaHoaDon: HOA_DON của Khang; MaNVXacNhan: NHAN_VIEN của Nhân

INSERT INTO dbo.GIAO_DICH_THANH_TOAN
    (ThoiDiemThanhToan, SoTien, PhuongThuc,
     MaThamChieu, TrangThai, MaHoaDon, MaNVXacNhan)
VALUES
    ('2025-10-26T08:05:00', 205000.00, N'Tiền mặt', NULL, N'Thành công', 1, 3), -- MaHoaDon 1: Giao dịch 1: Thanh toán đủ 205.000 đồng bằng tiền mặt

    ('2025-10-26T08:35:00', 100000.00, N'Chuyển khoản/QR', N'CK20251026001', N'Thành công', 2, 4), -- MaHoaDon 2: Giao dịch 2: Thanh toán 100.000 đồng bằng chuyển khoản

    ('2025-10-26T08:40:00', 170000.00, N'Tiền mặt', NULL, N'Thành công', 2, 4), -- MaHoaDon 2: Giao dịch 3: Thanh toán tiếp 170.000 đồng bằng tiền mặt

    ('2025-10-26T09:05:00', 170000.00, N'Ví điện tử', N'VDT20251026001', N'Thành công', 3, 3), -- MaHoaDon 3: Giao dịch 4: Thanh toán đủ 170.000 đồng bằng ví điện tử

    ('2025-10-26T09:34:00', 50000.00, N'Chuyển khoản/QR', N'CK20251026002', N'Thất bại', 4, 4), -- MaHoaDon 4: Giao dịch 5: Thanh toán thất bại 50.000 đồng

    ('2025-10-26T09:35:00', 310000.00, N'Chuyển khoản/QR', N'CK20251026003', N'Thành công', 4, 4), -- MaHoaDon 4: Giao dịch 6: Thanh toán thành công 310.000 đồng

    ('2025-10-26T10:05:00', 225000.00, N'Tiền mặt', NULL, N'Thành công', 5, 3); -- MaHoaDon 5: Giao dịch 7: Thanh toán đủ 225.000 đồng bằng tiền mặt
GO