import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../backend/models.dart';
import '../theme.dart';
import 'common.dart';

/// [Avatar] for another user when the screen has only their id: shows their
/// uploaded profile photo once their public profile loads, initials until
/// then (and for anyone who never added a photo).
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.size = 44,
  });
  final String uid;
  final String name;
  final double size;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  late Future<UserDoc?> _profile = context.app.publicProfile(widget.uid);

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _profile = context.app.publicProfile(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserDoc?>(
        future: _profile,
        builder: (context, snapshot) => Avatar(initialsOf(widget.name),
            size: widget.size, imagePath: snapshot.data?.photoUrl),
      );
}

/// A profile [Avatar] that opens the photo full-size when tapped, so a hirer
/// can actually see who they are about to call — a 76px circle is too small
/// to recognise someone by.
class ProfilePhotoAvatar extends StatelessWidget {
  const ProfilePhotoAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.size = 76,
  });
  final String name;
  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = Avatar(initialsOf(name), size: size, imagePath: photoUrl);
    if (!photoUrl.startsWith('http')) return avatar;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: InteractiveViewer(
              child: Image.network(photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 40))),
            ),
          ),
        ),
      ),
      child: avatar,
    );
  }
}
