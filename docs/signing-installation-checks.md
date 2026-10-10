# Kiểm tra ký và cài đặt CSign

## Các lỗi đã sửa

- Cờ xoá provisioning bị đảo ở Swift; C++ lại chỉ ghi profile khi bật cờ xoá, rồi xoá profile khi tạo CodeResources. Mặc định nay giữ `embedded.mobileprovision`; chỉ loại bỏ khi người dùng yêu cầu.
- Bộ sao chép cho app lớn bỏ tệp ẩn và xử lý thủ công symlink. Dùng `FileManager.copyItem` để giữ toàn bộ bundle và tránh quét kích thước trước khi sao chép.
- Tự cài dựa vào “bản ký mới nhất” qua notification, phụ thuộc màn hình thư viện. Nay dùng đúng UUID do tác vụ ký trả về và mở đóng gói/cài đặt ngay trong cùng sheet, kể cả khi ký lại từ lịch sử.
- Lỗi lưu Core Data, tệp SSL và xuất IPA từng bị bỏ qua hoặc dùng `try!`. Nay trả lỗi và chỉ báo thành công sau khi lưu xong.
- URL manifest máy chủ ngoài không mã hoá riêng từng tham số. Nay giữ đúng tên có dấu, `&`, `+`, `#` và URL lồng nhau.
- Dò cài đặt mỗi 1 ms và coi tiến độ biến mất là thành công. Nay dò mỗi 500 ms, truyền đúng kiểu Objective-C BOOL và yêu cầu xác nhận trên màn hình chính nếu iOS không trả kết quả cuối.
- Đóng gói nay đọc trực tiếp bundle vào `Payload/` bằng minizip đã có sẵn, không sao chép thêm cả app sang thư mục staging. Đọc theo khối 256 KiB; giữ quyền thực thi và symlink; kiểm tra lỗi ghi và xoá archive dở dang. Cài đặt dùng ZIP không nén, xuất IPA giữ mức nén người dùng chọn.
- Cài qua pairing từng đọc toàn bộ IPA vào RAM và giữ con trỏ ngoài `withUnsafeBytes`. Nay gửi từng khối 1 MiB trong phạm vi con trỏ hợp lệ.
- Thiếu delegate để hiện thông báo khi app đang mở. Nay hiện banner cho kết quả ký và trạng thái cài đặt; nhập IPA được ghi đúng là nhập vào thư viện.

Màn hình log được thay bằng sheet trạng thái gọn. Giao diện dùng cyan/hồng theo icon và linh vật vector; không thêm GIF, bộ giải mã ảnh động hay thư viện đồ hoạ. Hoạt ảnh có công tắc trong Giao diện và tự tắt với Reduce Motion, Low Power Mode hoặc khi app vào nền.

## Kiểm tra tự động

```sh
python3 -m unittest discover -s Tests -p 'test_*.py' -v
```

Kiểm tra chạy bộ ký C++ thực với chứng chỉ thử được tạo tạm và Mach-O fixture: giữ profile cùng hash resource, xoá profile khi chọn xoá, và từ chối mật khẩu sai. Chứng chỉ thử không phải chứng chỉ Apple và không được dùng để cài lên iPhone.

GitHub Actions kiểm tra archive thực (CRC, cấu trúc Payload, tệp ẩn, quyền thực thi, symlink, tên có dấu, mức nén và giữ nguyên bản gốc) bằng `python3 Tests/archive_regressions.py`.

GitHub Actions còn biên dịch/chạy kiểm tra Swift cho mã hoá URL, tiến độ thiếu/timeout, huỷ an toàn và ngăn hai tác vụ ký đồng thời; sau đó build IPA Release trên macOS.

## Kiểm tra trên iPhone

1. Nhập chứng chỉ Apple còn hiệu lực với profile phù hợp thiết bị; ký IPA ở mặc định và xác nhận hộp thoại cài đặt.
2. Ký lại từ Lịch sử; xác nhận bản vừa ký được cài đúng, kể cả khi nhiều bản có cùng tên.
3. Tắt tự cài; xác nhận có nút Cài đặt/Xuất IPA. Huỷ khi đang sao chép hoặc ký; đợi tác vụ dừng rồi thử lại.
4. Thử IPA lớn, tên có ký tự đặc biệt, chế độ máy chủ HTTPS/máy chủ ngoài và pairing. Kiểm tra thông báo khi đang mở app và khi app ở nền.
5. Thử Light/Dark, Reduce Motion và Low Power Mode. Với OTA, “đã gửi IPA” chưa phải bằng chứng cài thành công: kiểm tra kết quả trên màn hình chính nếu iOS không trả tiến độ cuối.

Build và kiểm tra tự động không xác minh việc Apple chấp nhận chứng chỉ, chứng chỉ bị thu hồi, quyền entitlements hay khả năng cài trên mọi phiên bản iOS.
