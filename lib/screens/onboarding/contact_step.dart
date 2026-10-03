import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../terms_screens.dart';
import 'step_scaffold.dart';
import 'work_step.dart';

/// Step 3 — mobile verification, a face photo, and work photos.
class ContactStep extends StatelessWidget {
  const ContactStep({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;

    return StepScaffold(
      title: t['lpTitle3'],
      stepIndex: 2,
      stepCount: 3,
      speakText: '${t['lpTitle3']}. ${t['phoneNumber']}. ${t['profilePhoto']}',
      footer: PrimaryButton(
        t[app.editingProfile ? 'updateProfile' : 'completeProfile'],
        enabled: AppState.canCompleteProfile(
            stepValid: app.contactValid,
            termsChecked: app.termsChecked,
            termsCurrent: app.termsCurrent),
        onTap: () => context.app.completeProfile(),
      ),
      children: [
        const PhoneVerificationBlock(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t['profilePhotoOptional'],
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: C.textMid)),
            const SizedBox(height: 3),
            Text(t['profilePhotoSub'], style: T.caption),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final files = await pickPhotos(context, t: t);
                if (files.isNotEmpty && context.mounted) {
                  context.app.setProfilePhoto(files.first);
                }
              },
              child: Row(
                children: [
                  if (lp.profilePicture.isEmpty)
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: C.surfaceMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.borderDashed, width: 1.5),
                      ),
                      child: const Icon(Icons.photo_camera_outlined,
                          size: 26, color: C.muted),
                    )
                  else
                    Avatar('', size: 72, imagePath: lp.profilePicture),
                  const SizedBox(width: 14),
                  Text(
                    lp.profilePicture.isEmpty
                        ? t['addPhoto']
                        : t['changePhoto'],
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: C.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t['workPhotos'],
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: C.textMid)),
            const SizedBox(height: 3),
            Text(t['workPhotosSub'], style: T.caption),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i < lp.workPhotos.length; i++)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: WorkPhotoTile(path: lp.workPhotos[i]),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: InkWell(
                          onTap: () => context.app
                              .update(() => lp.workPhotos.removeAt(i)),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (lp.workPhotos.length < 6)
                  InkWell(
                    onTap: () async {
                      final files = await pickPhotos(context,
                          t: t, allowMultiple: true);
                      if (files.isNotEmpty && context.mounted) {
                        context.app.addWorkPhotos(files);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: C.surface,
                        border: Border.all(color: C.borderDashed, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: C.accent),
                          const SizedBox(height: 2),
                          Text(t['addPhoto'],
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: C.accent)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        // The very last thing before "Complete profile": accepting the Terms.
        const TermsConsentCheck(),
      ],
    );
  }
}
