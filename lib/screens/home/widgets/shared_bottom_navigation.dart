import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moodgenie/l10n/app_localizations.dart';
import 'package:moodgenie/screens/home/widgets/nav_bar_item.dart';

class SharedBottomNavigation extends StatelessWidget {
  static const double _barContentHeight = 60;
  static const double _topPadding = 8;
  static const double _bottomPadding = 8;

  final int currentIndex;
  final Function(int) onTap;

  const SharedBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static double reservedHeight(BuildContext context) {
    return _barContentHeight + _topPadding + _bottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Semantics(
        container: true,
        label: l10n.navigationBarLabel,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                _topPadding,
                12,
                _bottomPadding,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                height: _barContentHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    NavBarItem(
                      icon: Icons.home_rounded,
                      label: l10n.navHome,
                      tooltip: l10n.navTabTooltip(l10n.navHome),
                      semanticHint: currentIndex == 0
                          ? l10n.navCurrentTabHint
                          : l10n.navSwitchTabHint(l10n.navHome),
                      isSelected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    NavBarItem(
                      icon: Icons.emoji_emotions_outlined,
                      label: l10n.navMood,
                      tooltip: l10n.navTabTooltip(l10n.navMood),
                      semanticHint: currentIndex == 1
                          ? l10n.navCurrentTabHint
                          : l10n.navSwitchTabHint(l10n.navMood),
                      isSelected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    NavBarItem(
                      icon: Icons.chat_bubble_rounded,
                      label: l10n.navChat,
                      tooltip: l10n.navTabTooltip(l10n.navChat),
                      semanticHint: currentIndex == 2
                          ? l10n.navCurrentTabHint
                          : l10n.navSwitchTabHint(l10n.navChat),
                      isSelected: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                    NavBarItem(
                      icon: Icons.medical_services_outlined,
                      label: l10n.navTherapist,
                      tooltip: l10n.navTabTooltip(l10n.navTherapist),
                      semanticHint: currentIndex == 3
                          ? l10n.navCurrentTabHint
                          : l10n.navSwitchTabHint(l10n.navTherapist),
                      isSelected: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
