"""Quản lý khách hàng (Phong): màn hình 3.2 (danh sách, tìm kiếm, lọc, sắp xếp) và 3.1 (thêm, sửa, xóa)."""
from datetime import date
import re

from flask import Blueprint, flash, redirect, render_template, request, url_for

import db

bp = Blueprint("khach_hang", __name__, url_prefix="/khach-hang")

GIOI_TINH = ["Nam", "Nữ", "Khác"]
LOAI_KHACH = [
    ("HoiVien", "Hội viên"),
    ("VangLai", "Khách vãng lai"),
]
HANG_THANH_VIEN = [
    (1, "Đồng"),
    (2, "Bạc"),
    (3, "Vàng"),
    (4, "Bạch Kim"),
    (5, "Kim Cương"),
]
COT_SAP_XEP = ("MaKH", "Ten", "DiemTichLuy", "NgaySinh")
_MAU_SDT = re.compile(r"^0\d{9}$")


def _kiem_tra_form(form):
    """Kiểm tra dữ liệu nhập trên form trước khi gọi thủ tục CSDL."""
    ho = form.get("ho", "").strip()
    ten_dem = form.get("ten_dem", "").strip()
    ten = form.get("ten", "").strip()
    ngay_sinh_str = form.get("ngay_sinh", "").strip()
    gioi_tinh = form.get("gioi_tinh", "").strip()
    so_dien_thoai = form.get("so_dien_thoai", "").strip()

    loi = []
    if not ho:
        loi.append("Vui lòng nhập họ của khách hàng.")
    elif len(ho) > 30:
        loi.append("Họ của khách hàng không được vượt quá 30 ký tự.")

    if len(ten_dem) > 30:
        loi.append("Tên đệm không được vượt quá 30 ký tự.")

    if not ten:
        loi.append("Vui lòng nhập tên của khách hàng.")
    elif len(ten) > 30:
        loi.append("Tên của khách hàng không được vượt quá 30 ký tự.")

    if gioi_tinh and gioi_tinh not in GIOI_TINH:
        loi.append("Giới tính không hợp lệ (chỉ chọn Nam, Nữ hoặc Khác).")

    ngay_sinh = None
    if ngay_sinh_str:
        try:
            ngay_sinh = date.fromisoformat(ngay_sinh_str)
            hom_nay = date.today()
            if ngay_sinh > hom_nay:
                loi.append("Ngày sinh không được lớn hơn ngày hiện tại.")
            elif hom_nay.year - ngay_sinh.year > 120:
                loi.append("Tuổi khách hàng không hợp lệ (vượt quá 120 tuổi).")
        except ValueError:
            loi.append("Ngày sinh không đúng định dạng YYYY-MM-DD.")

    if so_dien_thoai and not _MAU_SDT.match(so_dien_thoai):
        loi.append("Số điện thoại phải gồm đúng 10 chữ số và bắt đầu bằng số 0.")

    du_lieu = {
        "ho": ho,
        "ten_dem": ten_dem or None,
        "ten": ten,
        "ngay_sinh": ngay_sinh_str or None,
        "gioi_tinh": gioi_tinh or None,
        "so_dien_thoai": so_dien_thoai or None,
    }
    return du_lieu, loi


def _lay_khach_hang(ma_kh):
    """Lấy thông tin một khách hàng theo MaKH thông qua thủ tục sp_TraCuuKhachHang."""
    ds = db.goi_thu_tuc("sp_TraCuuKhachHang", (None, None, None, None, "MaKH", "ASC"))
    for dong in ds:
        if dong.get("MaKH") == ma_kh:
            return dong
    return None


@bp.route("/")
def danh_sach():
    """Màn hình 3.2: Danh sách khách hàng có tìm kiếm, lọc và sắp xếp."""
    tu_khoa = request.args.get("tu_khoa", "").strip()
    gioi_tinh = request.args.get("gioi_tinh", "").strip()
    if gioi_tinh not in GIOI_TINH:
        gioi_tinh = ""

    loai_khach = request.args.get("loai_khach", "").strip()
    if loai_khach not in {ma for ma, _ in LOAI_KHACH}:
        loai_khach = ""

    ma_hang_str = request.args.get("ma_hang", "").strip()
    ma_hang = int(ma_hang_str) if ma_hang_str.isdigit() else None
    if ma_hang not in {ma for ma, _ in HANG_THANH_VIEN}:
        ma_hang = None

    sap_xep = request.args.get("sap_xep", "MaKH")
    if sap_xep not in COT_SAP_XEP:
        sap_xep = "MaKH"
    chieu = "giam" if request.args.get("chieu") == "giam" else "tang"

    ds = []
    try:
        ds = db.goi_thu_tuc("sp_TraCuuKhachHang", (
            tu_khoa or None,
            gioi_tinh or None,
            loai_khach or None,
            ma_hang,
            sap_xep,
            "DESC" if chieu == "giam" else "ASC",
        ))
    except db.LoiNghiepVu as e:
        flash(e.thong_bao, "danger")

    return render_template(
        "khach_hang/danh_sach.html",
        ds=ds,
        tu_khoa=tu_khoa,
        gioi_tinh=gioi_tinh,
        loai_khach=loai_khach,
        ma_hang=ma_hang or "",
        sap_xep=sap_xep,
        chieu=chieu,
        GIOI_TINH=GIOI_TINH,
        LOAI_KHACH=LOAI_KHACH,
        HANG_THANH_VIEN=HANG_THANH_VIEN,
    )


