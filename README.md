# TrungTN — Flutter device authentication

Ứng dụng yêu cầu xác thực thiết bị khi không có phiên mở khóa còn hạn. Xác thực thành công tạo một phiên mới; các lần mở app trong thời hạn đã chọn có thể tiếp tục dùng phiên đó.

## Cấu trúc

- `lib/main.dart`: cấu hình theme, tiếng Việt và điểm vào ứng dụng.
- `lib/features/auth/device_auth_service.dart`: gọi `local_auth`, cho phép dùng mã khóa thiết bị và chuyển lỗi thành thông báo.
- `lib/features/auth/auth_gate.dart`: màn khóa, trạng thái xác thực, thử lại và thoát.
- `lib/features/home/home_screen.dart`: khung ba tab và vòng đời dữ liệu sau khi xác thực.
- `test/`: kiểm tra luồng khóa/mở, lỗi, thoát và cấu hình fallback.

## Hành vi

- iPhone: hệ thống dùng Face ID hoặc Touch ID tùy phần cứng và cấu hình.
- Android: hộp thoại sinh trắc học hệ thống hỗ trợ vân tay; hệ điều hành quyết định phương thức sinh trắc khả dụng, ứng dụng không ép riêng cảm biến vân tay.
- Không có sinh trắc học: dùng PIN, mật mã, mật khẩu hoặc hình vẽ khóa máy trong giao diện hệ thống. Ứng dụng không đọc, lưu hoặc so sánh mật khẩu máy.
- Chưa thiết lập mã khóa hoặc thiết bị không hỗ trợ: giữ màn khóa và hiển thị hướng dẫn.
- Hủy, thất bại hoặc lỗi: hiện thông báo, nút **Thử lại** và **Thoát ứng dụng**. Hệ điều hành có thể cho thử lại sinh trắc học ngay trong hộp thoại trước khi trả kết quả thất bại về app.
- Android: nút thoát đóng Activity bằng `SystemNavigator.pop()`.
- iOS: nút thoát hiển thị hướng dẫn về màn hình chính/đóng ứng dụng; không ép kết thúc tiến trình. Nội dung bên trong tiếp tục bị khóa.
- Icon khóa ở topbar mở menu thời gian khóa. Mặc định ứng dụng khóa khi xuống nền; nếu chọn một khoảng thời gian, app chỉ yêu cầu xác thực lại sau khi phiên hết hạn. Chọn **Khóa luôn** để khóa ngay.

## Chạy và kiểm tra

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Kiểm thử Face ID/vân tay/mã khóa trên điện thoại thật đã cấu hình khóa màn hình. Với iOS Simulator, cấu hình Face ID/Touch ID trong menu Features và mô phỏng kết quả khớp/không khớp. Cần build lại app sau khi thay đổi plugin hoặc cấu hình native; hot reload không đủ.

Android cần API 24 trở lên theo `local_auth`; iOS project hiện đặt deployment target 15.0. Web/Linux không có phương thức xác thực được tích hợp nên không mở được màn chính.

