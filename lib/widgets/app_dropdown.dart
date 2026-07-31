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
              child: Text(label,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
            ),
            if (hasChildren)
              const Icon(Icons.chevron_right, size: 16, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// The flyout panel shell shared by every popup in the app: a white card
/// with rounded corners and a soft shadow, sized to [width].
Widget appDropdownFlyoutPanel({required double width, required List<Widget> rows}) {
  return Material(
    elevation: 6,
    borderRadius: BorderRadius.circular(16),
    color: AppColors.card,
    child: SizedBox(
      width: width,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    ),
  );
}

/// The trigger chrome shared by toolbar filter dropdowns (Category, Stock
/// Level, ...) and the "New" split-action button: a bordered, rounded box
/// showing [label] with a trailing caret and an optional [leadingIcon].
/// [expand] fills the parent's width (for a dropdown sitting alongside
/// full-width text fields) instead of hugging the label's width (for
/// compact toolbar filters). Purely presentational -- wrap in your own
/// [InkWell]/[GestureDetector] for tap handling (see [AppMenuButton]).
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
                  child: Text(label,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)))
              : Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}

/// Shared open/close/positioning plumbing for every flyout popup in the
/// app. Mix into a [State] and implement [buildFlyoutPanel]; call
/// [toggleDropdown] from the trigger and wrap the trigger in
/// [CompositedTransformTarget] with [dropdownLink].
///
/// Uses a manual [OverlayEntry] rather than [MenuAnchor]/[SubmenuButton] --
/// those throw a RenderBox layout assertion on web when their anchor sits
/// inside a [Wrap] (https://github.com/flutter/flutter/issues/131843).
mixin DropdownOverlayMixin<T extends StatefulWidget> on State<T> {
  final LayerLink dropdownLink = LayerLink();
  OverlayEntry? _entry;

  bool get isDropdownOpen => _entry != null;

  /// The flyout panel's content, positioned automatically under the
  /// trigger. Wrap the selectable rows in [appDropdownFlyoutPanel] (or a
  /// [Material] with the same look) -- see [AppMenuButton] for the standard
  /// single-column case.
  Widget buildFlyoutPanel(BuildContext context);

  /// Where on the trigger the panel is anchored, and which corner of the
  /// panel sits there -- override both to flip a panel leftward (e.g. for
  /// a trigger near the right edge of the screen, so the panel doesn't
  /// overflow off-screen) instead of the default left-aligned drop-down.
  Alignment get targetAnchor => Alignment.topLeft;
  Alignment get followerAnchor => Alignment.topLeft;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void toggleDropdown() => isDropdownOpen ? closeDropdown() : openDropdown();

  void openDropdown() {
    _entry = OverlayEntry(builder: (context) => _buildOverlay());
    // rootOverlay: true -- pages that use this live inside go_router's
    // ShellRoute, which owns a nested Navigator/Overlay scoped to the
    // scrollable page body. Inserting there clips the flyout to that body
    // instead of the full screen; the app's outermost Overlay doesn't have
    // that constraint.
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void closeDropdown() {
    _entry?.remove();
    _entry = null;
  }

  void rebuildDropdown() => _entry?.markNeedsBuild();

  Widget _buildOverlay() {
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
          targetAnchor: targetAnchor,
          followerAnchor: followerAnchor,
          offset: const Offset(0, 44),
          child: buildFlyoutPanel(context),
        ),
      ],
    );
  }
}

/// Generic popup control shared by every dropdown and action-menu in the
/// app. [triggerBuilder] renders the clickable element -- an outlined box
/// ([AppDropdownButton]), a bare icon, a filled CTA button, a form-field
/// box -- and receives whether the panel is currently open (e.g. to show a
/// focused-style border). Tapping it opens [options] in the same flyout
/// panel style used everywhere else in the app.
class AppMenuButton<T> extends StatefulWidget {
  final Widget Function(BuildContext context, bool isOpen) triggerBuilder;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T> onSelected;
  final double menuWidth;
  final String? tooltip;

  const AppMenuButton({
    super.key,
    required this.triggerBuilder,
    required this.options,
    required this.onSelected,
    this.menuWidth = 200,
    this.tooltip,
  });

  @override
  State<AppMenuButton<T>> createState() => _AppMenuButtonState<T>();
}

class _AppMenuButtonState<T> extends State<AppMenuButton<T>>
    with DropdownOverlayMixin<AppMenuButton<T>> {
  void _select(T value) {
    widget.onSelected(value);
    setState(closeDropdown);
  }

  @override
  Widget buildFlyoutPanel(BuildContext context) {
    return appDropdownFlyoutPanel(
      width: widget.menuWidth,
      rows: [
        for (final o in widget.options)
          AppDropdownMenuRow(label: o.label, onTap: () => _select(o.value)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final trigger = CompositedTransformTarget(
      link: dropdownLink,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(toggleDropdown),
        child: widget.triggerBuilder(context, isDropdownOpen),
      ),
    );
    return widget.tooltip == null ? trigger : Tooltip(message: widget.tooltip, child: trigger);
  }
}

/// Single-column select dropdown: an [AppDropdownButton] trigger that opens
/// a flat list of [options]. Used for toolbar filters (nullable "All X"
/// style, e.g. Category/Stock Level on Inventory, Species/Status filters).
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
          AppDropdownButton(label: label, expand: expand),
    );
  }
}

/// Form-integrated version of [AppDropdown]: renders as a real
/// [InputDecorator] (the same label/border/error chrome every
/// [TextFormField] and [SearchSelectField] in the app uses, driven by the
/// shared [InputDecorationTheme]) so it lines up pixel-for-pixel with
/// sibling text fields instead of adding its own label row above a
/// differently-shaped box. Wires validation/error display through
/// [FormField], so it drops into a [Form] exactly like a
/// [DropdownButtonFormField] did. Pass the field's default in
/// [initialValue], or leave it null (with [placeholder] text) to start
/// blank -- e.g. a Stock In form opened with no preselected type.
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
                    (o) => o.value == state.value,
                    orElse: () => options.first,
                  );
            return AppMenuButton<T>(
              options: options,
              onSelected: (v) {
                state.didChange(v);
                onChanged(v);
              },
              triggerBuilder: (context, isOpen) => InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  errorText: state.errorText,
                  suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
                ),
                isEmpty: false,
                isFocused: isOpen,
                child: Text(
                  selected?.label ?? placeholder ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: selected == null ? AppColors.mutedForeground : null,
                  ),
                ),
              ),
            );
          },
        );
}
