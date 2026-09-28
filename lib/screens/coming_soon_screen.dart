import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, this.showBack = true});
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = context.appWatch.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: RoundIconButton(
              onTap: () => context.app.goBack(),
              child: const Icon(Icons.chevron_left, color: C.text),
            ),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: 0.35,
                    child: Icon(Icons.engineering_outlined,
                        size: 72, color: C.text.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 14),
                  Text(t['comingSoonTitle'],
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: C.text)),
                  const SizedBox(height: 10),
                  Text(t['comingSoonBody'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14.5, color: C.mutedSoft, height: 1.4)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
