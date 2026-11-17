-- ============================================================================
-- Hệ thống Quản lý Quán Bida - BidaHub
-- Phần việc thành viên: Đào Huy Phong (MSSV: 2412628)
-- File: sql/04_thu_tuc/phong.sql
-- Mô tả: 
--   1. Câu 2.1: Các thủ tục Thêm, Sửa, Xóa trên bảng KHACH_HANG:
--      - sp_ThemKhachHang: Thêm khách hàng mới, validate dữ liệu, tự động sinh mã IDENTITY
--      - sp_SuaKhachHang: Sửa thông tin khách hàng, kiểm tra hợp lệ
--      - sp_XoaKhachHang: Xóa khách hàng với kiểm tra ràng buộc toàn vẹn và nghiệp vụ
--   2. Câu 2.3: Các thủ tục hiển thị dữ liệu:
--      - sp_TraCuuKhachHang: Tra cứu khách hàng từ >= 2 bảng, có WHERE, ORDER BY
--      - sp_ThongKeChiTieuKhachHang: Thống kê chi tiêu khách hàng có GROUP BY, HAVING, WHERE, ORDER BY
-- Dải mã lỗi của Phong: 50200 - 50299
-- ============================================================================

USE BidaHub;
GO

-- ============================================================================
-- PHẦN 1: CÂU 2.1 - THỦ TỤC THÊM, SỬA, XÓA TRÊN BẢNG KHACH_HANG
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1. Thủ tục Thêm khách hàng: sp_ThemKhachHang
-- Mô tả: Thêm một khách hàng mới vào hệ thống BidaHub.
--        Mã khách hàng tự động sinh qua thuộc tính IDENTITY(1,1).
--        Nếu có @SoDienThoai, thủ tục tự động thêm vào bảng KHACH_HANG_SDT.
-- Ràng buộc kiểm tra:
--   - Họ không được để trống (50202)
--   - Tên không được để trống (50203)
--   - Giới tính phải là 'Nam', 'Nữ' hoặc 'Khác' (50204)
--   - Ngày sinh không được ở tương lai (50205)
--   - Tuổi không được vượt quá 120 (50206)
--   - Định dạng số điện thoại: 10 chữ số, bắt đầu bằng 0 (50207)
--   - Số điện thoại không được trùng với khách khác (50208)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ThemKhachHang
    @Ho             NVARCHAR(30),
    @TenDem         NVARCHAR(30) = NULL,
    @Ten            NVARCHAR(30),
    @NgaySinh       DATE         = NULL,
    @GioiTinh       NVARCHAR(10) = NULL,
    @SoDienThoai    VARCHAR(15)  = NULL,
    @MaKH           INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validate Họ
    SET @Ho = LTRIM(RTRIM(@Ho));
    IF @Ho IS NULL OR LEN(@Ho) = 0
    BEGIN
        THROW 50202, N'Lỗi thêm khách hàng: Họ của khách hàng không được để trống.', 1;
        RETURN;
    END

    -- 2. Validate Tên
    SET @Ten = LTRIM(RTRIM(@Ten));
    IF @Ten IS NULL OR LEN(@Ten) = 0
    BEGIN
        THROW 50203, N'Lỗi thêm khách hàng: Tên của khách hàng không được để trống.', 1;
        RETURN;
    END

    -- Chuẩn hóa Tên đệm
    SET @TenDem = LTRIM(RTRIM(@TenDem));
    IF LEN(@TenDem) = 0 SET @TenDem = NULL;

    -- 3. Validate Giới tính
    IF @GioiTinh IS NOT NULL
    BEGIN
        SET @GioiTinh = LTRIM(RTRIM(@GioiTinh));
        IF LEN(@GioiTinh) = 0
            SET @GioiTinh = NULL;
        ELSE IF @GioiTinh NOT IN (N'Nam', N'Nữ', N'Khác')
        BEGIN
            THROW 50204, N'Lỗi thêm khách hàng: Giới tính không hợp lệ. Chỉ chấp nhận ''Nam'', ''Nữ'' hoặc ''Khác''.', 1;
            RETURN;
        END
    END

    -- 4. Validate Ngày sinh và Tuổi
    IF @NgaySinh IS NOT NULL
    BEGIN
        IF @NgaySinh > CAST(GETDATE() AS DATE)
        BEGIN
            THROW 50205, N'Lỗi thêm khách hàng: Ngày sinh không được lớn hơn ngày hiện tại.', 1;
            RETURN;
        END

        IF DATEDIFF(YEAR, @NgaySinh, GETDATE()) > 120
        BEGIN
            THROW 50206, N'Lỗi thêm khách hàng: Tuổi khách hàng không hợp lệ (vượt quá 120 tuổi).', 1;
            RETURN;
        END
    END

    -- 5. Validate Số điện thoại
    IF @SoDienThoai IS NOT NULL
    BEGIN
        SET @SoDienThoai = LTRIM(RTRIM(@SoDienThoai));
        IF LEN(@SoDienThoai) > 0
        BEGIN
            IF @SoDienThoai LIKE '%[^0-9]%' OR LEN(@SoDienThoai) NOT BETWEEN 10 AND 11 OR @SoDienThoai NOT LIKE '0%'
            BEGIN
                THROW 50207, N'Lỗi thêm khách hàng: Số điện thoại không hợp lệ (phải từ 10-11 chữ số và bắt đầu bằng số 0).', 1;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM dbo.KHACH_HANG_SDT WHERE SoDienThoai = @SoDienThoai)
            BEGIN
                THROW 50208, N'Lỗi thêm khách hàng: Số điện thoại này đã được đăng ký bởi khách hàng khác.', 1;
                RETURN;
            END
        END
        ELSE
            SET @SoDienThoai = NULL;
    END

    -- 6. Thực hiện chèn dữ liệu với Transaction
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO dbo.KHACH_HANG (Ho, TenDem, Ten, NgaySinh, GioiTinh)
        VALUES (@Ho, @TenDem, @Ten, @NgaySinh, @GioiTinh);

        SET @MaKH = SCOPE_IDENTITY();

        IF @SoDienThoai IS NOT NULL
        BEGIN
            INSERT INTO dbo.KHACH_HANG_SDT (MaKH, SoDienThoai)
            VALUES (@MaKH, @SoDienThoai);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Trả về bản ghi vừa tạo
    SELECT 
        kh.MaKH,
        kh.Ho,
        kh.TenDem,
        kh.Ten,
        LTRIM(RTRIM(ISNULL(kh.Ho, '') + ' ' + ISNULL(kh.TenDem + ' ', '') + ISNULL(kh.Ten, ''))) AS HoTen,
        kh.NgaySinh,
        kh.GioiTinh,
        @SoDienThoai AS SoDienThoai
    FROM dbo.KHACH_HANG kh
    WHERE kh.MaKH = @MaKH;
