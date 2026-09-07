# Nhật ký Phát triển Dự án CSign

**Ngày thực hiện:** 30/08/2026
**Mục tiêu:** Xây dựng ứng dụng ký IPA on-device (CSign) mang thương hiệu riêng dựa trên mã nguồn mở Feather, tích hợp quy trình build tự động (CI/CD) qua GitHub Actions.

---

## Các công việc đã hoàn thành

### 1. Khởi tạo mã nguồn & Rebrand (Đổi thương hiệu)
- **Clone Source:** Đã tải mã nguồn gốc sạch nhất của dự án iOS Signer `Feather` (từ tác giả khcrysalis).
- **Rebrand:** Sử dụng script tự động để tìm kiếm và thay thế toàn bộ các từ khóa liên quan đến "Feather" thành "CSign" (và "feather" -> "csign") trên toàn bộ file cấu hình, giao diện và logic của dự án.
- **Đổi Logo:** Đã tải icon độc quyền từ link Imgur (`https://i.imgur.com/WWoN7ox.jpeg`), định dạng lại kích thước chuẩn 1024x1024 và chép đè vào thư mục `AppIcon.appiconset` của CSign.

### 2. Tùy chỉnh tính năng (Giao diện)
- **Thêm Popup thông báo:** Đã can thiệp vào file `CSignApp.swift` để thêm một bảng thông báo (Alert) tự động bật lên khi người dùng mới mở app lần đầu.
  - Cấu trúc: Sử dụng `@AppStorage("hasSeenTutorialAlert")` để lưu trạng thái.
  - Nội dung: *"Bạn đã biết cách sử dụng CSign chưa? Nếu rồi hãy bỏ qua, còn chưa biết sử dụng hãy bấm nút xem hướng dẫn."*
  - Nút bấm: "Bỏ qua" và "Xem hướng dẫn" (tạm thời trỏ về link tìm kiếm Google, có thể dễ dàng thay thế bằng link Youtube thật).

### 3. Sửa lỗi hệ thống & Xử lý Submodule
- Đã khắc phục sự cố hệ thống GitHub Actions không thể build (lỗi không tìm thấy module `Zsign` và `IDeviceKitten`).
- **Nguyên nhân:** Do khởi tạo lại kho Git nội bộ làm mất liên kết Submodule.
- **Cách xử lý:** 
  - Khai báo lại module `IDeviceKit`.
  - Khai báo và checkout chính xác nhánh `package` cho module `Zsign-Package` để lấy file `Package.swift`.
  - Cập nhật và push lại toàn bộ các submodule này vào repo chính.

### 4. Cấu hình CI/CD (GitHub Actions)
- Tạo mới repository `CSign` trên tài khoản GitHub (Cuongqtx11) ở chế độ Private.
- Đẩy (push) toàn bộ mã nguồn lên repo.
- Viết file cấu hình `.github/workflows/build.yml`:
  - Môi trường: Máy chủ `macos-latest` do GitHub cung cấp miễn phí.
  - Biên dịch: Chạy lệnh `make iphoneos` (với `xcodebuild`) để dịch mã Swift ra tệp cài đặt cho iOS.
  - Kết xuất: Trích xuất và tải lên file cài đặt `CSign.ipa` hoàn chỉnh tại mục Artifacts.

---

## Kế hoạch phát triển tiếp theo (Ngày mai)
1. **Kiểm tra file IPA:** Cài đặt file `CSign.ipa` (được build từ GitHub Actions) vào thiết bị iOS để test bảng thông báo và icon.
2. **Cập nhật nội dung Popup:** Sửa link hướng dẫn "Xem hướng dẫn" đến video Youtube/Bài viết hướng dẫn chính thức của CSign.
3. **Tuỳ biến sâu:** 
   - Có thể đổi màu chủ đạo (Theme/Tint Color) của ứng dụng để đồng bộ với màu của Logo.
   - Chỉnh sửa ngôn ngữ (Việt hóa sâu hơn) hoặc thay đổi giao diện Tabbar/Cài đặt theo ý muốn.
4. **Nhúng trực tiếp Chứng chỉ:** Nếu cần, có thể nhét sẵn file `.p12` và `.mobileprovision` kèm `password.txt` vào thư mục `signing-assets` hoặc viết logic tự Import chứng chỉ mặc định vào kho để người dùng tải về là xài được ngay.

*Tài liệu này được tạo tự động để lưu trữ tiến độ công việc.*
