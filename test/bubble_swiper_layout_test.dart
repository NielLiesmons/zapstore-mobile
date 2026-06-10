import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/community/comment_card.dart';
import 'package:zapstore/widgets/social/bubble_swiper.dart';

void main() {
  testWidgets('BubbleSwiper lays out inside stack-overlay inbox row',
      (tester) async {
    final c = LabColors.dark();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [c]),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final rightWidth = constraints.maxWidth -
                      kCommentCardLeftColWidth -
                      kCommentCardColGap;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: kCommentCardLeftColWidth),
                          const SizedBox(width: kCommentCardColGap),
                          SizedBox(
                            width: rightWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 28),
                                const SizedBox(height: 4),
                                BubbleSwiper(
                                  c: c,
                                  replyIconInset: 8,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: rightWidth,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(11),
                                      color: c.gray66,
                                      child: const Text('Hello inbox'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
