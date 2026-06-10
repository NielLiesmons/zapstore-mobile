import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/community/comment_card.dart';

import 'helpers/inbox_test_data.dart';
import 'helpers/storage_test_container.dart';

/// Same list shell as [InboxScreen] (padding + separators) without relay timers.
Widget _inboxListShell(List<Comment> comments) {
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
    itemCount: comments.length,
    separatorBuilder: (_, __) => const SizedBox(height: kCommentCardListGap),
    itemBuilder: (context, i) => CommentCard(comment: comments[i]),
  );
}

Future<List<FlutterErrorDetails>> _layoutErrorsDuring(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('RenderFlex') ||
        text.contains('overflowed') ||
        text.contains('BoxConstraints')) {
      errors.add(details);
    }
    old?.call(details);
  };
  await body();
  FlutterError.onError = old;
  return errors;
}

void main() {
  testWidgets('real CommentCard inbox list has no overflow', (tester) async {
    final container = await createStorageTestContainer();
    final comments = await seedInboxTestComments(container);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final errors = await _layoutErrorsDuring(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(extensions: [LabColors.dark()]),
            home: Scaffold(body: _inboxListShell(comments)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });

    container.dispose();

    expect(
      errors,
      isEmpty,
      reason: errors.map((e) => e.exceptionAsString()).join('\n'),
    );
    expect(find.byType(CommentCard), findsWidgets);
  });

  testWidgets('scrolling real CommentCard inbox list stays clean', (tester) async {
    final container = await createStorageTestContainer();
    final comments = await seedInboxTestComments(container);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        errors.add(details);
      }
      old?.call(details);
    };

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: [LabColors.dark()]),
          home: Scaffold(body: _inboxListShell(comments)),
        ),
      ),
    );
    await tester.pump();

    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(list, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));

    FlutterError.onError = old;
    container.dispose();

    expect(
      errors,
      isEmpty,
      reason: errors.map((e) => e.exceptionAsString()).join('\n'),
    );
  });
}
