### 3.1. Danh mục mã lỗi phụ trách (Dải 50400 – 50499)
- `50401` (RB10): Chỉ được gọi mặt hàng đang bán.
- `50402` (RB10): Chỉ được ghi dòng gọi món trong phiên đang chơi.
- `50403` (RB10): Đơn giá tại thời điểm gọi phải bằng đơn giá niêm yết của mặt hàng.
- `50404` (RB10): Dòng gọi món mới không được ở trạng thái 'Đã hủy'.
- `50405` (RB10): Không được xóa dòng gọi món, chỉ được hủy khi còn chờ chế biến.
- `50406` (RB10): Dòng gọi món đã ghi chỉ được đổi trạng thái phục vụ và ghi chú.
- `50407` (RB10): Chỉ được chuyển dòng đang chờ chế biến sang 'Đã phục vụ' hoặc 'Đã hủy'.
- `50408` (RB10): Số lượng tồn của mặt hàng không đủ cho dòng gọi món.
- `50471` (RB7): Không được mở đoạn sử dụng trên bàn đang bảo trì hoặc ngưng sử dụng.
- `50472` (RB7): Đoạn sử dụng bàn phải nằm trong khoảng thời gian của phiên.
- `50473` (RB7): Các đoạn sử dụng bàn của cùng một phiên không được chồng lấn.
- `50474` (RB7): Bàn đã thuộc một đoạn sử dụng khác trong khoảng thời gian này.
- `50475` (RB7): Sửa giờ của phiên làm đoạn sử dụng bàn nằm ngoài khoảng thời gian của phiên.
- `50481` (RB8): Khung giá của đoạn phải thuộc đúng loại bàn của bàn được sử dụng.
- `50482` (RB8): Khung giá phải chứa thời điểm bắt đầu đoạn và đúng loại ngày áp dụng (ngày lễ không kiểm tra vì CSDL không có lịch lễ).
- `50483` (RB8): Đoạn không được đi qua thời điểm đổi khung giá.
- `50484` (RB8): Đơn giá áp dụng phải bằng đơn giá mỗi giờ của khung giá.
- `50485` (RB8): Đoạn đã ghi chỉ được cập nhật giờ kết thúc, đơn giá áp dụng đã được chốt.
- `50486` (RB8): Phiên kết thúc phải có ít nhất một đoạn và mọi đoạn sử dụng bàn đã đóng.
- `50487` (RB8): Các đoạn sử dụng bàn phải phủ kín toàn bộ thời gian của phiên.
- `50491` (RB2): Nhân viên đã nghỉ việc hoặc tài khoản bị khóa không được mở phiên chơi.
- `50492` (RB2): Nhân viên đã nghỉ việc hoặc tài khoản bị khóa không được ghi dòng gọi món.

---

### 3.2. Chữ ký Hàm Người Dùng UDF có con trỏ CURSOR (Câu 2.4)

#### `fn_DuBaoSoNgayTonKho`
Dự báo số ngày còn bán được của một mặt hàng = số lượng tồn / lượng bán trung bình mỗi ngày. Lượng bán lấy từ `DONG_GOI_MON` (bỏ dòng 'Đã hủy') trong `@SoNgayXet` ngày kết thúc tại `@NgayThamChieu`, con trỏ duyệt tổng số lượng bán theo từng ngày.
```sql
CREATE OR ALTER FUNCTION dbo.fn_DuBaoSoNgayTonKho (
    @MaMatHang      INT,
    @SoNgayXet      INT,   -- từ 1 đến 365, gợi ý 7
    @NgayThamChieu  DATE   -- NULL: lấy ngày gọi món mới nhất trong CSDL
)
RETURNS DECIMAL(18,1)
```
- **Giá trị trả về:** số ngày dự báo (làm tròn 1 chữ số thập phân), `0` khi mặt hàng đã hết.
- **Mã âm (hàm không dùng được `THROW`, ứng dụng đổi thành thông báo trong `app/ma_loi.py`):**
  - `-1`: Mã mặt hàng NULL hoặc không tồn tại.
  - `-2`: Số ngày xét NULL hoặc ngoài khoảng 1 đến 365.
  - `-3`: Mặt hàng đã ngừng bán.
  - `-4`: Không có dòng gọi món nào trong kỳ xét nên không dự báo được.
