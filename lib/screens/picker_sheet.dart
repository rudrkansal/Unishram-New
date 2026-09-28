import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class PickerOption {
  final String id;
  final String label;
  final String? tag;
  const PickerOption(this.id, this.label, {this.tag});
}

/// The full-screen searchable picker used for skills, work types and states.
/// Single-select returns on tap; multi-select confirms with Done.
class PickerSheet extends StatefulWidget {
  const PickerSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.options,
    required this.selected,
    required this.multi,
    required this.emptyText,
    required this.doneLabel,
    this.skipLabel,
    this.maxSelection,
    this.maxSelectionMessage,
  });

  final String title;
  final String subtitle;
  final String searchHint;
  final List<PickerOption> options;
  final List<String> selected;
  final bool multi;
  final String emptyText;
  final String doneLabel;
  final String? skipLabel;
  final int? maxSelection;
  final String? maxSelectionMessage;

  static Future<List<String>?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String searchHint,
    required List<PickerOption> options,
    required List<String> selected,
    required bool multi,
    required String emptyText,
    required String doneLabel,
    String? skipLabel,
    int? maxSelection,
    String? maxSelectionMessage,
  }) {
    return Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PickerSheet(
          title: title,
          subtitle: subtitle,
          searchHint: searchHint,
          options: options,
          selected: selected,
          multi: multi,
          emptyText: emptyText,
          doneLabel: doneLabel,
          skipLabel: skipLabel,
          maxSelection: maxSelection,
          maxSelectionMessage: maxSelectionMessage,
        ),
      ),
    );
  }

  @override
  State<PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<PickerSheet> {
  late final List<String> _selected = [...widget.selected];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final rows = widget.options
        .where((o) =>
            _query.trim().isEmpty ||
            o.label.toLowerCase().contains(_query.trim().toLowerCase()) ||
            o.id.replaceAll('_', ' ').contains(_query.trim().toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: C.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoundIconButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 18, color: C.text),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 19,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                color: C.text)),
                        const SizedBox(height: 4),
                        Text(widget.subtitle,
                            style: const TextStyle(
                                fontSize: 13, color: C.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: AppTextField(
                initial: '',
                hint: widget.searchHint,
                fontSize: 15,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? EmptyNote(widget.emptyText)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _row(rows[i]),
                    ),
            ),
            if (widget.multi)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  color: C.appBg,
                  border: Border(top: BorderSide(color: Color(0xFFEAE7E0))),
                ),
                child: Column(
                  children: [
                    PrimaryButton(widget.doneLabel,
                        onTap: () => Navigator.of(context).pop(_selected)),
                    if (widget.skipLabel != null)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(<String>[]),
                        child: Text(widget.skipLabel!,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: C.accent)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(PickerOption o) {
    final on = _selected.contains(o.id);
    return InkWell(
      onTap: () => _toggle(o.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: on ? C.accentTint : C.surface,
          border:
              Border.all(color: on ? C.accent : C.border, width: on ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(o.label,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: C.text)),
            ),
            if (o.tag != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: C.accentTint,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(o.tag!,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: C.accent)),
              ),
              const SizedBox(width: 10),
            ],
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? C.accent : const Color(0xFFECEAE4),
                borderRadius: BorderRadius.circular(7),
              ),
              child: on
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String id) {
    if (!widget.multi) {
      Navigator.of(context).pop([id]);
      return;
    }
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        if (widget.maxSelection != null &&
            _selected.length >= widget.maxSelection!) {
          if (widget.maxSelectionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(widget.maxSelectionMessage!),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 2200),
              ),
            );
          }
          return;
        }
        _selected.add(id);
      }
    });
  }
}
