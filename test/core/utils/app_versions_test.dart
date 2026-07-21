import 'package:flutter_test/flutter_test.dart';
import 'package:prototipo_2/core/utils/app_versions.dart';

void main() {
  group('ReleaseVersion', () {
    test('separa la versión pública del número de compilación', () {
      final version = ReleaseVersion.parse('1.4.2+18');

      expect(version.display, '1.4.2');
      expect(version.buildNumber, '18');
      expect(version.full, '1.4.2+18');
    });

    test('acepta una versión sin compilación', () {
      final version = ReleaseVersion.parse('2.0.0');

      expect(version.display, '2.0.0');
      expect(version.buildNumber, isNull);
      expect(version.full, '2.0.0');
    });
  });

  group('AppVersions', () {
    testWidgets('carga la versión web real desde el recurso del proyecto', (
      tester,
    ) async {
      await AppVersions.loadAdminWeb();

      expect(AppVersions.adminWeb.display, matches(r'^\d+\.\d+\.\d+'));
      expect(AppVersions.adminWeb.full, isNot('0.0.0'));
    });

    test('lee la versión independiente del panel desde pubspec', () {
      final version = AppVersions.parseAdminWebPubspec('''
name: ejemplo
version: 9.9.9+99
admin_web_version: 1.3.0+7
''');

      expect(version.display, '1.3.0');
      expect(version.full, '1.3.0+7');
    });

    test('rechaza un pubspec sin versión web', () {
      expect(
        () => AppVersions.parseAdminWebPubspec('name: ejemplo'),
        throwsFormatException,
      );
    });
  });
}
