class AppConstants {
  static const String appName = 'MinaCalc Pro';
  static const String appVersion = '2.9.0';
  static const String apiBaseUrl = String.fromEnvironment(
    'MINACALC_API_URL',
    defaultValue: 'https://desenvolvimento.joaoprogramador.site/projetos/minacalc/api.php',
  );
  static const String mapStyleUrl = String.fromEnvironment(
    'MINACALC_MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );
  static const String mapAttribution = '© OpenStreetMap contributors · OpenFreeMap';
  static const String fallbackTermsVersion = '1.0';
  static const int maxPhotos = 8;
  static const int maxOptimizedPhotoBytes = 6 * 1024 * 1024;
}
