import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/services/auth_service.dart';

void main() {
  group('AuthService Password & Reset Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService(null);
    });

    test('isPasswordUser returns false when user is not logged in', () {
      expect(authService.isPasswordUser, isFalse);
    });

    test('changePassword throws exception when no user is authenticated', () async {
      expect(
        () async => await authService.changePassword(
          currentPassword: 'currentPassword123',
          newPassword: 'newPassword123',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('resetPassword throws exception when Firebase is not configured', () async {
      expect(
        () async => await authService.resetPassword('test@example.com'),
        throwsA(isA<Exception>()),
      );
    });

    test('verifyPasswordResetCode throws exception when Firebase is not configured', () async {
      expect(
        () async => await authService.verifyPasswordResetCode('sample-code-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('confirmPasswordReset throws exception when Firebase is not configured', () async {
      expect(
        () async => await authService.confirmPasswordReset(
          code: 'sample-code-123',
          newPassword: 'newPassword123',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Password and Email Validation Logic', () {
    test('email validation identifies valid and invalid addresses', () {
      bool isValidEmail(String? val) {
        if (val == null || val.trim().isEmpty) return false;
        return val.contains('@') && val.contains('.');
      }

      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('invalid-email'), isFalse);
      expect(isValidEmail('user@domain'), isFalse);
      expect(isValidEmail('user@domain.com'), isTrue);
      expect(isValidEmail('  test.user@company.co.in  '), isTrue);
    });

    test('password validation enforces minimum length of 6 characters', () {
      bool isValidPassword(String? val) {
        if (val == null || val.length < 6) return false;
        return true;
      }

      expect(isValidPassword(''), isFalse);
      expect(isValidPassword('12345'), isFalse);
      expect(isValidPassword('123456'), isTrue);
      expect(isValidPassword('securePassword!'), isTrue);
    });

    test('password match verification detects mismatches', () {
      bool doPasswordsMatch(String p1, String p2) {
        return p1.isNotEmpty && p1 == p2;
      }

      expect(doPasswordsMatch('secret1', 'secret2'), isFalse);
      expect(doPasswordsMatch('secret', 'secret'), isTrue);
      expect(doPasswordsMatch('', ''), isFalse);
    });
  });
}
