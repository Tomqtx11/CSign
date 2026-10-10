# Kiểm tra ký và cài đặt CSign

## Các lỗi đã sửa

- Cờ xoá provisioning bị đảo ở Swift; C++ lại chỉ ghi profile khi bật cờ xoá, rồi xoá profile khi tạo CodeResources. Mặc định nay giữ `embedded.mobileprovision`; chỉ loại bỏ khi người dùng yêu cầu.
- Bộ sao chép cho app lớn bỏ tệp ẩn và xử lý thủ công symlink. Dùng `FileManager.copyItem` để giữ toàn bộ bundle và tránh quét kích thước trước khi sao chép.
- Tự cài dựa vào “bản ký mới nhất” qua notification, phụ thuộc màn hình thư viện. Nay dùng đúng UUID do tác vụ ký trả về và mở đóng gói/cài đặt ngay trong cùng sheet, kể cả khi ký lại từ lịch sử.
- Lỗi lưu Core Data, tệp SSL và xuất IPA từng bị bỏ qua hoặc dùng `try!`. Nay trả lỗi và chỉ báo thành công sau khi lưu xong.
- URL manifest máy chủ ngoài không mã hoá riêng từng tham số. Nay giữ đúng tên có dấu, `&`, `+`, `#` và URL lồng nhau.
- Liên kết iOS từng tạo thành `itms-services:?…`; nay giữ đúng `itms-services://?action=download-manifest&url=…` theo [tài liệu Apple](https://support.apple.com/guide/deployment/depce7cefc4d/web), có regression kiểm tra cả dấu `//`.
- Máy chủ manifest nội suy giá trị query trực tiếp vào XML. Kiểm tra endpoint thực cho thấy tên chứa `&` tạo plist lỗi; nay escape XML trước khi mã hoá query, giữ đúng tên và URL tải khi iOS đọc plist.
- Trang Safari mở qua `http://127.0.0.1:<port>/install`, không phụ thuộc IP Wi-Fi/4G. Safari được present bằng UIKit sau khi presenter xuất hiện, thay vì nhúng controller Safari vào hierarchy SwiftUI theo [hướng dẫn Apple](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller). Sau khi trang tải xong, tự gọi trình cài một lần; nút Cài đặt vẫn hiện nếu iOS chặn chuyển hướng tự động. Delegate nhận kết quả tải; nếu thất bại hoặc chờ 15 giây chưa tải được thì hiện lỗi và nút Thử lại Safari, dùng lại IPA đã đóng gói.
- Khi mở trực tiếp bị từ chối, không có yêu cầu manifest sau 8 giây hoặc khởi động HTTPS thất bại, chuyển sang máy chủ HTTP/Safari và manifest HTTPS qua `api.palera.in`. Cần Internet cho manifest máy chủ ngoài. Không dừng máy chủ chỉ vì màn cài đặt bị Safari che; chỉ dọn khi đóng sheet cài.
- Dò cài đặt mỗi 1 ms và coi tiến độ biến mất là thành công. Nay dò mỗi 500 ms, truyền đúng kiểu Objective-C BOOL và yêu cầu xác nhận trên màn hình chính nếu iOS không trả kết quả cuối.
- Đóng gói nay đọc trực tiếp bundle vào `Payload/` bằng minizip đã có sẵn, không sao chép thêm cả app sang thư mục staging. Đọc theo khối 256 KiB; giữ quyền thực thi và symlink; kiểm tra lỗi ghi và xoá archive dở dang. Cài đặt dùng ZIP không nén, xuất IPA giữ mức nén người dùng chọn.
- Cài qua pairing từng đọc toàn bộ IPA vào RAM và giữ con trỏ ngoài `withUnsafeBytes`. Nay gửi từng khối 1 MiB trong phạm vi con trỏ hợp lệ.
- Thiếu delegate để hiện thông báo khi app đang mở. Nay hiện banner cho kết quả ký và trạng thái cài đặt; nhập IPA được ghi đúng là nhập vào thư viện.

Màn hình log được thay bằng sheet trạng thái gọn. Bỏ khung khẩu hiệu CSign; viền bo cyan/hồng nằm trên từng ô ứng dụng trong Thư viện và Lịch sử. Linh vật vector chỉ ở sheet tiến độ; không thêm GIF, bộ giải mã ảnh động hay thư viện đồ hoạ. Hoạt ảnh có công tắc trong Giao diện và tự tắt với Reduce Motion, Low Power Mode hoặc khi app vào nền.

## Kiểm tra tự động

```sh
python3 -m unittest discover -s Tests -p 'test_*.py' -v
```

Kiểm tra chạy bộ ký C++ thực với chứng chỉ thử được tạo tạm và Mach-O fixture: giữ profile cùng hash resource, xoá profile khi chọn xoá, và từ chối mật khẩu sai. Chứng chỉ thử không phải chứng chỉ Apple và không được dùng để cài lên iPhone.

GitHub Actions kiểm tra archive thực (CRC, cấu trúc Payload, tệp ẩn, quyền thực thi, symlink, tên có dấu, mức nén và giữ nguyên bản gốc) bằng `python3 Tests/archive_regressions.py`.

GitHub Actions còn biên dịch/chạy kiểm tra Swift cho URL trang Safari loopback, mã hoá URL, tiến độ thiếu/timeout, huỷ an toàn và ngăn hai tác vụ ký đồng thời. Node chạy JavaScript trong HTML do Swift thật sinh ra để kiểm tra tự mở sau tải, chỉ mở một lần, giữ URL manifest lồng nhau và xử lý chuyển hướng bị chặn; sau đó build IPA Release trên macOS.

## Kiểm tra trên iPhone

1. Nhập chứng chỉ Apple còn hiệu lực với profile phù hợp thiết bị; ký IPA ở mặc định và xác nhận hộp thoại cài đặt.
2. Ký lại từ Lịch sử; xác nhận bản vừa ký được cài đúng, kể cả khi nhiều bản có cùng tên.
3. Tắt tự cài; xác nhận có nút Cài đặt/Xuất IPA. Huỷ khi đang sao chép hoặc ký; đợi tác vụ dừng rồi thử lại.
4. Thử IPA lớn, tên có ký tự đặc biệt, chế độ máy chủ HTTPS/máy chủ ngoài và pairing. Kiểm tra thông báo khi đang mở app và khi app ở nền.
5. Thử Light/Dark, Reduce Motion và Low Power Mode. Với OTA, “đã gửi IPA” chưa phải bằng chứng cài thành công: kiểm tra kết quả trên màn hình chính nếu iOS không trả tiến độ cuối.
6. Thử Safari trên iPhone/iPad: sheet cài đặt và máy chủ phải còn hoạt động khi Safari mở; nút Cài đặt phải hiện thông báo xác nhận. Đóng Safari rồi mở lại nút Mở cài đặt. Thử SSL thiếu/hết hạn hoặc chặn mở trực tiếp: đường dự phòng phải dùng lại IPA, không chạy lại đóng gói.

Build và kiểm tra tự động không xác minh việc Apple chấp nhận chứng chỉ, chứng chỉ bị thu hồi, quyền entitlements hay khả năng cài trên mọi phiên bản iOS.
