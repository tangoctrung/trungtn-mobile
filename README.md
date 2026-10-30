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
- Toolbar editor dùng icon trắng trên nền đen cho định dạng đang chọn, icon đen khi chưa chọn; vùng chọn chữ có nền xám trong suốt. Chỉ thay đổi nội dung/định dạng tài liệu mới được xem là chỉnh sửa; đổi focus hoặc vị trí con trỏ không hiện cảnh báo bỏ thay đổi, undo về nội dung ban đầu cũng không cảnh báo.
- Ảnh có thể phóng to, video có phát/tạm dừng và tua. Các tệp khác có thể mở bằng ứng dụng hỗ trợ trên thiết bị.
- Card Text/Editor có nút **Sao chép nội dung** để copy toàn bộ văn bản (kể cả phần bị rút gọn). Mở ảnh rồi vuốt trái để xem ảnh tiếp, vuốt phải để xem ảnh trước trong cùng thư mục, theo thứ tự ảnh trên lưới. Tên ảnh và bộ đếm cập nhật theo ảnh đang xem; vẫn hỗ trợ zoom và vuốt từ mép trái để Back.
- Vuốt từ mép trái sang phải để quay lại: từ thư mục về thư mục cha, từ trình xem/soạn thảo về màn trước. Ghi chú chưa lưu vẫn yêu cầu xác nhận; vuốt ở màn gốc không thoát app.
- Thư mục, ghi chú và metadata lưu bằng **SQLite** (`sqflite`) tại `Application Support/vault/vault.db`, có transaction và khóa ngoại. File nhập được sao chép vào `vault/files/`, ảnh đại diện vào `vault/covers/`. Kho JSON cũ tự chuyển sang SQLite một lần, giữ nguyên ID, định dạng ghi chú và đường dẫn tệp; `index.json` được giữ làm bản sao chuyển đổi và không nhập lại sau khi xóa dữ liệu.
- Màn Lưu trữ chỉ hiển thị thư mục, không có “Gần đây”. Nhấn giữ thư mục ở Home hoặc Lưu trữ để đổi tên, đổi ảnh đại diện hoặc xóa; thumbnail thư mục không có nút camera/ba chấm. Với card nội dung, nhấn **…** hoặc giữ lâu để đổi tên, sửa ghi chú, thay ảnh/video/file hoặc xóa. Xóa thư mục có xác nhận và xóa cả thư mục con; tệp riêng được dọn sau khi transaction hoàn tất, tệp dùng chung chỉ xóa khi không còn được tham chiếu.
- Xóa nhiều: trong **Lưu trữ**, nhấn icon **Chọn nhiều** trên hàng tiêu đề (ở kho gốc lẫn trong thư mục), hoặc mở menu của một mục rồi chọn **Chọn nhiều**. Chạm để chọn/bỏ chọn thư mục, text/editor, ảnh, video và file trong vị trí hiện tại; có **Chọn tất cả/Bỏ chọn tất cả**. Thanh thao tác luôn hiện khi cuộn. Nhấn **Xóa** rồi xác nhận; hộp thoại tính cả thư mục con và nội dung bên trong, không đếm trùng. Toàn bộ lựa chọn được xóa trong một transaction SQLite; lỗi sẽ rollback toàn bộ trước khi dọn file, dung lượng được cập nhật sau khi hoàn tất. Back hoặc nút **×** thoát chế độ chọn trước khi quay về thư mục cha.
- Thẻ **Đã dùng** hiển thị dung lượng thực tế của kho trên máy, cập nhật sau thêm/sửa/xóa. Nhấn để xem tệp, ảnh đại diện, ghi chú/dữ liệu ứng dụng và dữ liệu khác cùng số lượng từng loại. Tổng được tính từ kích thước file thực tế, gồm SQLite/WAL và bản sao chuyển đổi; không cộng trùng file demo dùng chung hoặc cộng lại text đã nằm trong database.
- Màn hình và hộp thoại bên trong được đặt trong Navigator riêng, giữ trạng thái dưới lớp khóa khi ứng dụng xuống nền. Ghi chú đang soạn hoặc lần nhập tệp không bị mất do giao diện xác thực được dựng lại. Video tự tạm dừng khi ứng dụng không còn ở foreground.
- Trên Android/iOS, chuyển focus, mở/đóng editor và trạng thái `hidden` tạm thời không thu hồi phiên xác thực. Nội dung vẫn được che khi hidden; chính sách khóa khi xuống nền được áp dụng ở `paused`. Khóa thủ công và thời hạn tính từ lần mở khóa gần nhất vẫn được giữ nguyên.

