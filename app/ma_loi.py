"""Đổi mã lỗi của SQL Server thành câu thông báo tiếng Việt cho người dùng."""
import re

# 1) Mã âm do hàm trả về. Khóa ngoài là tên hàm vì mỗi hàm tự đặt nghĩa cho mã âm của nó.
#    Thành thêm fn_DemBanTrong, Dũng thêm fn_DuBaoSoNgayTonKho, đúng theo bảng mã trong docs/chu_ky_thu_tuc.md.
MA_AM = {
    # "fn_DemBanTrong": {-1: "Giờ kết thúc phải sau giờ bắt đầu", -2: "Không tìm thấy loại bàn"},
}

# 2) Vi phạm CHECK / UNIQUE / FOREIGN KEY: tra theo tên ràng buộc (hoặc tên unique index).
#    Mỗi người thêm tên ràng buộc trong file bảng của mình.
RANG_BUOC = {
    "UQ_TaiKhoan_TenDangNhap": "Tên đăng nhập đã tồn tại (không phân biệt chữ hoa, chữ thường)",
    "UQ_TaiKhoan_Email": "Email đã được dùng cho tài khoản khác",
    "CK_TaiKhoan_TenDangNhap": "Tên đăng nhập phải có ít nhất 6 ký tự và không chứa khoảng trắng",
    "CK_TaiKhoan_MatKhauBam": "Mật khẩu phải được lưu dưới dạng mã băm SHA-256 (64 ký tự hex)",
    "CK_TaiKhoan_Email": "Email không đúng định dạng (ví dụ: ten@congty.vn)",
    "UQ_NhanVien_MaTK": "Tài khoản này đã thuộc về một nhân viên khác",
    "CK_NhanVien_SoDienThoai": "Số điện thoại phải gồm 10 số và bắt đầu bằng 0",
    "CK_NhanVien_Du18Tuoi": "Nhân viên phải đủ 18 tuổi tại ngày vào làm",
    "CK_NhanVien_KhongTuGiamSat": "Nhân viên không thể tự giám sát chính mình",
}

# 3) Mã lỗi chung của hệ thống khi không biết tên ràng buộc.
MA_HE_THONG = {
    547: "Dữ liệu vi phạm ràng buộc hoặc đang được bảng khác tham chiếu",
    515: "Thiếu giá trị bắt buộc",
    2601: "Giá trị bị trùng, không được lặp lại",
    2627: "Giá trị bị trùng, không được lặp lại",
    8152: "Chuỗi nhập vào quá dài",
    245: "Giá trị nhập vào không đúng kiểu dữ liệu",
    8114: "Giá trị nhập vào không đúng kiểu dữ liệu",
}

_TEN_RANG_BUOC = re.compile(r"(?:constraint|index) [\"']([^\"']+)[\"']")


def dich_ma_am(ten_ham, ma):
    return MA_AM.get(ten_ham, {}).get(ma, f"Hàm {ten_ham} trả về mã lỗi {ma}")


def dich_he_thong(ma, thong_diep):
    m = _TEN_RANG_BUOC.search(thong_diep)
    ten = m.group(1) if m else None
    if ten in RANG_BUOC:
        return RANG_BUOC[ten]
    chung = MA_HE_THONG.get(ma)
    if chung:
        return f"{chung} ({ten})" if ten else chung
    return thong_diep


def dich_ket_noi(chuoi_loi):
    return ("Không kết nối được tới SQL Server. Hãy kiểm tra dịch vụ SQL Server đang chạy "
            f"và DB_SERVER trong file .env. Chi tiết: {chuoi_loi[:200]}")
