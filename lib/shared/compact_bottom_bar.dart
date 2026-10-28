import 'package:flutter/material.dart';

import 'app_theme.dart';

class CompactBottomBar extends StatefulWidget {
  const CompactBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<CompactBottomBar> createState() => _CompactBottomBarState();
}

class _CompactBottomBarState extends State<CompactBottomBar> {
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
  static const _duration = Duration(milliseconds: 320);
  final _tapTicks = [0, 0, 0];

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: AppTheme.ink,
              borderRadius: BorderRadius.circular(32),
              child: SizedBox(
                height: 60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Previous focused tab filled all width left by two 56px tabs.
                      final focusWidth = (constraints.maxWidth - 112) * 2 / 3;
                      final otherWidth =
                          (constraints.maxWidth - focusWidth) / 2;
                      final index = widget.selectedIndex;
                      final focusLeft = index == 0
                          ? 0.0
                          : index == 1
                          ? otherWidth
                          : otherWidth * 2;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            key: const Key('tab-focus-indicator'),
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            left: focusLeft,
                            top: 0,
                            width: focusWidth,
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
                              for (final (index, _) in _destinations.indexed)
                                AnimatedContainer(
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  width: index == widget.selectedIndex
                                      ? focusWidth
                                      : otherWidth,
                                  child: _tab(context, index, duration),
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
      ),
    );
  }

  Widget _tab(BuildContext context, int index, Duration duration) {
    final destination = _destinations[index];
    final selected = widget.selectedIndex == index;
    return Semantics(
      label: destination.label,
      button: true,
      selected: selected,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          key: ValueKey(destination.key),
          borderRadius: BorderRadius.circular(26),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          enableFeedback: false,
          onTap: () {
            setState(() => _tapTicks[index]++);
            widget.onSelected(index);
          },
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey('tab-icon-$index-${_tapTicks[index]}'),
                        tween: Tween(begin: .82, end: 1),
                        duration: duration,
                        curve: Curves.easeOutBack,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: AnimatedSwitcher(
                          duration: duration,
                          child: Icon(
                            selected
                                ? destination.selectedIcon
                                : destination.icon,
                            key: ValueKey(selected),
                            size: selected ? 28 : 30,
                            color: selected
                                ? AppTheme.ink
                                : const Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        child: selected
                            ? Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  destination.label,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppTheme.ink,
                                        fontSize: 14,
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
    );
  }
}
