import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/social/thread_root.dart';

/// Every PNG shipped from webapp must be bundled — missing assets crash Inbox.
void main() {
  test('emoji PNGs exist on disk', () {
    final dir = Directory('assets/images/emoji');
    expect(dir.existsSync(), isTrue);
    final pngs = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList();
    expect(pngs.length, greaterThanOrEqualTo(40));
    expect(
      pngs.any((f) => f.path.endsWith('forum.png')),
      isTrue,
      reason: 'forum.png is required for inbox CommentCard badges',
    );
  });

  testWidgets('ForumEmojiBadge loads forum.png without asset errors', (
    tester,
  ) async {
    final assetErrors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('Unable to load asset')) {
        assetErrors.add(details);
      }
      old?.call(details);
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [LabColors.dark()]),
        home: const Scaffold(body: ForumEmojiBadge()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    FlutterError.onError = old;
    expect(
      assetErrors,
      isEmpty,
      reason: assetErrors.map((e) => e.exceptionAsString()).join('\n'),
    );
  });
}
