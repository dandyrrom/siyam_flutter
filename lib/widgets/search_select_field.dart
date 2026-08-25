import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// A "Type, Search, Select[, Add]" field (see the app's TSS/TSSA input
/// convention): a text field that filters [options] as the user types
/// and lists matches in a dropdown below. Selecting one fires
/// [onSelected]. If [onAddNew] is set, a pinned "+ Add new" row is
/// always shown at the top of the dropdown (TSSA); otherwise only
/// matches are listed (TSS).
///
/// This renders a [TextFormField] under the hood, so it participates in
/// the enclosing [Form]'s validation exactly like any other form field.
///
/// IMPORTANT (Flutter Web / AlertDialog):
/// This widget intentionally does not use LayoutBuilder. AlertDialog performs
/// intrinsic-size calculations, and LayoutBuilder cannot provide intrinsic
/// dimensions. Using LayoutBuilder here caused the rendering assertion:
/// "LayoutBuilder does not support returning intrinsic dimensions."
///
/// The autocomplete field's actual laid-out width is measured instead when
/// the options overlay is built. This keeps the dropdown aligned with the
/// field while remaining safe inside AlertDialog and other intrinsically-sized
/// parents.
class SearchSelectField<T extends Object> extends StatefulWidget {
  final String labelText;
  final TextEditingController? controller;
  final String? initialText;
  final List<T> options;
  final String Function(T) displayStringForOption;
  final ValueChanged<T> onSelected;
  final ValueChanged<String>? onTextChanged;
  final VoidCallback? onAddNew;
  final String addNewLabel;
  final String? Function(String?)? validator;
  final bool autofocus;

  /// Keeps long result lists inside a predictable dropdown instead of
  /// allowing the overlay to grow down the entire screen.
  final double maxOptionsHeight;

  const SearchSelectField({
    super.key,
    required this.labelText,
    this.controller,
    this.initialText,
    required this.options,
    required this.displayStringForOption,
    required this.onSelected,
    this.onTextChanged,
    this.onAddNew,
    this.addNewLabel = '+ Add new',
    this.validator,
    this.autofocus = false,
    this.maxOptionsHeight = 240,
  });

  @override
  State<SearchSelectField<T>> createState() =>
      _SearchSelectFieldState<T>();
}

class _SearchSelectFieldState<T extends Object>
    extends State<SearchSelectField<T>> {
  late final TextEditingController _controller =
      widget.controller ??
          TextEditingController(
            text: widget.initialText ?? '',
          );

  final FocusNode _focusNode = FocusNode();
  final ScrollController _optionsScrollController = ScrollController();

  /// Used only to read the already-laid-out width of the actual text field.
  /// Measuring after layout avoids intrinsic-size requests entirely.
  final GlobalKey _fieldKey = GlobalKey();

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }

    _focusNode.dispose();
    _optionsScrollController.dispose();

    super.dispose();
  }

  double _overlayWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final availableScreenWidth =
        screenWidth > 32 ? screenWidth - 32 : screenWidth;

    final renderObject =
        _fieldKey.currentContext?.findRenderObject();

    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.size.width.isFinite &&
        renderObject.size.width > 0) {
      final fieldWidth = renderObject.size.width;

      return fieldWidth > availableScreenWidth
          ? availableScreenWidth
          : fieldWidth;
    }

    // Safe fallback for the very first overlay frame if the field's render box
    // is not measurable yet. In normal use the field is already laid out before
    // RawAutocomplete opens its options overlay.
    return availableScreenWidth < 320
        ? availableScreenWidth
        : 320;
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: widget.displayStringForOption,
      optionsViewOpenDirection: OptionsViewOpenDirection.down,
      optionsBuilder: (textValue) {
        final query = textValue.text.trim().toLowerCase();

        if (query.isEmpty) {
          return widget.options;
        }

        return widget.options.where(
          (option) => widget
              .displayStringForOption(option)
              .toLowerCase()
              .contains(query),
        );
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        return TextFormField(
          key: _fieldKey,
          controller: controller,
          focusNode: focusNode,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            labelText: widget.labelText,
          ),
          validator: widget.validator,
          onChanged: widget.onTextChanged,
        );
      },
      optionsViewBuilder: (
        context,
        onSelectedCb,
        optionsList,
      ) {
        final list = optionsList.toList();

        if (list.isEmpty && widget.onAddNew == null) {
          return const SizedBox.shrink();
        }

        final overlayWidth = _overlayWidth(context);

        return Align(
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: const Offset(0, 6),
            child: Material(
              elevation: 6,
              shadowColor: Colors.black.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              color: AppColors.card,
              child: Container(
                width: overlayWidth,
                constraints: BoxConstraints(
                  maxHeight: widget.maxOptionsHeight,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Keep Add New pinned while the actual result list
                    // scrolls underneath it.
                    if (widget.onAddNew != null) ...[
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.add,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          widget.addNewLabel,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: widget.onAddNew,
                      ),
                      if (list.isNotEmpty)
                        const Divider(
                          height: 1,
                        ),
                    ],

                    if (list.isNotEmpty)
                      Flexible(
                        child: Scrollbar(
                          controller: _optionsScrollController,
                          thumbVisibility: true,
                          interactive: true,
                          child: ListView.separated(
                            controller: _optionsScrollController,
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            shrinkWrap: true,
                            itemCount: list.length,
                            separatorBuilder: (
                              context,
                              index,
                            ) =>
                                const Divider(
                              height: 1,
                            ),
                            itemBuilder: (
                              context,
                              index,
                            ) {
                              final option = list[index];

                              return ListTile(
                                dense: true,
                                title: Text(
                                  widget.displayStringForOption(option),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => onSelectedCb(option),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