Tài liệu: [local_auth](https://pub.dev/packages/local_auth), [Android setup](https://pub.dev/packages/local_auth_android), [iOS setup](https://pub.dev/packages/local_auth_darwin), [SystemNavigator.pop](https://api.flutter.dev/flutter/services/SystemNavigator/pop.html).

## Home, Lưu trữ và Khám phá

- Thanh điều hướng gồm **Home**, **Lưu trữ**, **Khám phá**. Chỉ tab đang chọn hiện tên cạnh icon; đổi tab vẫn giữ vị trí/thư mục đang xem.
- **Home** tổng hợp thời tiết, thống kê lưu trữ, thư mục, nội dung gần đây, giá vàng, giá xăng và tin mới.
- **Lưu trữ**: nhấn icon thư mục có dấu cộng để tạo thư mục; nhấn một lần để chọn, nhấn đúp để mở. Có thể tạo thư mục con.
- Trong thư mục, nhấn **+** để thêm văn bản thường, văn bản có định dạng (đậm/nghiêng/danh sách…), nhiều ảnh, video hoặc tệp bất kỳ. Nhấn **Lưu** trong editor để ghi lại thay đổi. Rời editor khi chưa lưu sẽ có xác nhận.
- Ảnh có thể phóng to, video có phát/tạm dừng và tua. Các tệp khác có thể mở bằng ứng dụng hỗ trợ trên thiết bị.
- Metadata và ghi chú lưu trong `Application Support/vault/index.json`; file nhập được sao chép vào `vault/files/`, nên không phụ thuộc file tạm của trình chọn file. Các lần ghi được xếp hàng và index được thay bằng thao tác rename sau khi ghi xong. Dữ liệu vẫn còn sau khi mở lại app.
- Màn hình và hộp thoại bên trong được đặt trong Navigator riêng, giữ trạng thái dưới lớp khóa khi ứng dụng xuống nền. Ghi chú đang soạn hoặc lần nhập tệp không bị mất do giao diện xác thực được dựng lại. Video tự tạm dừng khi ứng dụng không còn ở foreground.

### Nguồn Khám phá

- Thời tiết: [Open-Meteo](https://open-meteo.com/en/docs), mặc định TP.HCM; đổi giữa các thành phố bằng menu trên thẻ thời tiết.
- Giá vàng: [API công khai BTMC](https://btmc.vn/thong-tin/tai-lieu-api/api-gia-vang-17784.html), hiển thị giá mua/bán VND/chỉ cho SJC và nhẫn tròn trơn, chọn bản ghi mới nhất cho từng sản phẩm.
- Giá xăng dầu: dữ liệu bảng giá công khai mà [website Petrolimex](https://www.petrolimex.com.vn/) đang sử dụng; hiển thị hai vùng bằng VND/lít, không trộn giá dầu mazut tính theo kg.
- Bài viết trong nước/thế giới: [RSS VnExpress](https://vnexpress.net/rss), hiển thị tiêu đề, tóm tắt, ảnh, thời gian và nguồn. Nhấn bài viết để mở bản gốc.

Kéo xuống ở Home/Khám phá để cập nhật. Giá có thời gian cập nhật của nguồn và thời gian tải; nguồn có thể trả bản ghi của kỳ trước. Các nguồn được tải độc lập, có timeout và thông báo lỗi riêng. Khi tải lại thất bại, dữ liệu cũ trong phiên được giữ cùng thông báo. Không có số liệu hay bài viết mẫu trong app. API công khai của nhà cung cấp có thể thay đổi cấu trúc hoặc khả năng truy cập; adapter nằm trong `lib/features/discover/discover_service.dart`.

Các thư mục mã mới: `lib/features/storage/`, `lib/features/discover/`, `lib/shared/`. Kiểm tra nguồn online (độc lập với unit test dùng fixture):

```sh
dart run tool/check_discover_sources.dart
```

Cần dừng app và chạy build mới sau khi cài các plugin native; hot reload không đủ để nạp trình chọn file, phát video hoặc mở file.

## Giao diện đen trắng

Theme dùng đen, trắng và xám, thẻ và nút bo tròn. Font Be Vietnam Pro được đóng gói cùng ứng dụng (400/500/600/700), nội dung chính 16–17px. Thanh điều hướng nổi cao 60px, icon 30px; mục đang chọn có nền trắng và tên bên cạnh icon.

Kho mới được thêm 6 thư mục mẫu, mỗi thư mục có văn bản thường, editor, ảnh, PDF và video để xem giao diện và thử sửa văn bản. Dữ liệu mẫu được bổ sung một lần khi cập nhật phiên bản demo; kho đã dùng trước đó cũng nhận được các mẫu mới. Nội dung đã lưu không bị ghi đè. Các nguồn Khám phá vẫn dùng dữ liệu online.

Font: [Google Fonts — Be Vietnam Pro](https://github.com/google/fonts/tree/main/ofl/bevietnampro), giấy phép tại `assets/fonts/OFL.txt`. Chạy lại ứng dụng để nạp font và dữ liệu mẫu cho kho mới.

### Animation và thư mục mẫu đầy đủ

Tab đang chọn có nền trắng trượt trong 320ms và icon nảy nhẹ khi bấm. Phần nền focus giữ chiều rộng bằng 2/3 bản trước, cao 52px trong thanh 60px, cách mép trên/dưới 4px. Hiệu ứng splash/highlight và phản hồi mặc định khi bấm đã tắt; hiệu ứng trượt vẫn được giữ. Hiệu ứng tôn trọng cài đặt giảm chuyển động của thiết bị.

Sáu thư mục mẫu: Cá nhân, Công việc, Ý tưởng, Tài liệu, Hình ảnh, Video. Mỗi thư mục có đủ năm loại nội dung. Ảnh JPEG, file PDF và video MP4 được đóng gói trong `assets/demo/`, sao chép vào vùng lưu trữ riêng và mở được offline. Nguồn media mẫu từ bộ tài liệu Flutter, xem `assets/demo/SOURCES.txt`.

Trong thư mục có các nút thêm nhanh **Text**, **Editor**, **Ảnh**, **File**, **Video**; nút tạo thư mục và menu dấu **+** vẫn có sẵn. Nhấn đúp để mở thư mục. Khởi động lại app sau cập nhật để nạp asset và bổ sung dữ liệu mẫu cho kho hiện tại.

## Thời hạn phiên xác thực

Nhấn icon khóa trên topbar để chọn **Khóa luôn**, **3 phút**, **15 phút**, **30 phút**, **1 giờ**, **3 giờ**, **1 ngày**, **7 ngày**. Menu hiển thị thời điểm mở khóa và thời điểm cần xác thực lại. Thời hạn luôn tính từ lần xác thực thiết bị thành công gần nhất; chọn lại mốc không đặt lại thời gian bắt đầu. Nếu chọn thời hạn ngắn hơn thời gian đã trôi qua, app yêu cầu xác thực lại ngay.

Phiên còn hạn được giữ khi xuống nền hoặc đóng/mở lại app. App kiểm tra hạn ngay khi quay về foreground; khi đang sử dụng, timer sẽ yêu cầu xác thực khi hết hạn. Màn hình đang xem và nội dung soạn thảo được giữ dưới lớp khóa. Xác thực lại thành công sẽ bắt đầu một phiên mới với lựa chọn đã lưu.

Lựa chọn và mốc xác thực được lưu riêng trong `Application Support/lock_session.json`, ghi theo hàng đợi và thay file sau khi ghi hoàn tất. Mốc tương lai, phiên hết hạn hoặc dữ liệu không hợp lệ không mở được màn chính. Nếu chưa chọn mốc, hành vi mặc định vẫn là khóa khi xuống nền và xác thực khi mở lại. Không có mật mã hay dữ liệu sinh trắc học trong file phiên.
