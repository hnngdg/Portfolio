use QLBH_1004_TEST;

--SCALAR FUNCTION
--Tạo hàm hiển thị thứ trong tuần tương ứng với ngày khai báo

create function fn_weekday
(
	@Date datetime
)
returns nvarchar(25)
as
begin
	declare @ketqua nvarchar(25)
	set @ketqua = datename(weekday, @Date)
	return @ketqua
end;

select dbo.fn_weekday ('2022-06-16') as Weekday;


--Tạo hàm xác định tuổi khách hàng tại ngày đăng ký [NGDK]

create function fn_TuoiKH
(
	@Ngaysinh datetime
	, @NgayDK datetime
)
returns int
as
begin
	declare @ketqua int
	set @ketqua = datediff(year, @Ngaysinh, @NgayDK)
	return @ketqua
end;


select 
	*
	, dbo.fn_TuoiKH (NGSINH, NGDK) as TuoiKH
from KHACHHANG;


--Yêu cầu: Sử dụng 02 hàm vừa viết ra để viết query hiển thị MAKH, TUOI (tại ngày đăng ký) và Birth_Weekday của KH

select
	MAKH
	, dbo.fn_TuoiKH (NGSINH, NGDK) as TuoiKH
	, dbo.fn_weekday (NGSINH) as Birth_Weekday
from KHACHHANG;



--TABLE FUNCTION
--Yêu cầu: Tìm thông tin khách hàng mua nhiều sp nhất tại ngày yyyy/mm/dd (biến đầu vào)

Create function fn_KHmuanhieuSPnhat
(
	@NgayMuaHang datetime
)
returns table
as
return
(
	WITH bangtam as
	(
	select TOP 1
		a.NGHD
		, a.MAKH
		, sum(b.SL) as TongSoSP
	from HOADON as a
	inner join CTHD as b
		on a.SOHD = b.SOHD
	where a.NGHD = @NgayMuaHang
	group by a.NGHD, a.MAKH
	order by TongSoSP desc
	)
	select 
		bangtam.MAKH
		, bangtam.TongSoSP
		, bangtam.NGHD
		, KHACHHANG.HOTEN
		, KHACHHANG.NGSINH
		, KHACHHANG.NGDK
		, KHACHHANG.DOANHSO
		, KHACHHANG.SODT
		, KHACHHANG.DCHI
	from bangtam
	inner join KHACHHANG
		on bangtam.MAKH = KHACHHANG.MAKH
)

SELECT * FROM fn_KHmuanhieuSPnhat('2006-08-23')


--STORED PROCEDURE
--Yêu cầu: Tạo Stored Procedure tính hoa hồng cho nhân viên theo ngày nhập vào, biết Commision Rate như sau:
	--Bán sản phẩm có nước sản xuất là Việt Nam: Commision Rate = 10%
	--Bán sản phẩm có nước sản xuất là Trung Quốc: Commision Rate = 12%
	--Bán sản phẩm từ các nước sản xuất khác: Commision Rate = 8%

create table QLBH_1004_TEST..COMMISION_PER_STAFF_MONTH
(
	MONTH_NC varchar(10),
	STAFF_CODE nvarchar(25),
	STAFF_NAME nvarchar(50),
	COMMISION float
);

create table BT_3_1
(
	MaNV nvarchar(25),
	Date_HD Date,
	COMMISION float
);

create procedure storepro_TinhHoaHong
@END_MONTH_DATE Date
as
begin

	truncate table BT_3_1
	print N'Đã hoàn thành xóa dữ liệu BT_3_1'

	insert into BT_3_1
	select 
		MANV
		,NGHD
		, 'COMMISION'=
			case 
			when NuocSX='Viet Nam' then Round(convert(float,Gia) * SL * 0.1 , 1)
			when NuocSX='Trung Quoc' then Round(convert(float,Gia) * SL * 0.12 , 1)
			else Round(convert(float,Gia) * SL * 0.08 , 1)
			end
	from HOADON
	left join CTHD 
		on CTHD.SOHD=HOADON.SOHD
	left join SANPHAM 
		on SANPHAM.MASP=CTHD.MASP
	where DATEDIFF(Month,NGHD,@END_MONTH_DATE) = 0
	print N'Thêm dữ liệu thành công vào bảng BT_3_1'

	truncate table QLBH_1004_TEST..COMMISION_PER_STAFF_MONTH
	print N'Đã hoàn thành xóa dữ liệu ở bảng COMMISION_PER_STAFF_MONTH'

	insert into QLBH_1004_TEST..COMMISION_PER_STAFF_MONTH
		(STAFF_CODE,MONTH_NC,COMMISION)
	select 
		MaNV
		,@END_MONTH_DATE
		,sum(COMMISION) 
	from BT_3_1
	group by MaNV
	print N'Đã hoàn thành thêm dữ liệu vào COMMISION_PER_STAFF_MONTH'

	update QLBH_1004_TEST..COMMISION_PER_STAFF_MONTH 
		set STAFF_NAME = HoTen
		from NHANVIEN
		where STAFF_CODE = NHANVIEN.MANV
end;

exec storepro_TinhHoaHong '2006-12-31';

select * 
from COMMISION_PER_STAFF_MONTH;



--CURSOR
--Yêu cầu: Kiểm tra trong bảng SANPHAM xem có sản phẩm nào nước sản xuất là 'USA' hay không: 
	--Nếu có trả về dòng: 'trong bảng này có sản phẩm sản xuất tại USA', nếu ko trả ra dòng: 'trong bảng này không có sản phẩm sản xuất tại USA'

declare cursorNuocSX cursor for
select
	nuocsx
from SANPHAM

open cursorNuocSX

	declare @flat bit
		set @flat = 0
	declare @NuocSX nvarchar(max)

	fetch next from cursorNuocSX into @NuocSX

	while @@FETCH_STATUS = 0
	begin
		if (@NuocSX = 'USA')
		begin
			set @flat = 1
			break   --khi đã tìm thấy có sản phẩm sản xuất tại USA thì trả kết quả là có, không cần dò thêm các dòng khác
		end
		
		fetch next from cursorNuocSX into @NuocSX
	end
	if @flat = 1
		print N'trong bảng này có sản phẩm sản xuất tại USA'
	else
		print N'trong bảng này không có sản phẩm sản xuất tại USA'

close cursorNuocSX
deallocate cursorNuocSX;