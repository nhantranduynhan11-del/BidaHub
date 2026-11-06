# BidaHub – BTL2 Hệ quản trị cơ sở dữ liệu

Nhóm 5 · Lớp L10 · GVHD: Dương Huỳnh Anh Đức

## 1. Công nghệ đã chốt

| | Chốt |
|---|---|
| Hệ quản trị CSDL | **MS SQL Server** |
| Ứng dụng | **Web Flask (Python) + pyodbc + Bootstrap**, gọi thẳng thủ tục và hàm, không dùng ORM |
| Quản lý mã | Git và GitHub |
| Hạn nộp | Báo cáo sơ bộ **Thứ Ba 24/11/2026** · Báo cáo cuối **Thứ Ba 8/12/2026** |

**Cài trên máy mỗi người:** SQL Server (bản Developer hoặc Express), SSMS, Python 3, ODBC Driver 18 for SQL Server, Git.

## 2. Cấu trúc repo

```
bidahub-btl2/
├── sql/
│   ├── chay_tat_ca.sql     # chạy một lần là dựng xong CSDL 
│   ├── 00_tao_csdl.sql
│   ├── 01_bang/            # tạo bảng
│   ├── 02_du_lieu/         # dữ liệu mẫu, từ 5 hàng mỗi bảng
│   ├── 03_trigger/         # trigger
│   ├── 04_thu_tuc/         # thủ tục
│   ├── 05_ham/             # hàm
│   └── 99_demo/            # kịch bản demo
├── app/
│   ├── app.py  db.py  ma_loi.py   # khung ứng dụng 
│   ├── routes/             # mỗi màn hình một file
│   └── templates/          # giao diện HTML
├── baocao/                 # báo cáo LaTeX, mỗi người một mục: nhan.tex, phong.tex, ...
├── docs/                   # chu_ky_thu_tuc.md, báo cáo BTL1, đặc tả BTL2
├── .env.example
└── requirements.txt        # flask, pyodbc, python-dotenv
```

Trong mỗi thư mục của `sql/`, mỗi người có một file mang tên mình: `nhan.sql`, `phong.sql`, `thanh.sql`, `dung.sql`, `khang.sql`. **Chỉ sửa file của mình.**

## 3. Quy ước căn bản

- **Tên:** giữ nguyên tên bảng và cột của BTL1. Thủ tục bắt đầu bằng `sp_`, hàm bằng `fn_`, trigger bằng `trg_`.
- **Tiếng Việt:** cột chữ dùng `NVARCHAR`, chuỗi luôn có tiền tố `N'...'`, file `.sql` lưu UTF-8.
- **Báo lỗi:** thủ tục và trigger dùng `THROW` với câu nói rõ lỗi gì ở trường nào. Mỗi người một dải mã lỗi: Nhân 50100–50199, Phong 50200–50299, Thành 50300–50399, Dũng 50400–50499, Khang 50500–50599. Hàm không dùng được `THROW`, nên hàm trả mã âm và ứng dụng đổi thành thông báo.
- **Viết SQL:** đầu mỗi thủ tục có `SET NOCOUNT ON`; dùng `CREATE OR ALTER` để chạy lại được. Ràng buộc kiểm tra được trong `CREATE TABLE` (CHECK, UNIQUE, NOT NULL) thì đặt ở đó, không dùng trigger.
- **Ứng dụng:** Python không tự viết `INSERT`, `UPDATE`, `DELETE`; mọi thao tác dữ liệu đi qua thủ tục hoặc hàm.
- **Hai việc về thiết kế bảng:** thêm cột lưu cho thuộc tính dẫn xuất (ví dụ `HOA_DON.TongPhaiTra`) và UNIQUE cho 4 khóa ngoại 1:1; chi tiết ở mục 2 của tài liệu phân công.

## 4. Giao việc và deadline

Theo đặc tả, **ai không tự viết ít nhất một câu ở phần 2 thì không có điểm BTL2**, và ai cũng phải giải thích được phần của người khác. Hạn riêng đều là Thứ Sáu; cuối tuần dành cho ghép và kiểm tra chéo.

### Nhân 

6 bảng: `TAI_KHOAN`, `VAI_TRO`, `DUOC_CAP`, `NHAN_VIEN`, `NV_TOAN_THOI_GIAN`, `NV_BAN_THOI_GIAN` · RB1–RB3 · Phần 2: trigger 1 (RB1) · Phần 3: khung ứng dụng

- [ ] **Thứ Sáu 6/11:** `01_bang/nhan.sql`, `00_tao_csdl.sql`, `chay_tat_ca.sql`; khung ứng dụng `app/app.py`, `app/db.py`, `app/ma_loi.py`, `app/templates/base.html`
- [ ] **Thứ Ba 10/11:** dữ liệu `02_du_lieu/nhan.sql` (nạp `TAI_KHOAN`, `NHAN_VIEN` trước Thứ Hai 9/11 vì Phong và Thành cần)
- [ ] **Thứ Sáu 13/11:** RB1–RB3 trong `03_trigger/nhan.sql`
- [ ] **Thứ Sáu 20/11:** trigger 1 (RB1) trong `03_trigger/nhan.sql`; kịch bản `99_demo/nhan.sql`
- [ ] **Thứ Sáu 27/11:** ghép menu ba màn hình, chạy thử trên máy sạch
- [ ] **Thứ Sáu 4/12:** `baocao/muc/nhan.tex`; ghép báo cáo LaTeX cuối vào 5–6/12