END;
GO

-- ----------------------------------------------------------------------------
-- 1.2. Thủ tục Sửa khách hàng: sp_SuaKhachHang
-- Mô tả: Cập nhật thông tin khách hàng và cập nhật/bổ sung số điện thoại.
-- Ràng buộc kiểm tra:
--   - Mã khách hàng phải tồn tại (50209)
--   - Validate Họ, Tên, Giới tính, Ngày sinh, Tuổi
--   - Validate Số điện thoại không bị trùng với khách hàng khác (50208)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_SuaKhachHang
    @MaKH           INT,
    @Ho             NVARCHAR(30),
    @TenDem         NVARCHAR(30) = NULL,
    @Ten            NVARCHAR(30),
    @NgaySinh       DATE         = NULL,
    @GioiTinh       NVARCHAR(10) = NULL,
    @SoDienThoai    VARCHAR(15)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @MaKH IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = @MaKH)
    BEGIN
        THROW 50209, N'Lỗi sửa khách hàng: Không tìm thấy khách hàng với mã đã cung cấp.', 1;
        RETURN;
    END

    -- Validate Họ
    SET @Ho = LTRIM(RTRIM(@Ho));
    IF @Ho IS NULL OR LEN(@Ho) = 0
    BEGIN
        THROW 50202, N'Lỗi sửa khách hàng: Họ của khách hàng không được để trống.', 1;
        RETURN;
    END

    -- Validate Tên
    SET @Ten = LTRIM(RTRIM(@Ten));
    IF @Ten IS NULL OR LEN(@Ten) = 0
    BEGIN
        THROW 50203, N'Lỗi sửa khách hàng: Tên của khách hàng không được để trống.', 1;
        RETURN;
    END

    SET @TenDem = LTRIM(RTRIM(@TenDem));
    IF LEN(@TenDem) = 0 SET @TenDem = NULL;

    -- Validate Giới tính
    IF @GioiTinh IS NOT NULL
    BEGIN
        SET @GioiTinh = LTRIM(RTRIM(@GioiTinh));
        IF LEN(@GioiTinh) = 0
            SET @GioiTinh = NULL;
        ELSE IF @GioiTinh NOT IN (N'Nam', N'Nữ', N'Khác')
        BEGIN
            THROW 50204, N'Lỗi sửa khách hàng: Giới tính không hợp lệ. Chỉ chấp nhận ''Nam'', ''Nữ'' hoặc ''Khác''.', 1;
            RETURN;
        END
    END

    -- Validate Ngày sinh và Tuổi
    IF @NgaySinh IS NOT NULL
    BEGIN
        IF @NgaySinh > CAST(GETDATE() AS DATE)
        BEGIN
            THROW 50205, N'Lỗi sửa khách hàng: Ngày sinh không được lớn hơn ngày hiện tại.', 1;
            RETURN;
        END

        IF DATEDIFF(YEAR, @NgaySinh, GETDATE()) > 120
        BEGIN
            THROW 50206, N'Lỗi sửa khách hàng: Tuổi khách hàng không hợp lệ (vượt quá 120 tuổi).', 1;
            RETURN;
        END
    END

    -- Validate Số điện thoại
    IF @SoDienThoai IS NOT NULL
    BEGIN
        SET @SoDienThoai = LTRIM(RTRIM(@SoDienThoai));
        IF LEN(@SoDienThoai) > 0
        BEGIN
            IF @SoDienThoai LIKE '%[^0-9]%' OR LEN(@SoDienThoai) NOT BETWEEN 10 AND 11 OR @SoDienThoai NOT LIKE '0%'
            BEGIN
                THROW 50207, N'Lỗi sửa khách hàng: Số điện thoại không hợp lệ (phải từ 10-11 chữ số và bắt đầu bằng số 0).', 1;
                RETURN;
            END

            -- Kiểm tra số điện thoại có bị trùng với khách hàng khác không
            IF EXISTS (SELECT 1 FROM dbo.KHACH_HANG_SDT WHERE SoDienThoai = @SoDienThoai AND MaKH <> @MaKH)
            BEGIN
                THROW 50208, N'Lỗi sửa khách hàng: Số điện thoại này đã được đăng ký bởi khách hàng khác.', 1;
                RETURN;
            END
        END
        ELSE
            SET @SoDienThoai = NULL;
    END

    -- Thực hiện cập nhật
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE dbo.KHACH_HANG
        SET Ho = @Ho,
            TenDem = @TenDem,
            Ten = @Ten,
            NgaySinh = @NgaySinh,
            GioiTinh = @GioiTinh
        WHERE MaKH = @MaKH;

        -- Đồng bộ số điện thoại chính: Nếu khách chưa có số điện thoại này thì thêm mới
        IF @SoDienThoai IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG_SDT WHERE MaKH = @MaKH AND SoDienThoai = @SoDienThoai)
            BEGIN
                DELETE FROM dbo.KHACH_HANG_SDT WHERE MaKH = @MaKH;
                INSERT INTO dbo.KHACH_HANG_SDT (MaKH, SoDienThoai)
                VALUES (@MaKH, @SoDienThoai);
            END
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Trả về dữ liệu sau khi sửa
    SELECT 
        kh.MaKH,
        kh.Ho,
        kh.TenDem,
        kh.Ten,
        LTRIM(RTRIM(ISNULL(kh.Ho, '') + ' ' + ISNULL(kh.TenDem + ' ', '') + ISNULL(kh.Ten, ''))) AS HoTen,
        kh.NgaySinh,
        kh.GioiTinh,
        @SoDienThoai AS SoDienThoai
    FROM dbo.KHACH_HANG kh
    WHERE kh.MaKH = @MaKH;
