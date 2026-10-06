import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/strings.dart';
import '../theme.dart';

/// Places a real dial to an Indian mobile number. Shared by every "Call"
/// action so the sheet, applicants list, etc. dial the same way.
Future<void> dialPhone(String phone) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return;
  final uri = Uri.parse('tel:+91$digits');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

/// Shows a bottom sheet offering "take a photo" / "choose from gallery",
/// every time — so users always get both options regardless of which one
/// they picked last. Returns the picked file paths, or an empty list if
/// cancelled.
Future<List<String>> pickPhotos(
  BuildContext context, {
  required Str t,
  bool allowMultiple = false,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: C.accent),
              title: Text(t['takePhoto']),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: C.accent),
              title: Text(t['chooseFromGallery']),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 4),
            ListTile(
              title: Center(child: Text(t['cancel'])),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return const [];

  final picker = ImagePicker();
  if (source == ImageSource.gallery && allowMultiple) {
    final files = await picker.pickMultiImage(imageQuality: 80);
    return files.map((f) => f.path).toList();
  }
  final file = await picker.pickImage(
    source: source,
    preferredCameraDevice: CameraDevice.front,
    imageQuality: 80,
  );
  return file == null ? const [] : [file.path];
}

/// A text field that owns its controller, so a rebuild never moves the cursor.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.keyboardType,
    this.digitsOnly = false,
    this.maxLength,
    this.maxLines = 1,
    this.letterSpacing,
    this.fontSize = 16,
    this.onEditingComplete,
    this.textAlign = TextAlign.start,
    this.controller,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
  });

  /// Lets a caller read the live text (including any not-yet-committed
  /// keyboard composition) instead of waiting for [onChanged].
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextInputType? keyboardType;
  final bool digitsOnly;
  final int? maxLength;
  final int maxLines;
  final double? letterSpacing;
  final double fontSize;
  final VoidCallback? onEditingComplete;
  final TextAlign textAlign;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _c =
      widget.controller ?? TextEditingController(text: widget.initial);
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onEditingComplete?.call();
    });
  }

  @override
  void didUpdateWidget(AppTextField old) {
    super.didUpdateWidget(old);
    // Adopt values the app itself changed (a clamped wage, a resolved PIN)
    // without disturbing text the user is actively typing.
    if (widget.initial != _c.text && !_focus.hasFocus) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      textAlign: widget.textAlign,
      inputFormatters: [
        if (widget.digitsOnly) FilteringTextInputFormatter.digitsOnly,
        if (widget.maxLength != null)
          LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      style: TextStyle(
        fontSize: widget.fontSize,
        color: C.text,
        letterSpacing: widget.letterSpacing,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: const TextStyle(color: C.muted, fontSize: 15),
        filled: true,
        fillColor: C.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: _border(C.borderStrong),
        enabledBorder: _border(C.borderStrong),
        focusedBorder: _border(C.accent),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: color, width: color == C.accent ? 1.5 : 1),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label,
      {super.key, this.onTap, this.enabled = true, this.icon});

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final on = enabled && onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      child: InkWell(
        onTap: on ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? C.accent : C.border,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : C.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton(this.label, {super.key, this.onTap, this.icon});
  final String label;
  final VoidCallback? onTap;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 54),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: C.surface,
          border: Border.all(color: C.accent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 9)],
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: C.accent)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill/chip with a 44px minimum tap target.
class Pill extends StatelessWidget {
  const Pill(this.label,
      {super.key, this.selected = false, this.onTap, this.compact = false});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 40 : 44),
        padding:
            EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? C.accentTint : C.surface,
          border: Border.all(
              color: selected ? C.accent : C.border, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? C.accent : C.textMid,
          ),
        ),
      ),
    );
  }
}

