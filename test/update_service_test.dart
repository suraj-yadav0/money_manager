import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/services/update_service.dart';

void main() {
  group('UpdateService.isNewer version comparison tests', () {
    test('detects newer patch version', () {
      expect(UpdateService.isNewer('v1.0.4', '1.0.3'), isTrue);
      expect(UpdateService.isNewer('1.0.4', '1.0.3'), isTrue);
    });

    test('detects newer minor version', () {
      expect(UpdateService.isNewer('v1.1.0', '1.0.9'), isTrue);
      expect(UpdateService.isNewer('1.2.0', '1.1.5'), isTrue);
    });

    test('detects newer major version', () {
      expect(UpdateService.isNewer('v2.0.0', '1.9.9'), isTrue);
    });

    test('detects newer build number when versions match', () {
      expect(
        UpdateService.isNewer('v1.0.3+5', '1.0.3', currentBuild: 4),
        isTrue,
      );
      expect(
        UpdateService.isNewer('v1.0.3+4', '1.0.3', currentBuild: 4),
        isFalse,
      );
      expect(
        UpdateService.isNewer('v1.0.3+3', '1.0.3', currentBuild: 4),
        isFalse,
      );
    });

    test('returns false when remote version is equal or older', () {
      expect(UpdateService.isNewer('v1.0.3', '1.0.3'), isFalse);
      expect(UpdateService.isNewer('1.0.3', '1.0.3'), isFalse);
      expect(UpdateService.isNewer('v1.0.2', '1.0.3'), isFalse);
      expect(UpdateService.isNewer('v0.9.9', '1.0.3'), isFalse);
    });

    test('handles tags with extra whitespace or mixed casing', () {
      expect(UpdateService.isNewer('  V1.0.4  ', '1.0.3'), isTrue);
      expect(UpdateService.isNewer('v1.0.3', '  1.0.3 '), isFalse);
    });
  });
}