END;
GO

-- ----------------------------------------------------------------------------
-- 1.3. Thủ tục Xóa khách hàng: sp_XoaKhachHang
-- Mô tả & Mục đích:
--   - Mục đích: Xóa hồ sơ khách hàng tạo nhầm, thông tin thử nghiệm hoặc khách vãng 
--     lai chưa từng phát sinh bất kỳ giao dịch/hoạt động nào tại quán, giúp giải phóng
--     dữ liệu rác và bảo đảm tính sạch sẽ của CSDL.
--   - Ràng buộc khi nào ĐƯỢC XÓA và KHÔNG ĐƯỢC XÓA:
--     + KHÔNG ĐƯỢC XÓA nếu khách hàng đã có phiếu đặt bàn (PHIEU_DAT_BAN) (50210)
--     + KHÔNG ĐƯỢC XÓA nếu khách hàng đã có lịch sử phiên chơi (PHIEN_CHOI) (50211)
--     + KHÔNG ĐƯỢC XÓA nếu khách là hội viên có DiemTichLuy > 0 hoặc đã liên kết tài khoản MaTK (50212)
--     + ĐƯỢC XÓA nếu khách hàng chỉ mới có thông tin liên lạc (KHACH_HANG_SDT) hoặc hội viên 0 điểm chưa chơi.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_XoaKhachHang
    @MaKH INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Kiểm tra tồn tại
    IF @MaKH IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = @MaKH)
    BEGIN
        THROW 50209, N'Lỗi xóa khách hàng: Không tìm thấy khách hàng với mã đã cung cấp.', 1;
        RETURN;
    END

    -- 2. Kiểm tra ràng buộc phiếu đặt bàn (PHIEU_DAT_BAN)
    IF OBJECT_ID('dbo.PHIEU_DAT_BAN', 'U') IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.PHIEU_DAT_BAN WHERE MaKH = @MaKH)
        BEGIN
            THROW 50210, N'Lỗi xóa khách hàng: Không thể xóa khách hàng vì đã có lịch sử phiếu đặt bàn trong hệ thống.', 1;
            RETURN;
        END
    END

    -- 3. Kiểm tra ràng buộc phiên chơi (PHIEN_CHOI)
    IF OBJECT_ID('dbo.PHIEN_CHOI', 'U') IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.PHIEN_CHOI WHERE MaKH = @MaKH)
        BEGIN
            THROW 50211, N'Lỗi xóa khách hàng: Không thể xóa khách hàng vì đã có lịch sử phiên chơi trong hệ thống.', 1;
            RETURN;
        END
    END

    -- 4. Kiểm tra ràng buộc hội viên có điểm tích lũy hoặc có tài khoản
    IF EXISTS (
        SELECT 1 FROM dbo.HOI_VIEN 
        WHERE MaKH = @MaKH AND (DiemTichLuy > 0 OR MaTK IS NOT NULL)
    )
    BEGIN
        THROW 50212, N'Lỗi xóa khách hàng: Không thể xóa hội viên đang có điểm tích lũy hoặc tài khoản đăng nhập.', 1;
        RETURN;
    END

    -- 5. Thực hiện xóa an toàn
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Xóa hội viên nếu có (trường hợp hội viên 0 điểm chưa giao dịch)
        DELETE FROM dbo.HOI_VIEN WHERE MaKH = @MaKH;

        -- Xóa số điện thoại
        DELETE FROM dbo.KHACH_HANG_SDT WHERE MaKH = @MaKH;

        -- Xóa khách hàng
        DELETE FROM dbo.KHACH_HANG WHERE MaKH = @MaKH;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT 1 AS DaXoa, N'Đã xóa khách hàng thành công.' AS ThongBao;
