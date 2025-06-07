import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class AppVersion {
  static String _version = '1.0.0';
  static String get version => _version;

  static Future<void> init() async {
    try {
      final yamlString = await rootBundle.loadString('pubspec.yaml');
      final yaml = loadYaml(yamlString);
      _version = yaml['version'] as String? ?? '1.0.0';
      // Remove build number if present (e.g., 1.0.0+1 -> 1.0.0)
      _version = _version.split('+').first;
    } catch (e) {
      // Fallback to default version if there's an error
      _version = '1.0.0';
    }
  }
}
