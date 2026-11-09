"""Khung ứng dụng BidaHub (Nhân). Mỗi người thêm blueprint của mình ở mục "Đăng ký blueprint"."""
import os

from dotenv import load_dotenv
from flask import Flask, render_template, request, url_for

import db
from routes.nhan_vien import bp as bp_nhan_vien

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "bidahub-chi-dung-khi-phat-trien")

# ---- Đăng ký blueprint: bỏ dấu # ở dòng của mình khi file route đã có ----
app.register_blueprint(bp_nhan_vien)
# from routes.khach_hang import bp as bp_khach_hang; app.register_blueprint(bp_khach_hang)  # Phong
# from routes.ban_trong import bp as bp_ban_trong; app.register_blueprint(bp_ban_trong)     # Thành
# from routes.thong_ke import bp as bp_thong_ke; app.register_blueprint(bp_thong_ke)        # Khang

# ---- Menu: (tên endpoint, nhãn). Endpoint nào chưa đăng ký thì tự ẩn ----
MENU = [
    ("nhan_vien.danh_sach", "Nhân viên"),
    ("khach_hang.danh_sach", "Khách hàng"),   # Phong: màn hình 3.1 và 3.2
    ("ban_trong.kiem_tra", "Bàn trống"),      # Thành: màn hình 3.3
    ("thong_ke.doanh_thu", "Doanh thu"),      # Khang: tùy chọn
]


@app.context_processor
def them_menu():
    muc = [(url_for(ep), nhan, ep.split(".")[0] == request.blueprint)
           for ep, nhan in MENU if ep in app.view_functions]
    return {"menu": muc}


@app.route("/")
def trang_chu():
    """Trang chủ kiêm kiểm tra kết nối: gọi một thủ tục thử và báo kết quả."""
    try:
        so_nhan_vien = len(db.goi_thu_tuc("sp_DanhSachNhanVien"))
        loi = None
    except db.LoiNghiepVu as e:
        so_nhan_vien, loi = None, e.thong_bao
    return render_template("trang_chu.html", so_nhan_vien=so_nhan_vien, loi=loi)


@app.errorhandler(db.LoiNghiepVu)
def xu_ly_loi_nghiep_vu(e):
    """Lỗi CSDL mà route không tự bắt: hiện nguyên văn câu thông báo."""
    return render_template("loi.html", thong_bao=e.thong_bao), 400