END;
GO

-- ============================================================================
-- PHẦN 2: CÂU 2.3 - HAI THỦ TỤC HIỂN THỊ DỮ LIỆU
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1. Thủ tục Tra cứu khách hàng: sp_TraCuuKhachHang
-- Yêu cầu thỏa mãn:
--   - Liên kết từ 2 bảng trở lên: KHACH_HANG, KHACH_HANG_SDT, HOI_VIEN, HANG_THANH_VIEN
--   - Có mệnh đề WHERE (tham số lọc)
--   - Có mệnh đề ORDER BY
--   - Trực tiếp liên quan đến bảng trong câu 2.1 (KHACH_HANG)
-- Tham số:
--   - @TuKhoa: tìm theo họ tên hoặc số điện thoại
--   - @GioiTinh: lọc giới tính (Nam, Nữ, Khác)
--   - @LoaiKhach: 'HoiVien' (chỉ hội viên), 'VangLai' (khách chưa là hội viên), NULL (tất cả)
--   - @MaHang: lọc theo mã hạng thành viên (1, 2, 3...)
--   - @SapXepTheo: 'Ten', 'MaKH', 'DiemTichLuy', 'NgaySinh'
--   - @HuongSapXep: 'ASC', 'DESC'
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_TraCuuKhachHang
    @TuKhoa         NVARCHAR(100) = NULL,
    @GioiTinh       NVARCHAR(10)  = NULL,
    @LoaiKhach      NVARCHAR(20)  = NULL,
    @MaHang         INT           = NULL,
    @SapXepTheo     VARCHAR(20)   = 'Ten',
    @HuongSapXep    VARCHAR(5)    = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    SET @TuKhoa = LTRIM(RTRIM(@TuKhoa));
    IF LEN(@TuKhoa) = 0 SET @TuKhoa = NULL;

    SET @GioiTinh = LTRIM(RTRIM(@GioiTinh));
    IF LEN(@GioiTinh) = 0 SET @GioiTinh = NULL;

    SET @LoaiKhach = LTRIM(RTRIM(@LoaiKhach));
    IF LEN(@LoaiKhach) = 0 SET @LoaiKhach = NULL;

    ;WITH DanhSachSDT AS (
        SELECT 
            MaKH,
            STRING_AGG(SoDienThoai, ', ') WITHIN GROUP (ORDER BY SoDienThoai) AS TatCaSDT,
            MIN(SoDienThoai) AS SoDienThoaiChinh
        FROM dbo.KHACH_HANG_SDT
        GROUP BY MaKH
    ),
    KetQuaChuaSapXep AS (
        SELECT 
            kh.MaKH,
            kh.Ho,
            kh.TenDem,
            kh.Ten,
            LTRIM(RTRIM(ISNULL(kh.Ho, '') + ' ' + ISNULL(kh.TenDem + ' ', '') + ISNULL(kh.Ten, ''))) AS HoTen,
            kh.NgaySinh,
            DATEDIFF(YEAR, kh.NgaySinh, GETDATE()) AS Tuoi,
            kh.GioiTinh,
            ISNULL(sdt.TatCaSDT, N'Chưa có') AS SoDienThoai,
            CASE WHEN hv.MaKH IS NOT NULL THEN 1 ELSE 0 END AS LaHoiVien,
            CASE WHEN hv.MaKH IS NOT NULL THEN N'Hội viên' ELSE N'Khách vãng lai' END AS LoaiKhachHang,
            hv.NgayDangKy,
            ISNULL(hv.DiemTichLuy, 0) AS DiemTichLuy,
            htv.MaHang,
            ISNULL(htv.TenHang, N'Chưa có') AS TenHang,
            ISNULL(htv.PhanTramGiamGia, 0.00) AS PhanTramGiamGia
        FROM dbo.KHACH_HANG kh
        LEFT JOIN DanhSachSDT sdt ON kh.MaKH = sdt.MaKH
        LEFT JOIN dbo.HOI_VIEN hv ON kh.MaKH = hv.MaKH
        LEFT JOIN dbo.HANG_THANH_VIEN htv ON hv.MaHang = htv.MaHang
        WHERE 
            -- Lọc từ khóa theo họ tên hoặc số điện thoại
            (@TuKhoa IS NULL 
             OR kh.Ho LIKE N'%' + @TuKhoa + N'%'
             OR kh.Ten LIKE N'%' + @TuKhoa + N'%'
             OR (kh.Ho + ' ' + ISNULL(kh.TenDem + ' ', '') + kh.Ten) LIKE N'%' + @TuKhoa + N'%'
             OR sdt.TatCaSDT LIKE '%' + @TuKhoa + '%')
            -- Lọc theo giới tính
            AND (@GioiTinh IS NULL OR kh.GioiTinh = @GioiTinh)
            -- Lọc theo loại khách hàng
            AND (
                @LoaiKhach IS NULL
                OR (@LoaiKhach = 'HoiVien' AND hv.MaKH IS NOT NULL)
                OR (@LoaiKhach = 'VangLai' AND hv.MaKH IS NULL)
            )
            -- Lọc theo hạng thành viên
            AND (@MaHang IS NULL OR htv.MaHang = @MaHang)
    )
    SELECT *
    FROM KetQuaChuaSapXep
    ORDER BY 
        CASE WHEN @SapXepTheo = 'Ten' AND @HuongSapXep = 'ASC' THEN Ten END ASC,
        CASE WHEN @SapXepTheo = 'Ten' AND @HuongSapXep = 'DESC' THEN Ten END DESC,
        CASE WHEN @SapXepTheo = 'MaKH' AND @HuongSapXep = 'ASC' THEN MaKH END ASC,
        CASE WHEN @SapXepTheo = 'MaKH' AND @HuongSapXep = 'DESC' THEN MaKH END DESC,
        CASE WHEN @SapXepTheo = 'DiemTichLuy' AND @HuongSapXep = 'ASC' THEN DiemTichLuy END ASC,
        CASE WHEN @SapXepTheo = 'DiemTichLuy' AND @HuongSapXep = 'DESC' THEN DiemTichLuy END DESC,
        CASE WHEN @SapXepTheo = 'NgaySinh' AND @HuongSapXep = 'ASC' THEN NgaySinh END ASC,
        CASE WHEN @SapXepTheo = 'NgaySinh' AND @HuongSapXep = 'DESC' THEN NgaySinh END DESC,
        MaKH ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 2.2. Thủ tục Thống kê chi tiêu khách hàng: sp_ThongKeChiTieuKhachHang
