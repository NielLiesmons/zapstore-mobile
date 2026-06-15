import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/community/comment_card.dart';
import 'package:zapstore/widgets/social/bubble_swiper.dart';

Future<List<FlutterErrorDetails>> _pump(WidgetTester tester, Widget child) async {
  final errors = <FlutterErrorDetails>[];
  final old = FlutterError.onError;
  FlutterError.onError = errors.add;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [LabColors.dark()]),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [child],
        ),
      ),
    ),
  );
  await tester.pump();
  FlutterError.onError = old;
  return errors;
}

Widget _tallBubble(LabColors c) {
  return ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 200),
    child: Container(
      padding: const EdgeInsets.all(11),
      color: c.gray66,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Author', style: TextStyle(fontSize: 13)),
          SizedBox(height: 4),
          Text(
            'A taller inbox bubble with enough body copy to exceed the '
            '34px avatar column and verify split-row intrinsic layout.',
          ),
        ],
      ),
    ),
  );
}

/// Mirrors [CommentCard]: badge row + [IntrinsicHeight] avatar/bubble row.
Widget _inboxStyleCard(LabColors c) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          SizedBox(
            width: kCommentCardLeftColWidth,
            height: kCommentCardBadgeSize,
            child: Center(
              child: Container(
                width: kCommentCardBadgeSize,
                height: kCommentCardBadgeSize,
                color: c.white8,
              ),
            ),
          ),
          const SizedBox(width: kCommentCardColGap),
          const Expanded(
            child: SizedBox(height: kCommentCardBadgeSize),
          ),
        ],
      ),
      const SizedBox(height: 4),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: kCommentCardLeftColWidth,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    bottom: kCommentCardAvatarSize,
                    left: (kCommentCardLeftColWidth - 2) / 2,
                    width: 2,
                    child: ColoredBox(color: Colors.grey),
                  ),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: CircleAvatar(radius: 17),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kCommentCardColGap),
            Expanded(
              child: BubbleSwiper(
                c: c,
                replyIconInset: 8,
                child: _tallBubble(c),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('CommentCard split intrinsic row in ListView', (tester) async {
    final c = LabColors.dark();
    final errors = await _pump(tester, _inboxStyleCard(c));

    expect(
      errors,
      isEmpty,
      reason: errors.map((e) => e.exception).join('\n'),
    );
  });

  testWidgets('many inbox-style cards in ListView without layout errors',
      (tester) async {
    final c = LabColors.dark();
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [c]),
        home: Scaffold(
          body: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: 12,
            separatorBuilder: (_, __) =>
                const SizedBox(height: kCommentCardListGap),
            itemBuilder: (_, __) => _inboxStyleCard(c),
          ),
        ),
      ),
    );
    await tester.pump();
    FlutterError.onError = old;

    expect(
      errors,
      isEmpty,
      reason: errors.map((e) => e.exception).join('\n'),
    );
  });
}