- **Lưu ý khi gọi:** hàm UDF phải truyền đủ 3 tham số, bỏ qua tham số thì ghi `DEFAULT`.

---

### 3.3. Danh mục Triggers Phụ Trách (Ràng buộc ngữ nghĩa RB2, RB7, RB8, RB9, RB10)
RB2 (phần mở phiên, ghi gọi món) dùng hàm dùng chung `dbo.fn_NhanVienDangHoatDong` của Nhân, nên `03_trigger/nhan.sql` phải chạy trước `03_trigger/dung.sql`. RB9 không cần trigger vì tiền giờ là cột tính toán `DOAN_SU_DUNG_BAN.TienGio`.

- `UQ_DoanSuDungBan_BanDangDung` (unique index có lọc trên `DOAN_SU_DUNG_BAN(MaBan) WHERE GioKetThucDung IS NULL`, RB7):
  Mỗi bàn chỉ có tối đa một đoạn đang diễn ra. Vi phạm báo lỗi hệ thống 2601, không phải `THROW`.
- `trg_RB7_KiemTraDoanSuDungBan` (ON `dbo.DOAN_SU_DUNG_BAN`, AFTER INSERT, UPDATE): lỗi 50471 – 50474.
- `trg_RB7_CapNhatTrangThaiBan` (ON `dbo.DOAN_SU_DUNG_BAN`, AFTER INSERT, UPDATE, DELETE):
  Tự cập nhật `BAN.TrangThai` thành 'Đang chơi', 'Đã đặt' hoặc 'Trống'; không đổi bàn đang bảo trì hoặc ngưng sử dụng.
- `trg_RB7_KiemTraThoiGianPhien` (ON `dbo.PHIEN_CHOI`, AFTER UPDATE): lỗi 50475.
- `trg_RB8_KiemTraKhungGia` (ON `dbo.DOAN_SU_DUNG_BAN`, AFTER INSERT, UPDATE): lỗi 50481 – 50483.
- `trg_RB8_ChotDonGiaDoan` (ON `dbo.DOAN_SU_DUNG_BAN`, AFTER INSERT, UPDATE): lỗi 50484, 50485.
- `trg_RB8_KiemTraPhuKinPhien` (ON `dbo.PHIEN_CHOI`, AFTER INSERT, UPDATE): lỗi 50486, 50487.
- `trg_RB8_PhuKinKhiSuaDoan` (ON `dbo.DOAN_SU_DUNG_BAN`, AFTER INSERT, UPDATE, DELETE): lỗi 50486, 50487.
- `trg_RB10_KiemTraGoiMon` (ON `dbo.DONG_GOI_MON`, AFTER INSERT): lỗi 50401 – 50404.
- `trg_RB10_KhoaDongGoiMon` (ON `dbo.DONG_GOI_MON`, AFTER UPDATE, DELETE): lỗi 50405 – 50407.
- `trg_RB10_CapNhatTonKho` (ON `dbo.DONG_GOI_MON`, AFTER INSERT, UPDATE):
  Gọi món thì trừ `SoLuongTon`, hủy dòng đang chờ chế biến thì hoàn lại; lỗi 50408.
- `trg_RB2_KiemTraNhanVienMoPhien` (ON `dbo.PHIEN_CHOI`, AFTER INSERT, UPDATE): lỗi 50491.
- `trg_RB2_KiemTraNhanVienGhiMon` (ON `dbo.DONG_GOI_MON`, AFTER INSERT): lỗi 50492.