-- Yêu cầu thỏa mãn:
--   - Liên kết từ 2 bảng trở lên: KHACH_HANG, HOI_VIEN, HANG_THANH_VIEN, PHIEN_CHOI, HOA_DON
--   - Có aggregate functions: COUNT(), SUM(), AVG(), MAX()
--   - Có mệnh đề GROUP BY
--   - Có mệnh đề HAVING
--   - Có mệnh đề WHERE
--   - Có mệnh đề ORDER BY
--   - Liên quan mật thiết tới bảng KHACH_HANG của câu 2.1
-- Tham số:
--   - @TuNgay, @DenNgay: khoảng thời gian mở phiên chơi
--   - @MaHang: lọc theo hạng thành viên (1, 2, 3...)
--   - @SoLuotChoiToiThieu: lọc HAVING số lượt chơi >= @SoLuotChoiToiThieu
--   - @TongChiTieuToiThieu: lọc HAVING tổng tiền đã thanh toán >= @TongChiTieuToiThieu
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ThongKeChiTieuKhachHang
    @TuNgay                 DATE            = NULL,
    @DenNgay                DATE            = NULL,
    @MaHang                 INT             = NULL,
    @SoLuotChoiToiThieu     INT             = 0,
    @TongChiTieuToiThieu    DECIMAL(18, 2)  = 0.00
