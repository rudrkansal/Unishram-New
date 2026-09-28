import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// Renders a Firestore stream with the three states a list can be in. Keeps
/// every feed screen from re-implementing loading and error handling.
class FeedBuilder<T> extends StatelessWidget {
  const FeedBuilder({
    super.key,
    required this.stream,
    required this.builder,
    required this.emptyText,
    this.errorText,
  });

  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, List<T> items) builder;
  final String emptyText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyNote(errorText ?? 'Could not load. Pull down to retry.');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: C.accent),
              ),
            ),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) return EmptyNote(emptyText);
        return builder(context, items);
      },
    );
  }
}