### Phong

4 bảng: `HANG_THANH_VIEN`, `KHACH_HANG`, `KHACH_HANG_SDT`, `HOI_VIEN` · RB15 · Phần 2: thêm/sửa/xóa `KHACH_HANG` (mục 2.1) và thủ tục tra cứu khách hàng (mục 2.3) · Phần 3: màn hình 3.1 và 3.2

- [x] **Thứ Sáu 6/11:** `01_bang/phong.sql`
- [ ] **Thứ Ba 10/11:** dữ liệu `02_du_lieu/phong.sql` (nạp `KHACH_HANG` trước vì Thành và Dũng cần)
- [ ] **Thứ Sáu 13/11:** RB15 trong `03_trigger/phong.sql`; chốt tên và tham số thủ tục, hàm của cả nhóm trong `docs/chu_ky_thu_tuc.md`
- [ ] **Thứ Sáu 20/11:** `04_thu_tuc/phong.sql` gồm `sp_ThemKhachHang`, `sp_SuaKhachHang`, `sp_XoaKhachHang`, `sp_TraCuuKhachHang`; kịch bản `99_demo/phong.sql`
- [ ] **Thứ Sáu 27/11:** `app/routes/khach_hang.py` và `app/templates/khach_hang/` (màn hình 3.1: form thêm, sửa, xóa; màn hình 3.2: danh sách có tìm kiếm, lọc, sắp xếp)
- [ ] **Thứ Sáu 4/12:** `baocao/muc/phong.tex`

### Thành

6 bảng: `KHU_VUC`, `LOAI_BAN`, `BAN`, `KHUNG_GIA`, `PHIEU_DAT_BAN`, `GIU_BAN` · RB4–RB6 · Phần 2: hàm `fn_DemBanTrong` (mục 2.4) · Phần 3: màn hình 3.3

- [ ] **Thứ Sáu 6/11:** `01_bang/thanh.sql`
- [ ] **Thứ Ba 10/11:** dữ liệu `02_du_lieu/thanh.sql` (`PHIEU_DAT_BAN` nạp sau khi Phong nạp `KHACH_HANG`)
- [ ] **Thứ Sáu 13/11:** RB4–RB6 trong `03_trigger/thanh.sql`
- [ ] **Thứ Sáu 20/11:** `05_ham/thanh.sql` (`fn_DemBanTrong`); kịch bản `99_demo/thanh.sql`
- [ ] **Thứ Sáu 27/11:** `app/routes/ban_trong.py` và `app/templates/ban_trong/` (màn hình 3.3: chọn loại bàn, giờ bắt đầu, giờ kết thúc, hiện số bàn trống)
- [ ] **Thứ Sáu 4/12:** `baocao/muc/thanh.tex`

### Dũng

5 bảng: `DANH_MUC`, `MAT_HANG`, `PHIEN_CHOI`, `DOAN_SU_DUNG_BAN`, `DONG_GOI_MON` · RB7–RB10 · Phần 2: hàm `fn_DuBaoSoNgayTonKho` (mục 2.4) · Phần 3: hỗ trợ Phong làm 3.2, gộp kịch bản demo

- [ ] **Thứ Sáu 6/11:** `01_bang/dung.sql`
- [ ] **Thứ Năm 12/11:** dữ liệu `02_du_lieu/dung.sql` (Khang cần để làm hóa đơn)
- [ ] **Thứ Sáu 13/11:** RB7–RB10 trong `03_trigger/dung.sql`
- [ ] **Thứ Sáu 20/11:** `05_ham/dung.sql` (`fn_DuBaoSoNgayTonKho`); kịch bản `99_demo/dung.sql`
- [ ] **Thứ Sáu 27/11:** hỗ trợ Phong hoàn thiện 3.2; gộp `99_demo/kich_ban_chung.sql` cho buổi báo cáo
- [ ] **Thứ Sáu 4/12:** `baocao/muc/dung.tex`

### Khang

6 bảng: `NHA_CUNG_CAP`, `PHIEU_NHAP`, `CHI_TIET_NHAP`, `KHUYEN_MAI`, `HOA_DON`, `GIAO_DICH_THANH_TOAN` · RB11–RB14 · Phần 2: trigger 2 (tính thuộc tính dẫn xuất của hóa đơn) và thủ tục thống kê doanh thu (mục 2.3) · Phần 3: màn hình thống kê (tùy chọn)

- [ ] **Thứ Sáu 6/11:** `01_bang/khang.sql`
- [ ] **Thứ Sáu 13/11:** RB11–RB14 trong `03_trigger/khang.sql`; dữ liệu `02_du_lieu/khang.sql` (nạp sau Dũng, từ 12/11; cuối tuần 14–15/11 là chỗ dự phòng)
- [ ] **Thứ Sáu 20/11:** trigger 2 trong `03_trigger/khang.sql`; `04_thu_tuc/khang.sql` (`sp_ThongKeDoanhThu`); kịch bản `99_demo/khang.sql`
- [ ] **Thứ Sáu 27/11:** `app/routes/thong_ke.py` và `app/templates/thong_ke/` (tùy chọn)
- [ ] **Thứ Sáu 4/12:** `baocao/muc/khang.tex`