@bp.route("/them", methods=["GET", "POST"])
def them():
    """Màn hình 3.1: Thêm mới khách hàng qua sp_ThemKhachHang."""
    if request.method == "POST":
        dl, ds_loi = _kiem_tra_form(request.form)
        if ds_loi:
            for cau_loi in ds_loi:
                flash(cau_loi, "warning")
            return render_template(
                "khach_hang/form.html",
                che_do="them",
                du_lieu=request.form,
                GIOI_TINH=GIOI_TINH,
            )

        try:
            ket_qua = db.goi_thu_tuc(
                "sp_ThemKhachHang",
                (dl["ho"], dl["ten_dem"], dl["ten"], dl["ngay_sinh"], dl["gioi_tinh"], dl["so_dien_thoai"]),
                ghi=True,
            )
            ma_moi = ket_qua[0]["MaKH"] if ket_qua and "MaKH" in ket_qua[0] else ""
            nhan_ma = f" (mã #{ma_moi})" if ma_moi != "" else ""
            flash(f"Đã thêm khách hàng mới thành công{nhan_ma}.", "success")
            return redirect(url_for("khach_hang.danh_sach"))
        except db.LoiNghiepVu as e:
            flash(e.thong_bao, "danger")
            return render_template(
                "khach_hang/form.html",
                che_do="them",
                du_lieu=request.form,
                GIOI_TINH=GIOI_TINH,
            )

    return render_template(
        "khach_hang/form.html",
        che_do="them",
        du_lieu={},
        GIOI_TINH=GIOI_TINH,
    )


@bp.route("/sua/<int:ma_kh>", methods=["GET", "POST"])
def sua(ma_kh):
    """Màn hình 3.1: Cập nhật khách hàng qua sp_SuaKhachHang."""
    try:
        thong_tin_goc = _lay_khach_hang(ma_kh)
    except db.LoiNghiepVu as e:
        flash(e.thong_bao, "danger")
        return redirect(url_for("khach_hang.danh_sach"))

    if not thong_tin_goc:
        flash(f"Không tìm thấy khách hàng mã #{ma_kh}.", "warning")
        return redirect(url_for("khach_hang.danh_sach"))

    if request.method == "POST":
        dl, ds_loi = _kiem_tra_form(request.form)
        if ds_loi:
            for cau_loi in ds_loi:
                flash(cau_loi, "warning")
            return render_template(
                "khach_hang/form.html",
                che_do="sua",
                ma_kh=ma_kh,
                du_lieu=request.form,
                thong_tin_goc=thong_tin_goc,
                GIOI_TINH=GIOI_TINH,
            )

        try:
            db.goi_thu_tuc(
                "sp_SuaKhachHang",
                (ma_kh, dl["ho"], dl["ten_dem"], dl["ten"], dl["ngay_sinh"], dl["gioi_tinh"], dl["so_dien_thoai"]),
                ghi=True,
            )
            flash(f"Đã cập nhật thông tin khách hàng #{ma_kh}.", "success")
            return redirect(url_for("khach_hang.danh_sach"))
        except db.LoiNghiepVu as e:
            flash(e.thong_bao, "danger")
            return render_template(
                "khach_hang/form.html",
                che_do="sua",
                ma_kh=ma_kh,
                du_lieu=request.form,
                thong_tin_goc=thong_tin_goc,
                GIOI_TINH=GIOI_TINH,
            )

    ngay_sinh_val = ""
    if thong_tin_goc.get("NgaySinh"):
        ns = thong_tin_goc["NgaySinh"]
        ngay_sinh_val = ns.strftime("%Y-%m-%d") if hasattr(ns, "strftime") else str(ns)[:10]

    sdt_chinh = thong_tin_goc.get("SoDienThoaiChinh") or ""
    if not sdt_chinh and thong_tin_goc.get("SoDienThoai") and thong_tin_goc["SoDienThoai"] != "Chưa có":
        sdt_chinh = thong_tin_goc["SoDienThoai"].split(",")[0].strip()

    du_lieu = {
        "ho": thong_tin_goc.get("Ho") or "",
        "ten_dem": thong_tin_goc.get("TenDem") or "",
        "ten": thong_tin_goc.get("Ten") or "",
        "ngay_sinh": ngay_sinh_val,
        "gioi_tinh": thong_tin_goc.get("GioiTinh") or "",
        "so_dien_thoai": sdt_chinh,
    }
    return render_template(
        "khach_hang/form.html",
        che_do="sua",
        ma_kh=ma_kh,
        du_lieu=du_lieu,
        thong_tin_goc=thong_tin_goc,
        GIOI_TINH=GIOI_TINH,
    )


@bp.route("/xoa/<int:ma_kh>", methods=["POST"])
def xoa(ma_kh):
    """Màn hình 3.1: Xóa khách hàng qua sp_XoaKhachHang."""
    try:
        db.goi_thu_tuc("sp_XoaKhachHang", (ma_kh,), ghi=True)
        flash(f"Đã xóa khách hàng #{ma_kh} thành công.", "success")
    except db.LoiNghiepVu as e:
        flash(e.thong_bao, "danger")
    return redirect(url_for("khach_hang.danh_sach"))
