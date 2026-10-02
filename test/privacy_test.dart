import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips XML comments so documentation that merely *names* a permission is not
/// mistaken for a request for it.
String _withoutXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');

/// The privacy claim is structural: the shipped Android manifest asks for no
/// permissions, so the app has no way to reach the network. If someone adds one
/// later, these tests fail instead of the README quietly becoming a lie.
void main() {
  group('release manifest', () {
    final mainManifest = File('android/app/src/main/AndroidManifest.xml');

    test('exists', () {
      expect(mainManifest.existsSync(), isTrue);
    });

    test('requests zero permissions', () {
      final xml = _withoutXmlComments(mainManifest.readAsStringSync());
      final requested = RegExp(
        r'<uses-permission[^>]*android:name\s*=\s*"([^"]+)"',
      ).allMatches(xml).map((m) => m.group(1)).toList();
      expect(requested, isEmpty, reason: 'unexpected permissions: $requested');
    });

    test('has no INTERNET permission anywhere in the release source set', () {
      final offenders = <String>[];
      for (final entity in Directory(
        'android/app/src/main',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.xml')) continue;
        if (_withoutXmlComments(
          entity.readAsStringSync(),
        ).contains('android.permission.INTERNET')) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('dependency surface', () {
    /// Package names from the `dependencies:` block of pubspec.yaml.
    List<String> directDependencies() {
      final lines = File('pubspec.yaml').readAsLinesSync();
      final names = <String>[];
      var inBlock = false;
      for (final raw in lines) {
        final line = raw.split('#').first;
        if (!inBlock) {
          if (line.trimRight() == 'dependencies:') inBlock = true;
          continue;
        }
        if (line.trim().isEmpty) continue;
        if (!line.startsWith(' ') && !line.startsWith('\t')) break;
        final m = RegExp(r'^\s{2}([a-z0-9_]+):').firstMatch(line);
        if (m != null) names.add(m.group(1)!);
      }
      return names;
    }

    test('parses the dependency block', () {
      expect(directDependencies(), contains('image'));
      expect(directDependencies(), contains('file_picker'));
    });

    test('pulls in no networking package', () {
      const banned = {
        'http',
        'dio',
        'chopper',
        'gql',
        'graphql_flutter',
        'socket_io_client',
        'web_socket_channel',
        'internet_connection_checker',
        'firebase_core',
        'sentry_flutter',
      };
      final found = directDependencies().where(banned.contains).toList();
      expect(
        found,
        isEmpty,
        reason: 'network packages are not allowed: $found',
      );
    });

    test('the image pipeline never opens a socket', () {
      final engine = File('lib/core/engine.dart').readAsStringSync();
      expect(engine.contains('package:http'), isFalse);
      expect(engine.contains('HttpClient'), isFalse);
      expect(engine.contains('Socket'), isFalse);
    });

    test('no source file imports an HTTP or socket client', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        if (text.contains('package:http/') ||
            text.contains('HttpClient') ||
            text.contains('package:web_socket_channel')) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
