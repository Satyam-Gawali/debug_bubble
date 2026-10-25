import 'dart:io';

import 'package:debug_bubble/src/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debugBubbleVersion matches pubspec.yaml version', () {
    var file = File('pubspec.yaml');
    if (!file.existsSync()) {
      file = File('../../pubspec.yaml');
    }
    expect(file.existsSync(), isTrue, reason: 'pubspec.yaml should be found');

    final content = file.readAsStringSync();
    final versionLine = content
        .split('\n')
        .firstWhere((line) => line.trim().startsWith('version:'));
    final pubspecVersion = versionLine.split(':')[1].trim();

    expect(debugBubbleVersion, equals(pubspecVersion));
  });
}
