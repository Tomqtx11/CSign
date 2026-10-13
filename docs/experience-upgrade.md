# CSign: trải nghiệm mới

Bản sao gốc: tag `backup/pre-upgrade-20261013`, commit `4ac15f7a9bc05fcefd0f3e3797922709c4b2b619`.

- Hôm nay: chứng chỉ đang chọn, thời hạn/đánh dấu thu hồi đã lưu, lối tắt và cập nhật từ nguồn.
- Yêu thích: lưu theo URL nguồn + bundle identifier, độc lập với URL tải/phiên bản. Mở chi tiết sẽ ghi nhận phiên bản đã xem. Có bản mới hiện khi phiên bản số tăng sau lần đã xem. Dữ liệu chỉ ở UserDefaults của thiết bị.
- Nhiệm vụ: khám phá, lưu yêu thích, có chứng chỉ và ký thành công. Tiến độ không bị mất khi xoá app trong thư viện. Bản chỉ chỉnh sửa IPA không được tính là ký thành công. 4/4 mở huy hiệu và màu Aurora.
- Linh vật: mở rộng vector có sẵn với trạng thái nghỉ/tải/ký/ăn mừng. Giữ tuỳ chọn Hoạt ảnh vui nhộn, tôn trọng Giảm chuyển động, nguồn điện thấp và trạng thái app.
- App đáng thử: `CSign/Resources/weekly-picks.json`. Mỗi mục phải khớp URL nguồn và bundle identifier. Dữ liệu thật lấy từ chính nguồn đó; không đưa link IPA khác vào card. JSON đóng gói và cache được dùng khi mạng lỗi. Sau khi sửa JSON trên GitHub, kéo để làm mới app để nhận tuyển chọn mới mà không cần cài lại.

Điện thoại giữ 5 tab: Hôm nay, IPA Mod, Thư viện, Lịch sử, Cài đặt. Hướng dẫn có ở Hôm nay/Cài đặt và sidebar iPad.

## Kiểm tra

Workflow build chạy thêm `ExperienceRegressionTests.swift`: lưu/đọc dữ liệu, cách ly nguồn, đối chiếu phiên bản, giữ huy hiệu và kiểm tra JSON tuyển chọn. Các kiểm tra signer/provisioning, đóng gói IPA, HTTP download và install lifecycle hiện có tiếp tục chạy.

Sau build: ký lại từ cùng binary, template Free phải có CFBundleDisplayName `CSign Free`, cá nhân giữ `CSign`; xác minh chữ ký và tài nguyên trước khi deploy.

## Khôi phục

Release `backup/pre-upgrade-20261013` có source archive, Git bundle và IPA gốc. Tạo nhánh từ tag này để build lại; không reset main. Trên máy, `/home/pi/Downloads/CSign_BACKUP_20261013` giữ cả hai template hiện hành và sáu IPA free trước nâng cấp, kèm SHA-256 và hướng dẫn khôi phục. UserDefaults của trải nghiệm mới không thay đổi Core Data của nguồn, IPA hay chứng chỉ.
