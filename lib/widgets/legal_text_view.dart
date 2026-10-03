import 'package:flutter/material.dart';

import '../theme.dart';

/// Renders the small markdown subset used by the Terms and Privacy Policy
/// (`# title`, `## heading`, `- bullet`, blank-line paragraphs, `**bold**`),
/// readable on a phone without any extra dependency.
class LegalTextView extends StatelessWidget {
  const LegalTextView(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(line.substring(2),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: C.text)),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(line.substring(3),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: C.text)),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ',
                  style: TextStyle(fontSize: 14, height: 1.45, color: C.text)),
              Expanded(child: _rich(line.substring(2))),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _rich(line),
        ));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  static const _base = TextStyle(fontSize: 14, height: 1.45, color: C.text);

  Widget _rich(String s) {
    final spans = <TextSpan>[];
    final parts = s.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
          text: parts[i],
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null));
    }
    return Text.rich(TextSpan(style: _base, children: spans));
  }
}
