import 'package:flutter/material.dart';

import 'app_theme.dart';

class CompactBottomBar extends StatelessWidget {
  const CompactBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _destinations = [
    (
      key: 'tab-home',
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    (
      key: 'tab-storage',
      label: 'Lưu trữ',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
    ),
    (
      key: 'tab-discover',
      label: 'Khám phá',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            color: AppTheme.ink,
            borderRadius: BorderRadius.circular(32),
            child: SizedBox(
              key: const Key('bottom-bar-surface'),
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final focusedWidth = (constraints.maxWidth - 112) * 2 / 3;
                    final otherWidth =
                        (constraints.maxWidth - focusedWidth) / 2;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          key: const Key('tab-focus-indicator'),
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          left: selectedIndex * otherWidth,
                          top: 0,
                          width: focusedWidth,
                          height: constraints.maxHeight,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(26),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (index, destination)
                                in _destinations.indexed)
                              AnimatedContainer(
                                duration: duration,
                                curve: Curves.easeOutCubic,
                                width: selectedIndex == index
                                    ? focusedWidth
                                    : otherWidth,
                                child: Semantics(
                                  label: destination.label,
                                  button: true,
                                  selected: selectedIndex == index,
                                  child: Tooltip(
                                    message: destination.label,
                                    child: InkWell(
                                      key: ValueKey(destination.key),
                                      borderRadius: BorderRadius.circular(26),
                                      splashFactory: NoSplash.splashFactory,
                                      overlayColor:
                                          const WidgetStatePropertyAll(
                                            Colors.transparent,
                                          ),
                                      enableFeedback: false,
                                      onTap: () => onSelected(index),
                                      child: ExcludeSemantics(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  AnimatedSwitcher(
                                                    duration: duration,
                                                    child: Icon(
                                                      selectedIndex == index
                                                          ? destination
                                                                .selectedIcon
                                                          : destination.icon,
                                                      key: ValueKey(
                                                        selectedIndex == index,
                                                      ),
                                                      size: 30,
                                                      color:
                                                          selectedIndex == index
                                                          ? AppTheme.ink
                                                          : const Color(
                                                              0xFFCCCCCC,
                                                            ),
                                                    ),
                                                  ),
                                                  AnimatedSize(
                                                    duration: duration,
                                                    curve: Curves.easeOutCubic,
                                                    child:
                                                        selectedIndex == index
                                                        ? Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 8,
                                                                ),
                                                            child: Text(
                                                              destination.label,
                                                              style: const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: AppTheme
                                                                    .ink,
                                                              ),
                                                            ),
                                                          )
                                                        : const SizedBox.shrink(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
