import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

abstract interface class DeviceAuthenticator {
  Future<bool> authenticate();
}

class DeviceAuthFailure implements Exception {
  const DeviceAuthFailure(this.message);

  final String message;
}

class DeviceAuthService implements DeviceAuthenticator {
  DeviceAuthService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> authenticate() async {
    try {
      // Device credentials can be available even without biometric hardware.
      if (!await _localAuth.isDeviceSupported()) {
        throw const DeviceAuthFailure(
          'Thiết bị chưa hỗ trợ xác thực hoặc chưa cài mã khóa màn hình. '
          'Hãy thiết lập mã khóa trong Cài đặt rồi thử lại.',
        );
      }

      return await _localAuth.authenticate(
        localizedReason: 'Xác thực danh tính để mở khóa TrungTN',
        // The OS checks the device PIN, pattern or password as a fallback.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Mở khóa TrungTN',
            signInHint: 'Xác thực danh tính của bạn',
            cancelButton: 'Hủy',
          ),
          IOSAuthMessages(
            cancelButton: 'Hủy',
            localizedFallbackTitle: 'Dùng mật mã thiết bị',
          ),
        ],
      );
    } on LocalAuthException catch (error) {
      throw DeviceAuthFailure(switch (error.code) {
        LocalAuthExceptionCode.userCanceled =>
          'Bạn đã hủy xác thực. Ứng dụng vẫn đang được khóa.',
        LocalAuthExceptionCode.systemCanceled =>
          'Xác thực bị gián đoạn. Vui lòng thử lại.',
        LocalAuthExceptionCode.noCredentialsSet =>
          'Thiết bị chưa có mã khóa màn hình. '
              'Hãy thiết lập mã PIN, mật khẩu hoặc hình vẽ trong Cài đặt.',
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          'Xác thực đang bị khóa do thử sai nhiều lần. '
              'Hãy mở khóa thiết bị bằng mã khóa rồi thử lại.',
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware =>
          'Không có sinh trắc học khả dụng. '
              'Hãy kiểm tra mã khóa màn hình trong Cài đặt rồi thử lại.',
        _ => 'Không thể xác thực lúc này. Vui lòng thử lại.',
      });
    }
  }
}
