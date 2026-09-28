import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Shared chrome for the three onboarding steps: back, step counter, title,
/// a Listen button that reads the step aloud, progress dots, then content.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.title,
    required this.stepIndex,
    required this.stepCount,
    required this.children,
    required this.footer,
    this.speakText,
  });

  final String title;
  final int stepIndex;
  final int stepCount;
  final List<Widget> children;
  final Widget footer;
  final String? speakText;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoundIconButton(
                onTap: () => context.app.goBack(),
                child: const Icon(Icons.chevron_left, color: C.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t['stepWord']} ${stepIndex + 1} ${t['ofWord']} $stepCount',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: C.accent),
                    ),
                    const SizedBox(height: 3),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: C.text)),
                  ],
                ),
              ),
              if (app.voiceAvailable) ...[
                const SizedBox(width: 8),
                RoundIconButton(
                  tooltip: t['listen'],
                  onTap: () => context.speakAloud(speakText ?? title),
                  child: SpeakerIcon(active: app.speaking, size: 18),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: StepDots(count: stepCount, index: stepIndex),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 24),
              ]
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: C.appBg,
            border: Border(top: BorderSide(color: Color(0xFFEAE7E0))),
          ),
          child: footer,
        ),
      ],
    );
  }
}