### Nguồn Khám phá

- Thời tiết: [Open-Meteo](https://open-meteo.com/en/docs), mặc định lấy tọa độ hiện tại qua `geolocator` sau khi mở khóa app. Chỉ xin quyền khi dùng app, đọc vị trí một lần mỗi lần tải lại, không theo dõi nền. Quyền vị trí chỉ được tự hỏi lần đầu trong phiên; các lần refresh tiếp theo không tự hỏi lại. Khi từ chối/tắt GPS có thông báo, nút thử lại/cài đặt và menu chọn thành phố thủ công; chọn **Vị trí hiện tại** để quay về GPS. Phản hồi cũ không ghi đè vị trí mới. Thời điểm quan trắc dùng Unix timestamp UTC, hiển thị theo giờ thiết bị.
- Giá vàng: [API công khai BTMC](https://btmc.vn/thong-tin/tai-lieu-api/api-gia-vang-17784.html), hiển thị giá mua/bán VND/chỉ cho SJC và nhẫn tròn trơn, chọn bản ghi mới nhất cho từng sản phẩm.
- Giá xăng dầu: dữ liệu bảng giá công khai mà [website Petrolimex](https://www.petrolimex.com.vn/) đang sử dụng; hiển thị hai vùng bằng VND/lít, không trộn giá dầu mazut tính theo kg.
- Bài viết trong nước/thế giới: [RSS VnExpress](https://vnexpress.net/rss), hiển thị tiêu đề, tóm tắt, ảnh, thời gian và nguồn. Nhấn bài viết ở Home hoặc Khám phá để đọc bản gốc ngay trong app qua WebView (Android/iOS). Có tiến trình tải, tải lại và thử lại khi lỗi mạng; nút Back/vuốt mép trái quay lại lịch sử trang hoặc danh sách tin, nút × đóng bài viết. Danh sách giữ vị trí cuộn; trang đọc vẫn nằm dưới lớp khóa của app.

Kéo xuống ở Home/Khám phá để cập nhật. Giá có thời gian cập nhật của nguồn và thời gian tải; nguồn có thể trả bản ghi của kỳ trước. Các nguồn được tải độc lập, có timeout và thông báo lỗi riêng. Khi tải lại thất bại, dữ liệu cũ trong phiên được giữ cùng thông báo. Không có số liệu hay bài viết mẫu trong app. API công khai của nhà cung cấp có thể thay đổi cấu trúc hoặc khả năng truy cập; adapter nằm trong `lib/features/discover/discover_service.dart`.

Các thư mục mã mới: `lib/features/storage/`, `lib/features/discover/`, `lib/shared/`. Kiểm tra nguồn online (độc lập với unit test dùng fixture):

```sh
dart run tool/check_discover_sources.dart
```

Cần dừng app và chạy build mới sau khi cài các plugin native; hot reload không đủ để nạp trình chọn file, phát video hoặc mở file.

Plugin vị trí cũng cần dừng/chạy lại app. Với iOS dùng Swift Package Manager, chạy `BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter run` hoặc thêm cùng biến này khi `flutter build ios` để bỏ nhánh xin quyền vị trí Always khỏi plugin; app chỉ khai báo quyền vị trí khi đang sử dụng.

## Giao diện và ảnh đại diện thư mục

Giao diện dùng Roboto đóng gói offline, nền trắng và thông tin phụ màu xám. Nội dung chính 16–17px, tiêu đề nội dung 18px, thông tin phụ 13px. Khoảng cách chữ, dòng và nhóm được thu gọn để bố cục liền mạch hơn.

Bottom bar nổi bo tròn trên nền đen, cao 60px, icon 30px. Tab chọn có nền trắng cao 52px, chiều rộng thu còn 2/3 phần focus cũ và hiện tên cạnh icon; hai tab còn lại chỉ hiện icon. Hiệu ứng chuyển tab nhẹ, không có splash/highlight mặc định.

Ảnh mặc định là thư mục xám bo tròn, thân dày và có chiều sâu nhẹ (mẫu 3 đã chọn), vẽ bằng Flutter để rõ nét ở mọi kích thước. Thêm ảnh vào nội dung không tự thay ảnh đại diện. Nhấn giữ thư mục rồi chọn **Đổi ảnh đại diện**, hoặc trong thư mục nhấn **+ → Đổi ảnh đại diện**, rồi chọn **Chọn ảnh từ máy** để dùng ảnh riêng. Ảnh được sao chép vào `vault/covers/` và đường dẫn tương đối được lưu trong SQLite, nên không phụ thuộc file tạm của trình chọn ảnh. Chọn **Dùng ảnh mặc định** để trở lại hình thư mục xám. Giao diện này dùng chung ở Lưu trữ và Home; ảnh đại diện đã tự chọn được giữ nguyên.

Font: [Google Fonts — Roboto](https://github.com/googlefonts/roboto-2), giấy phép tại `assets/fonts/roboto/LICENSE.txt`.

## Dữ liệu mẫu Lưu trữ

Sáu thư mục mẫu: Cá nhân, Công việc, Ý tưởng, Tài liệu, Hình ảnh, Video. Mỗi thư mục có văn bản thường, editor có định dạng, ảnh JPEG, file PDF và video MP4. Media được đóng gói trong `assets/demo/` và dùng được offline; nguồn tại `assets/demo/SOURCES.txt`.

Các nút thêm nhanh **Text**, **Editor**, **Ảnh**, **File**, **Video**, nút tạo thư mục và menu dấu **+** có sẵn. Nhấn đúp để mở thư mục. App không tự thêm dữ liệu mẫu cho người dùng mới; dữ liệu đã có được giữ nguyên khi chuyển sang SQLite. Hàm `load(seedDemo: true)` chỉ dùng khi cần tạo dữ liệu demo trong test/preview.

## Thời hạn phiên xác thực

Nhấn icon khóa trên topbar để chọn **Khóa luôn**, **3 phút**, **15 phút**, **30 phút**, **1 giờ**, **3 giờ**, **1 ngày**, **7 ngày**. Menu hiển thị thời điểm mở khóa và thời điểm cần xác thực lại. Thời hạn luôn tính từ lần xác thực thiết bị thành công gần nhất; chọn lại mốc không đặt lại thời gian bắt đầu. Nếu chọn thời hạn ngắn hơn thời gian đã trôi qua, app yêu cầu xác thực lại ngay.

Phiên còn hạn được giữ khi xuống nền hoặc đóng/mở lại app. App kiểm tra hạn ngay khi quay về foreground; khi đang sử dụng, timer sẽ yêu cầu xác thực khi hết hạn. Màn hình đang xem và nội dung soạn thảo được giữ dưới lớp khóa. Xác thực lại thành công sẽ bắt đầu một phiên mới với lựa chọn đã lưu.

Lựa chọn và mốc xác thực được lưu riêng trong `Application Support/lock_session.json`, ghi theo hàng đợi và thay file sau khi ghi hoàn tất. Mốc tương lai, phiên hết hạn hoặc dữ liệu không hợp lệ không mở được màn chính. Nếu chưa chọn mốc, hành vi mặc định vẫn là khóa khi xuống nền và xác thực khi mở lại. Không có mật mã hay dữ liệu sinh trắc học trong file phiên.

## Card nội dung trong thư mục

Trong mỗi thư mục, nội dung hiển thị thành lưới **2 card mỗi hàng**. Card text/editor có tiêu đề và xem trước tối đa 3 dòng; khi bị cắt có nút **Xem thêm** mở đầy đủ trong editor. Card ảnh hiển thị ảnh và tên; card file/video có hình đại diện định dạng, tên và dung lượng, nhấn để mở. Các nút thêm nội dung và ảnh đại diện thư mục tiếp tục sử dụng như trước.
