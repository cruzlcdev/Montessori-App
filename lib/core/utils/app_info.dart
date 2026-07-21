import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static String appName = "";
  static String packageName = "";
  static String version = "";
  static String buildNumber = "";

  /// Carga la información de la app desde el sistema
  static Future<void> loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    appName = info.appName;
    packageName = info.packageName;
    version = info.version;
    buildNumber = info.buildNumber;
  }

  /// Devuelve la versión en formato amigable
  static String get fullVersion => "$version+$buildNumber";

  /// Versión pública que se muestra a los usuarios.
  static String get displayVersion => version;
}
