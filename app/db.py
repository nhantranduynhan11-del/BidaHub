"""Kết nối SQL Server và gọi thủ tục, hàm. Python không tự viết INSERT, UPDATE, DELETE."""
import os
import re
from contextlib import contextmanager

import pyodbc
from dotenv import load_dotenv

import ma_loi

load_dotenv()

_TEN_HOP_LE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
# Một bản ghi lỗi trong chuỗi lỗi của pyodbc: "[SQL Server]<thông điệp> (<mã lỗi>)"
_BAN_GHI_LOI = re.compile(r"\[SQL Server\](.*?) \((\d+)\)(?: \(SQL\w+\))?(?=; \[|$)", re.S)
# Lỗi phụ đi kèm lỗi chính ("The statement has been terminated", "transaction ended in the trigger")
_LOI_PHU = {3621, 3609, 266}


class LoiNghiepVu(Exception):
    """Lỗi do CSDL báo, đã đổi thành câu thông báo tiếng Việt để hiện cho người dùng."""

    def __init__(self, thong_bao):
        super().__init__(thong_bao)
        self.thong_bao = thong_bao


def bat_loi(loi):
    """pyodbc.Error -> LoiNghiepVu.
    THROW của nhóm (mã từ 50000) giữ nguyên văn; lỗi hệ thống đổi qua ma_loi; bỏ tiền tố của driver."""
    chuoi = " ".join(str(a) for a in loi.args)
    for m in _BAN_GHI_LOI.finditer(chuoi):
        thong_diep, ma = m.group(1).strip(), int(m.group(2))
        if ma in _LOI_PHU:
            continue
        if ma >= 50000:
            return LoiNghiepVu(thong_diep)
        return LoiNghiepVu(ma_loi.dich_he_thong(ma, thong_diep))
    return LoiNghiepVu(ma_loi.dich_ket_noi(chuoi))


def _chuoi_ket_noi():
    return (
        f"DRIVER={{{os.getenv('DB_DRIVER', 'ODBC Driver 18 for SQL Server')}}};"
        f"SERVER={os.getenv('DB_SERVER', 'localhost')};"
        f"DATABASE={os.getenv('DB_NAME', 'BidaHub')};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;"
    )


@contextmanager
def _phien():
    try:
        conn = pyodbc.connect(_chuoi_ket_noi())
    except pyodbc.Error as e:
        raise bat_loi(e) from e
    try:
        yield conn
    finally:
        conn.close()


def _kiem_tra_ten(ten):
    if not _TEN_HOP_LE.match(ten):
        raise ValueError(f"Tên thủ tục hoặc hàm không hợp lệ: {ten!r}")


def goi_thu_tuc(ten, tham_so=(), ghi=False):
    """Chạy EXEC dbo.<ten> với tham số theo thứ tự; trả list[dict] của bảng kết quả đầu tiên.
    ghi=True cho thủ tục thêm/sửa/xóa: commit khi chạy xong, rollback khi lỗi."""
    _kiem_tra_ten(ten)
    tham_so = tuple(tham_so)
    dau_hoi = ", ".join("?" for _ in tham_so)
    cau_lenh = f"SET NOCOUNT ON; EXEC dbo.{ten} {dau_hoi}".rstrip()
    with _phien() as conn:
        try:
            cur = conn.cursor()
            cur.execute(cau_lenh, tham_so)
            ket_qua = None
            while True:
                if cur.description and ket_qua is None:
                    cot = [c[0] for c in cur.description]
                    ket_qua = [dict(zip(cot, dong)) for dong in cur.fetchall()]
                if not cur.nextset():   # duyệt hết để lỗi THROW ở cuối thủ tục không bị bỏ sót
                    break
            if ghi:
                conn.commit()
            return ket_qua or []
        except pyodbc.Error as e:
            conn.rollback()
            raise bat_loi(e) from e


def goi_ham(ten, *tham_so):
    """Chạy SELECT dbo.<ten>(...) và trả giá trị. Mã âm của hàm đổi thành LoiNghiepVu qua ma_loi.MA_AM."""
    _kiem_tra_ten(ten)
    dau_hoi = ", ".join("?" for _ in tham_so)
    with _phien() as conn:
        try:
            gia_tri = conn.cursor().execute(f"SELECT dbo.{ten}({dau_hoi})", tham_so).fetchval()
        except pyodbc.Error as e:
            raise bat_loi(e) from e
    if isinstance(gia_tri, int) and gia_tri < 0:
        raise LoiNghiepVu(ma_loi.dich_ma_am(ten, gia_tri))
    return gia_tri
