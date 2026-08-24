import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A single selectable option: the value it carries and the text shown for
/// it, both as a row in a flyout panel and (for [AppDropdown]/
/// [AppDropdownField], once picked) inside the trigger.
class AppDropdownOption<T> {
  final T value;
  final String label;
  const AppDropdownOption(this.value, this.label);
}

/// Flyout row shared by every popup in the app -- [AppDropdown],
/// [AppDropdownField], [AppMenuButton], and the hierarchical category
/// picker on InventoryPage -- so all of their panels look identical.
class AppDropdownMenuRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool hasChildren;

  const AppDropdownMenuRow({
    super.key,
    required this.label,
    required this.onTap,
    this.hasChildren = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            if (hasChildren)
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}

/// The flyout panel shell shared by every popup in the app: a white card
/// with rounded corners and a soft shadow, sized to [width].
Widget appDropdownFlyoutPanel({
  required double width,
  required List<Widget> rows,
}) {
  return Material(
    elevation: 6,
    borderRadius: BorderRadius.circular(16),
    color: AppColors.card,
    child: SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    ),
  );
}

/// The trigger chrome shared by toolbar filter dropdowns (Category, Stock
/// Level, ...) and the "New" split-action button.
class AppDropdownButton extends StatelessWidget {
  final String label;
  final bool expand;
  final IconData? leadingIcon;

  const AppDropdownButton({
    super.key,
    required this.label,
    this.expand = false,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(expand ? 28 : 16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 18),
            const SizedBox(width: 6),
          ],
          expand
              ? Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(fontSize: 14),
                ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}

/// Shared open/close/positioning plumbing for every flyout popup in the app.
///
/// ROUTE-SAFETY FIX:
/// - root overlays are removed in deactivate(), before the source route leaves
///   the widget tree;
/// - OverlayEntry is disposed after removal;
/// - the overlay subtree uses its own BuildContext, not the source page context;
/// - delayed positioning no longer registers a MediaQuery dependency.
mixin DropdownOverlayMixin<T extends StatefulWidget> on State<T> {
  final LayerLink dropdownLink = LayerLink();
  final GlobalKey _panelSizeKey = GlobalKey(debugLabel: 'SIYAM dropdown panel');

  OverlayEntry? _entry;
  Alignment _resolvedTargetAnchor = Alignment.topLeft;
  Alignment _resolvedFollowerAnchor = Alignment.topLeft;
  Offset _resolvedOffset = const Offset(0, 44);

  bool get isDropdownOpen => _entry != null;

  Widget buildFlyoutPanel(BuildContext context);

  Alignment get targetAnchor => Alignment.topLeft;
  Alignment get followerAnchor => Alignment.topLeft;

  @override
  void deactivate() {
    closeDropdown(rebuildTrigger: false);
    super.deactivate();
  }

  @override
  void dispose() {
    closeDropdown(rebuildTrigger: false);
    super.dispose();
  }

  void toggleDropdown() {
    if (isDropdownOpen) {
      closeDropdown();
    } else {
      openDropdown();
    }
  }

  void openDropdown() {
    if (!mounted || _entry != null) return;

    _resolvedTargetAnchor = targetAnchor;
    _resolvedFollowerAnchor = followerAnchor;
    _resolvedOffset = const Offset(0, 44);

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _buildOverlay(overlayContext),
    );

    _entry = entry;
    overlay.insert(entry);

    if (mounted) setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry != entry) return;
      _flipIfOffscreen();
    });
  }

  void closeDropdown({
    bool rebuildTrigger = true,
  }) {
    final entry = _entry;
    if (entry == null) return;

    // Clear first so any pending callback immediately sees the popup as closed.
    _entry = null;

    entry.remove();
    entry.dispose();

    if (rebuildTrigger && mounted) {
      setState(() {});
    }
  }

  void rebuildDropdown() {
    final entry = _entry;
    if (entry == null || !entry.mounted) return;
    entry.markNeedsBuild();
  }

  void _flipIfOffscreen() {
    if (!mounted || _entry == null) return;

    final triggerBox = context.findRenderObject();
    final panelBox = _panelSizeKey.currentContext?.findRenderObject();

    if (triggerBox is! RenderBox || !triggerBox.attached) return;
    if (panelBox is! RenderBox || !panelBox.attached) return;

    final triggerTopLeft = triggerBox.localToGlobal(Offset.zero);
    final triggerSize = triggerBox.size;
    final panelSize = panelBox.size;

    // Avoid MediaQuery.sizeOf(context) inside this delayed callback. That would
    // register a new inherited dependency while a route may be tearing down.
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;

    final view = views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;

    const margin = 8.0;
    var changed = false;

    if (_resolvedTargetAnchor.y < 0) {
      final spaceBelow =
          screenSize.height - (triggerTopLeft.dy + triggerSize.height);
      final spaceAbove = triggerTopLeft.dy;

      if (panelSize.height + margin > spaceBelow &&
          spaceAbove > spaceBelow) {
        _resolvedTargetAnchor =
            Alignment(_resolvedTargetAnchor.x, -1);
        _resolvedFollowerAnchor =
            Alignment(_resolvedFollowerAnchor.x, 1);
        _resolvedOffset = Offset(_resolvedOffset.dx, -8);
        changed = true;
      }
    }

    if (_resolvedTargetAnchor.x < 0) {
      final spaceRight = screenSize.width - triggerTopLeft.dx;

      if (panelSize.width + margin > spaceRight) {
        _resolvedTargetAnchor =
            Alignment(1, _resolvedTargetAnchor.y);
        _resolvedFollowerAnchor =
            Alignment(1, _resolvedFollowerAnchor.y);
        changed = true;
      }
    } else {
      final spaceLeft = triggerTopLeft.dx + triggerSize.width;

      if (panelSize.width + margin > spaceLeft) {
        _resolvedTargetAnchor =
            Alignment(-1, _resolvedTargetAnchor.y);
        _resolvedFollowerAnchor =
            Alignment(-1, _resolvedFollowerAnchor.y);
        changed = true;
      }
    }

    if (changed) rebuildDropdown();
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: closeDropdown,
          ),
        ),
        CompositedTransformFollower(
          link: dropdownLink,
          showWhenUnlinked: false,
          targetAnchor: _resolvedTargetAnchor,
          followerAnchor: _resolvedFollowerAnchor,
          offset: _resolvedOffset,
          child: KeyedSubtree(
            key: _panelSizeKey,
            child: buildFlyoutPanel(overlayContext),
          ),
        ),
      ],
    );
  }
}