AS
BEGIN
    SET NOCOUNT ON;

    -- Kiểm tra bảng PHIEN_CHOI và HOA_DON tồn tại
    IF OBJECT_ID('dbo.PHIEN_CHOI', 'U') IS NULL OR OBJECT_ID('dbo.HOA_DON', 'U') IS NULL
    BEGIN
        SELECT 
            kh.MaKH,
            LTRIM(RTRIM(ISNULL(kh.Ho, '') + ' ' + ISNULL(kh.TenDem + ' ', '') + ISNULL(kh.Ten, ''))) AS HoTen,
            kh.GioiTinh,
            ISNULL(htv.TenHang, N'Khách vãng lai') AS TenHang,
            ISNULL(hv.DiemTichLuy, 0) AS DiemTichLuy,
            CAST(0 AS INT) AS SoLuotChoi,
            CAST(0 AS INT) AS TongPhutChoi,
            CAST(0.00 AS DECIMAL(18, 2)) AS TongChiTieu,
            CAST(0.00 AS DECIMAL(18, 2)) AS ChiTieuTrungBinh,
            CAST(NULL AS DATETIME) AS LanChoiGanNhat
        FROM dbo.KHACH_HANG kh
        LEFT JOIN dbo.HOI_VIEN hv ON kh.MaKH = hv.MaKH
        LEFT JOIN dbo.HANG_THANH_VIEN htv ON hv.MaHang = htv.MaHang
        WHERE 1 = 0;
        RETURN;
    END

    SELECT 
        kh.MaKH,
        LTRIM(RTRIM(ISNULL(kh.Ho, '') + ' ' + ISNULL(kh.TenDem + ' ', '') + ISNULL(kh.Ten, ''))) AS HoTen,
        kh.GioiTinh,
        ISNULL(htv.TenHang, N'Khách vãng lai') AS TenHang,
        ISNULL(hv.DiemTichLuy, 0) AS DiemTichLuy,
        COUNT(pc.MaPhien) AS SoLuotChoi,
        ISNULL(SUM(DATEDIFF(MINUTE, pc.GioBatDau, ISNULL(pc.GioKetThuc, pc.GioBatDau))), 0) AS TongPhutChoi,
        ISNULL(SUM(hd.TongPhaiTra), 0.00) AS TongChiTieu,
        ISNULL(AVG(hd.TongPhaiTra), 0.00) AS ChiTieuTrungBinh,
        MAX(pc.GioBatDau) AS LanChoiGanNhat
    FROM dbo.KHACH_HANG kh
    LEFT JOIN dbo.HOI_VIEN hv ON kh.MaKH = hv.MaKH
    LEFT JOIN dbo.HANG_THANH_VIEN htv ON hv.MaHang = htv.MaHang
    INNER JOIN dbo.PHIEN_CHOI pc ON kh.MaKH = pc.MaKH
    LEFT JOIN dbo.HOA_DON hd ON pc.MaPhien = hd.MaPhien AND hd.TrangThaiThanhToan = N'Đã thanh toán'
    WHERE 
        -- Mệnh đề WHERE: Lọc theo thời gian và hạng thành viên
        (@TuNgay IS NULL OR CAST(pc.GioBatDau AS DATE) >= @TuNgay)
        AND (@DenNgay IS NULL OR CAST(pc.GioBatDau AS DATE) <= @DenNgay)
        AND (@MaHang IS NULL OR htv.MaHang = @MaHang)
    GROUP BY 
        kh.MaKH, 
        kh.Ho, 
        kh.TenDem, 
        kh.Ten, 
        kh.GioiTinh, 
        htv.TenHang, 
        hv.DiemTichLuy
    HAVING 
        -- Mệnh đề HAVING: Lọc theo số lượt chơi và tổng chi tiêu tối thiểu
        COUNT(pc.MaPhien) >= @SoLuotChoiToiThieu
        AND ISNULL(SUM(hd.TongPhaiTra), 0.00) >= @TongChiTieuToiThieu
    ORDER BY 
        TongChiTieu DESC, 
        SoLuotChoi DESC, 
        HoTen ASC;
END;
GO
