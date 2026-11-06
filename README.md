# WakeUp – Báo thức thông minh (Flutter, chỉ Android)

Tắt báo thức bằng cách **chụp lại đúng đồ vật** đã chụp mẫu từ trước.

## Đã làm sẵn trong mã nguồn (thư mục `lib/`)
| Chức năng | Cách làm |
|---|---|
| Đăng ký / đăng nhập / đăng xuất / nhớ tài khoản | SQLite + mật khẩu băm SHA-256 có salt (`services.dart`, `screens/auth.dart`) |
| Tạo / sửa / xóa nhiệm vụ bằng ảnh đồ vật mẫu | `camera` + SQLite (`screens/task_edit.dart`, tab Nhiệm vụ) |
| Tạo / sửa / xóa báo thức (giờ, tên, ngày lặp, chọn nhiệm vụ) | `screens/alarm_edit.dart`, tab Báo thức |
| Hẹn giờ + chuông + màn hình khóa | `flutter_local_notifications` (exact alarm, full-screen intent, âm thanh lặp) |
| Màn hình báo thức: hiện nhiệm vụ, bắt buộc chụp ảnh | `screens/ring.dart` |
| Đúng → hoàn thành + tắt chuông; sai → báo "chưa đúng" | `ImageMatcher` trong `services.dart` |
| Lịch sử, cài đặt (độ nghiêm ngặt) | SQLite, SharedPreferences |

## Bước 1 – Tạo dự án và chép mã
```bash
flutter create --org com.example --platforms android wakeup
cd wakeup
# Chép đè: pubspec.yaml và thư mục lib/ từ gói này
flutter pub get
```

## Bước 2 – Sửa Android (BẮT BUỘC, mình không làm giúp được vì thư mục `android/` do `flutter create` sinh ra)

### 2.1 `android/app/src/main/AndroidManifest.xml`
Thêm **trước** thẻ `<application>`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```
Trong thẻ `<activity android:name=".MainActivity" ...>` thêm 2 thuộc tính:
```xml
android:showWhenLocked="true"
android:turnScreenOn="true"
```
Trong thẻ `<application>` (cạnh `<activity>`) thêm:
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

### 2.2 `android/app/build.gradle` (hoặc `build.gradle.kts`)
`flutter_local_notifications` cần "desugaring" và `minSdk 21` trở lên.
- Groovy (`build.gradle`):
```gradle
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    defaultConfig { minSdkVersion 21 }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```
- Kotlin DSL (`build.gradle.kts`): `isCoreLibraryDesugaringEnabled = true`, `minSdk = 21`, và `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")`.

## Bước 3 – Chạy thử trên máy Android thật
```bash
flutter run
```
1. Đăng ký tài khoản.
2. Tab **Nhiệm vụ** → nút máy ảnh → đặt tên, chụp đồ vật mẫu → Lưu.
3. Tab **Báo thức** → `+` → chọn giờ, ngày lặp, nhiệm vụ → Lưu.
4. **Cài đặt → Báo thức thử sau 20 giây**, khóa màn hình và chờ. Chuông kêu, màn hình báo thức hiện ra, bấm **Mở camera** và chụp đúng đồ vật.

Cấp đủ quyền khi hệ điều hành hỏi: Thông báo, Camera, "Báo thức & lời nhắc" (Alarms & reminders).

## Những phần cần bạn tự kiểm tra / làm thêm

### A. Hãng máy chặn báo thức (Xiaomi, Oppo, Vivo, Samsung, Huawei...)
Mở **Cài đặt máy → Ứng dụng → WakeUp**: bật *Tự khởi chạy*, *Chạy nền*, *Hiển thị trên màn hình khóa*, và đặt pin = *Không hạn chế*. Nếu không, báo thức có thể không kêu khi app đã bị tắt. Việc này phải làm trên từng máy, không thể làm từ mã.

### B. Nhận diện ảnh chính xác hơn (LiteRT / TensorFlow Lite)
Bản hiện tại dùng so khớp **màu + hình dạng ở vùng giữa ảnh** bằng Dart thuần, chạy được ngay không cần mô hình, nhưng sẽ nhạy với đổi nền, ánh sáng và góc chụp. Chỉnh bằng thanh "Độ nghiêm ngặt" trong Cài đặt. Để chính xác hơn:
1. Tải một mô hình **feature-vector** (đầu ra là vector đặc trưng), ví dụ MobileNetV3 / EfficientNet-Lite từ Kaggle Models hoặc TensorFlow Hub, định dạng `.tflite`. Chép vào `assets/models/embed.tflite` và khai báo trong `pubspec.yaml` mục `flutter: assets:`.
2. Thêm dependency `tflite_flutter` (kiểm tra phiên bản mới nhất trên pub.dev).
3. Viết `EmbeddingMatcher`: resize ảnh đúng kích thước đầu vào của mô hình (thường 224×224, chuẩn hóa theo tài liệu của mô hình), chạy `Interpreter.run` cho **ảnh mẫu** và **ảnh mới** để lấy 2 vector, rồi tính **cosine similarity**. Điểm càng gần 1 càng giống.
4. Thay thân hàm `ImageMatcher.score` bằng `EmbeddingMatcher` (giữ nguyên chữ ký hàm nên không phải sửa màn hình nào). Thử với ảnh thật rồi chọn ngưỡng (thường 0.75–0.9).
Cách này hỗ trợ cả đồ vật tùy chỉnh mà không cần huấn luyện lại.

### C. Đổi sang Firebase Authentication (nếu muốn)
1. Tạo dự án tại console.firebase.google.com, thêm app Android (đúng package name), bật *Authentication → Email/Password*, tải `google-services.json` vào `android/app/`.
2. Chạy `flutterfire configure`, thêm `firebase_core`, `firebase_auth`.
3. Trong `Auth.register` / `Auth.login` (file `services.dart`) gọi `createUserWithEmailAndPassword` / `signInWithEmailAndPassword`, giữ nguyên các màn hình. Gọi `Firebase.initializeApp()` trong `main()`.
Bản hiện tại chạy offline, tài khoản chỉ nằm trên máy.

### D. Âm báo thức riêng
Mặc định dùng âm báo của hệ thống, lặp đến khi hoàn thành nhiệm vụ. Muốn chuông riêng: đặt file `alarm.mp3` vào `android/app/src/main/res/raw/`, rồi thêm `sound: RawResourceAndroidNotificationSound('alarm')` vào `AndroidNotificationDetails` (và đổi id kênh, ví dụ `wakeup_alarm2`, vì Android nhớ cấu hình kênh cũ).

## Giới hạn đã biết
- Mã chưa được biên dịch hay chạy thử trong môi trường này (không có Flutter SDK). Nếu `flutter run` báo lỗi, hãy gửi lại nguyên văn lỗi để sửa.
- Báo thức lặp được hẹn lần kế tiếp mỗi khi mở app hoặc sau khi hoàn thành nhiệm vụ, nên nếu bạn không mở app và không hoàn thành báo thức thì các lần lặp sau có thể không được hẹn lại (cải thiện bằng cách dùng `matchDateTimeComponents` với múi giờ địa phương qua `flutter_timezone`).
- Dữ liệu (nhiệm vụ, báo thức) dùng chung cho mọi tài khoản trên máy.
- Có "Tắt khẩn cấp" sau 5 lần chụp sai để không bị kẹt; bạn có thể bỏ nếu muốn nghiêm ngặt hơn.