/// The solid filter chip used on list screens.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill(this.label,
      {super.key, required this.active, this.onTap});
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? C.accent : C.surfaceMuted,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? Colors.white : C.textMid,
            )),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: C.surface,
          border: Border.all(color: C.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.text, {super.key, this.size = 44, this.imagePath});
  final String text;
  final double size;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final image =
        imagePath == null || imagePath!.isEmpty ? null : _fileImage(imagePath!);
    if (image != null) {
      return ClipOval(
        child: Image(
          image: image,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration:
            const BoxDecoration(color: C.accentTint, shape: BoxShape.circle),
        child: Text(text,
            style: TextStyle(
                fontSize: size * 0.33,
                fontWeight: FontWeight.w700,
                color: C.accent)),
      );
}

ImageProvider? _fileImage(String path) {
  if (path.startsWith('http')) return NetworkImage(path);
  // Local file paths only exist on a device; on web there is nothing to read.
  if (kIsWeb) return null;
  return FileImage(File(path));
}

class BadgePill extends StatelessWidget {
  const BadgePill(this.label,
      {super.key, required this.background, required this.color});
  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(100)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.sub, this.required = false});
  final String text;
  final String? sub;
  final bool required;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: C.text)),
              ),
              if (required) const Text(' *', style: TextStyle(color: C.warn)),
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(sub!, style: T.caption),
          ],
        ],
      );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: C.textMid)),
      );
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton(
      {super.key,
      required this.child,
      this.onTap,
      this.background = C.surfaceMuted,
      this.tooltip});
  final Widget child;
  final VoidCallback? onTap;
  final Color background;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: child,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The speaker glyph used by the Listen button; the wave arcs brighten while
/// speech is playing.
class SpeakerIcon extends StatelessWidget {
  const SpeakerIcon(
      {super.key, this.active = false, this.size = 20, this.color = C.accent});
  final bool active;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _SpeakerPainter(active: active, color: color),
      );
}

class _SpeakerPainter extends CustomPainter {
  _SpeakerPainter({required this.active, required this.color});
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final body = Path()
      ..moveTo(4 * s, 9.5 * s)
      ..lineTo(7.2 * s, 9.5 * s)
      ..lineTo(12 * s, 5.5 * s)
      ..lineTo(12 * s, 18.5 * s)
      ..lineTo(7.2 * s, 14.5 * s)
      ..lineTo(4 * s, 14.5 * s)
      ..close();
    canvas.drawPath(body, Paint()..color = color);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round;

    stroke.color = color.withOpacity(active ? 1 : 0.45);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: 5.2 * s),
        -0.7,
        1.4,
        false,
        stroke);
    stroke.color = color.withOpacity(active ? 1 : 0.25);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: 8.4 * s),
        -0.8,
        1.6,
        false,
        stroke);
  }

  @override
  bool shouldRepaint(_SpeakerPainter old) =>
      old.active != active || old.color != color;
}

class CheckRow extends StatelessWidget {
  const CheckRow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
            color: C.okBg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.check, size: 16, color: C.ok),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: C.ok)),
            ),
          ],
        ),
      );
}

class WarningNote extends StatelessWidget {
  const WarningNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: C.warnBg,
          border: Border.all(color: C.warnBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 17, color: C.warn),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: C.warn)),
            ),
          ],
        ),
      );
}

class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(count, (i) {
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: i <= index ? C.accent : C.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          );
        }),
      );
}

class WageBar extends StatelessWidget {
  const WageBar({super.key, required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: LinearProgressIndicator(
          value: fraction.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: C.surfaceMuted,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 44),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: C.mutedSoft)),
      );
}

/// A work photo, from a device file or an uploaded URL.
class WorkPhotoTile extends StatelessWidget {
  const WorkPhotoTile({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final image = _fileImage(path);
    if (image == null) {
      return Container(color: C.surfaceMuted);
    }
    return Image(
      image: image,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: C.surfaceMuted),
    );
  }
}

/// A back arrow plus a title, for entry-tier screens reached from a menu
/// rather than the bottom nav (so they never get `AppHeader`'s chrome).
class ScreenBackHeader extends StatelessWidget {
  const ScreenBackHeader({super.key, required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
        child: Row(
          children: [
            RoundIconButton(
              onTap: onBack,
              child: const Icon(Icons.chevron_left, color: C.text),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
          ],
        ),
      );
}
