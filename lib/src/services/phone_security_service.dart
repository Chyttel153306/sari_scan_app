import 'package:local_auth/local_auth.dart';

class PhoneSecurityResult {
  const PhoneSecurityResult.success() : authenticated = true, message = null;

  const PhoneSecurityResult.failure(this.message) : authenticated = false;

  final bool authenticated;
  final String? message;
}

abstract interface class PhoneSecurityAuthenticator {
  Future<PhoneSecurityResult> authenticate();
}

class PhoneSecurityService implements PhoneSecurityAuthenticator {
  PhoneSecurityService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<PhoneSecurityResult> authenticate() async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) {
        return const PhoneSecurityResult.failure(
          'Set up a fingerprint, face unlock, PIN, pattern, or password in '
          'your phone settings first.',
        );
      }

      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Unlock your offline SariScan store',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? const PhoneSecurityResult.success()
          : const PhoneSecurityResult.failure(
              'Phone security was cancelled. Try again to continue.',
            );
    } on LocalAuthException catch (error) {
      return PhoneSecurityResult.failure(
        error.description ??
            'Phone security is unavailable right now. Check your phone '
                'security settings and try again.',
      );
    } catch (_) {
      return const PhoneSecurityResult.failure(
        'Phone security could not open. Check your phone security settings '
        'and try again.',
      );
    }
  }
}
