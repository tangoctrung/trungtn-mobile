import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_demo/features/auth/device_auth_service.dart';

class FakeLocalAuth extends LocalAuthentication {
  bool supported = true;
  bool result = true;
  LocalAuthException? error;
  bool? requestedBiometricOnly;
  bool? requestedPersistence;
  int prompts = 0;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    requestedBiometricOnly = biometricOnly;
    requestedPersistence = persistAcrossBackgrounding;
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  test(
    'Allows OS device credentials, including devices without biometrics',
    () async {
      final local = FakeLocalAuth();
      final service = DeviceAuthService(localAuth: local);
      expect(await service.authenticate(), isTrue);
      expect(local.requestedBiometricOnly, isFalse);
      expect(local.requestedPersistence, isTrue);
    },
  );

  test('Unsupported device fails closed without opening a prompt', () async {
    final local = FakeLocalAuth()..supported = false;
    await expectLater(
      DeviceAuthService(localAuth: local).authenticate(),
      throwsA(isA<DeviceAuthFailure>()),
    );
    expect(local.prompts, 0);
  });

  test('False authentication result is preserved', () async {
    final local = FakeLocalAuth()..result = false;
    expect(await DeviceAuthService(localAuth: local).authenticate(), isFalse);
  });

  for (final code in [
    LocalAuthExceptionCode.userCanceled,
    LocalAuthExceptionCode.noCredentialsSet,
    LocalAuthExceptionCode.temporaryLockout,
    LocalAuthExceptionCode.biometricLockout,
    LocalAuthExceptionCode.unknownError,
  ]) {
    test('Handles ${code.name} without granting access', () async {
      final local = FakeLocalAuth()..error = LocalAuthException(code: code);
      await expectLater(
        DeviceAuthService(localAuth: local).authenticate(),
        throwsA(
          isA<DeviceAuthFailure>().having(
            (failure) => failure.message,
            'localized explanation',
            isNotEmpty,
          ),
        ),
      );
    });
  }
}
