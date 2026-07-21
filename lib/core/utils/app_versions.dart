import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class ReleaseVersion {
  const ReleaseVersion({required this.number, this.buildNumber});

  final String number;
  final String? buildNumber;

  String get display => number;

  String get full => buildNumber == null ? number : '$number+$buildNumber';

  factory ReleaseVersion.parse(String value) {
    final normalized = value.trim();
    final match = RegExp(
      r'^(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)(?:\+([0-9A-Za-z.-]+))?$',
    ).firstMatch(normalized);

    if (match == null) {
      throw FormatException(
        'La versión "$value" debe usar el formato 1.2.3 o 1.2.3+4.',
      );
    }

    return ReleaseVersion(number: match.group(1)!, buildNumber: match.group(2));
  }
}

abstract final class AppVersions {
  static const _adminWebKey = 'admin_web_version';

  static ReleaseVersion adminWeb = const ReleaseVersion(number: '0.0.0');

  static Future<void> loadAdminWeb() async {
    final pubspec = await rootBundle.loadString('pubspec.yaml');
    adminWeb = parseAdminWebPubspec(pubspec);
  }

  static ReleaseVersion parseAdminWebPubspec(String pubspec) {
    final document = loadYaml(pubspec);
    if (document is! YamlMap) {
      throw const FormatException(
        'El pubspec.yaml no contiene un mapa válido.',
      );
    }

    final rawVersion = document[_adminWebKey]?.toString().trim();
    if (rawVersion == null || rawVersion.isEmpty) {
      throw const FormatException(
        'Falta admin_web_version en el pubspec.yaml.',
      );
    }

    return ReleaseVersion.parse(rawVersion);
  }
}
