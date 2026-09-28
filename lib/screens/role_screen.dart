import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final roles = <(Role, String, String)>[
      (Role.labourer, t['roleLabourer'], t['roleLabourerDesc']),
      (Role.contractor, t['roleContractor'], t['roleContractorDesc']),
      (Role.client, t['roleClient'], t['roleClientDesc']),
      (Role.vendor, t['roleVendor'], t['roleVendorDesc']),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['whoAreYou'], style: T.screenTitle),
              const SizedBox(height: 6),
              Text(t['chooseRoleDesc'],
                  style: const TextStyle(fontSize: 13, color: C.textSecondary)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final (role, title, desc) = roles[i];
              return SurfaceCard(
                onTap: () => context.app.selectRole(role),
                child: Row(
                  children: [
                    Avatar(localInitial(title)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: C.text)),
                          const SizedBox(height: 2),
                          Text(desc, style: T.label),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFB7B3AA)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