/// Generic popup control shared by every dropdown and action-menu in the app.
class AppMenuButton<T> extends StatefulWidget {
  final Widget Function(BuildContext context, bool isOpen) triggerBuilder;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T> onSelected;
  final double menuWidth;
  final String? tooltip;
  final bool alignRight;

  const AppMenuButton({
    super.key,
    required this.triggerBuilder,
    required this.options,
    required this.onSelected,
    this.menuWidth = 200,
    this.tooltip,
    this.alignRight = false,
  });

  @override
  State<AppMenuButton<T>> createState() => _AppMenuButtonState<T>();
}

class _AppMenuButtonState<T> extends State<AppMenuButton<T>>
    with DropdownOverlayMixin<AppMenuButton<T>> {
  void _select(T value) {
    // Remove the overlay before the callback is allowed to rebuild/navigate.
    closeDropdown();

    if (!mounted) return;

    widget.onSelected(value);
  }

  @override
  Alignment get targetAnchor =>
      widget.alignRight ? Alignment.topRight : Alignment.topLeft;

  @override
  Alignment get followerAnchor =>
      widget.alignRight ? Alignment.topRight : Alignment.topLeft;

  @override
  Widget buildFlyoutPanel(BuildContext context) {
    return appDropdownFlyoutPanel(
      width: widget.menuWidth,
      rows: [
        for (final option in widget.options)
          AppDropdownMenuRow(
            label: option.label,
            onTap: () => _select(option.value),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final trigger = CompositedTransformTarget(
      link: dropdownLink,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: toggleDropdown,
        child: widget.triggerBuilder(context, isDropdownOpen),
      ),
    );

    return widget.tooltip == null
        ? trigger
        : Tooltip(
            message: widget.tooltip!,
            child: trigger,
          );
  }
}

/// Single-column select dropdown.
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T> onSelect;
  final bool expand;

  const AppDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.onSelect,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppMenuButton<T>(
      options: options,
      onSelected: onSelect,
      triggerBuilder: (context, isOpen) =>
          AppDropdownButton(
        label: label,
        expand: expand,
      ),
    );
  }
}

/// Form-integrated version of [AppDropdown].
class AppDropdownField<T> extends FormField<T> {
  AppDropdownField({
    super.key,
    required String label,
    super.initialValue,
    String? placeholder,
    required List<AppDropdownOption<T>> options,
    required ValueChanged<T> onChanged,
    super.validator,
  }) : super(
          builder: (state) {
            final selected = state.value == null
                ? null
                : options.firstWhere(
                    (option) => option.value == state.value,
                    orElse: () => options.first,
                  );

            return AppMenuButton<T>(
              options: options,
              onSelected: (value) {
                state.didChange(value);
                onChanged(value);
              },
              triggerBuilder: (context, isOpen) => InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  errorText: state.errorText,
                  suffixIcon: const Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                  ),
                ),
                isEmpty: false,
                isFocused: isOpen,
                child: Text(
                  selected?.label ?? placeholder ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: selected == null
                        ? AppColors.mutedForeground
                        : null,
                  ),
                ),
              ),
            );
          },
        );
}
