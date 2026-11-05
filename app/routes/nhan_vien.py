"""Trang mẫu: danh sách nhân viên có tìm kiếm, lọc, sắp xếp. Phong và Thành sao chép khuôn này."""
from flask import Blueprint, flash, render_template, request

import db

bp = Blueprint("nhan_vien", __name__, url_prefix="/nhan-vien")

CHUC_VU = ["Quản lý", "Thu ngân", "Phục vụ", "Pha chế", "Thủ kho"]   # đúng danh sách CHECK trong bảng
TINH_TRANG = ["Đang làm", "Đã nghỉ"]
COT_SAP_XEP = ("MaNV", "HoTen", "NgayVaoLam")


@bp.route("/")
def danh_sach():
    tu_khoa = request.args.get("tu_khoa", "").strip()
    chuc_vu = request.args.get("chuc_vu", "")
    tinh_trang = request.args.get("tinh_trang", "")
    sap_xep = request.args.get("sap_xep", "MaNV")
    if sap_xep not in COT_SAP_XEP:
        sap_xep = "MaNV"
    chieu = "giam" if request.args.get("chieu") == "giam" else "tang"

    ds = []
    try:
        ds = db.goi_thu_tuc("sp_DanhSachNhanVien", (
            tu_khoa or None, chuc_vu or None, tinh_trang or None,
            sap_xep, 1 if chieu == "giam" else 0))
    except db.LoiNghiepVu as e:
        flash(e.thong_bao, "danger")

    return render_template("nhan_vien/danh_sach.html", ds=ds, tu_khoa=tu_khoa, chuc_vu=chuc_vu,
                           tinh_trang=tinh_trang, sap_xep=sap_xep, chieu=chieu,
                           CHUC_VU=CHUC_VU, TINH_TRANG=TINH_TRANG)
