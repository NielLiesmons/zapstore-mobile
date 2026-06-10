import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:models/models.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/community/comment_card.dart';

import '../test/helpers/inbox_test_data.dart';
import '../test/helpers/storage_test_container.dart';

Widget _inboxListShell(List<Comment> comments) {
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
    itemCount: comments.length,
    separatorBuilder: (_, __) => const SizedBox(height: kCommentCardListGap),
    itemBuilder: (context, i) => CommentCard(comment: comments[i]),
  );
}

/// Device/emulator regression: real [CommentCard] rows in an inbox-style [ListView].
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inbox mention list lays out without overflow on device',
      (tester) async {
    final container = await createStorageTestContainer();
    final comments = await seedInboxTestComments(container);

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
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CommentCard), findsWidgets);

    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 200));
    }
    FlutterError.onError = old;
    container.dispose();

    expect(
      errors,
      isEmpty,
      reason: errors.map((e) => e.exceptionAsString()).join('\n'),
    );
  });
}
