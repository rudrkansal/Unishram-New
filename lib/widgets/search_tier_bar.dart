import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// The "Showing: X — Widen search" bar shown above every people/job search
/// list. Replaces the old fixed 10km/25km/city chip picker with a single
/// progressive ladder: City → Nearby (50km, crosses state lines) → State →
/// All India. Shared by ContractorFind, LabourerHome and ClientSearch, each
/// passing in the tier they own on [AppState].
class SearchTierBar extends StatelessWidget {
  const SearchTierBar({
    super.key,
    required this.tier,
    required this.onWiden,
    required this.onReset,
    this.baseTier = SearchTier.city,
  });
  final SearchTier tier;
  final VoidCallback onWiden;
  final VoidCallback onReset;
  /// What [onReset] actually resets back to — City for contractor/client,
  /// Nearby for a labourer (who has no City step at all). The reset
  /// button's label is derived from this, so it never claims to go
  /// "back to city" when it's really going back to Nearby.
  final SearchTier baseTier;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: '${t['showingLabel']}: ',
                      style: const TextStyle(
                          fontSize: 12.5, color: C.mutedSoft)),
                  TextSpan(
                    text: _tierLabel(app, t, tier),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: C.text),
                  ),
                ],
              ),
            ),
          ),
          if (tier.isWidest)
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(
                  '${t['resetToCity']}: ${_tierLabel(app, t, baseTier)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
            ),
          if (!tier.isWidest)
            TextButton(
              onPressed: onWiden,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('${t['widenSearch']} ›',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: C.accent)),
            ),
        ],
      ),
    );
  }

  static String _tierLabel(AppState app, Str t, SearchTier tier) {
    switch (tier) {
      case SearchTier.city:
        return app.lp.city.isEmpty ? t['searchTierCityFallback'] : app.lp.city;
      case SearchTier.nearby:
        return t['searchTierNearby'];
      case SearchTier.state:
        return app.lp.state.isEmpty
            ? t['searchTierState']
            : '${t['searchTierState']} ${app.lp.state}';
      case SearchTier.allIndia:
        return t['searchTierAllIndia'];
    }
  }
}
