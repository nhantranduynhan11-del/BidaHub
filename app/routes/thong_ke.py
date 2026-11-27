"""Thống kê doanh thu BidaHub - sử dụng procedure sp_ThongKeDoanhThu."""
from datetime import date
from decimal import Decimal, InvalidOperation

from flask import Blueprint, flash, render_template, request

import db

bp = Blueprint("thong_ke", __name__, url_prefix="/thong-ke")


@bp.route("/", methods=["GET"])
def doanh_thu():
    tu_ngay = request.args.get("tu_ngay", "").strip()
    den_ngay = request.args.get("den_ngay", "").strip()
    doanh_thu_toi_thieu = request.args.get("doanh_thu_toi_thieu", "0").strip()

    ds = []
    da_tim = False
    tong_doanh_thu = Decimal("0")
    tong_giao_dich = 0
    # Tránh gọi procedure ngay khi lần đầu mở trang.
    if "tu_ngay" in request.args or "den_ngay" in request.args:
        try:
            ngay_tu = date.fromisoformat(tu_ngay)
            ngay_den = date.fromisoformat(den_ngay)
            muc_toi_thieu = Decimal(doanh_thu_toi_thieu)
            if (ngay_tu > ngay_den or ngay_den == date.max
                    or not muc_toi_thieu.is_finite()
                    or muc_toi_thieu < 0
                    or muc_toi_thieu > Decimal("9999999999999999.99")
                    or muc_toi_thieu.as_tuple().exponent < -2):
                raise ValueError("Giá trị thống kê không hợp lệ")
        except (ValueError, InvalidOperation, TypeError):
            flash("Vui lòng nhập ngày hợp lệ, từ ngày không lớn hơn đến ngày, và doanh thu tối thiểu không âm (tối đa 2 chữ số thập phân).", "danger")
        else:
            try:
                ds = db.goi_thu_tuc(
                    "sp_ThongKeDoanhThu",
                    (ngay_tu, ngay_den, muc_toi_thieu),
                )
                da_tim = True
                tong_doanh_thu = sum(
                    (dong["TongDoanhThu"] for dong in ds), Decimal("0")
                )
                tong_giao_dich = sum(dong["SoGiaoDichThanhCong"] for dong in ds)
            except db.LoiNghiepVu as e:
                flash(e.thong_bao, "danger")

    return render_template(
        "thong_ke/doanh_thu.html",
        ds=ds,
        da_tim=da_tim,
        tu_ngay=tu_ngay,
        den_ngay=den_ngay,
        doanh_thu_toi_thieu=doanh_thu_toi_thieu,
        tong_doanh_thu=tong_doanh_thu,
        tong_giao_dich=tong_giao_dich,
    )
