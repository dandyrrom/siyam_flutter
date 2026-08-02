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
  });

  @override
  State<SearchSelectField<T>> createState() => _SearchSelectFieldState<T>();
}

class _SearchSelectFieldState<T extends Object> extends State<SearchSelectField<T>> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialText ?? '');
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: widget.displayStringForOption,
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return widget.options;
        final q = textValue.text.toLowerCase();
        return widget.options
            .where((o) => widget.displayStringForOption(o).toLowerCase().contains(q));
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          autofocus: widget.autofocus,
          decoration: InputDecoration(labelText: widget.labelText),
          validator: widget.validator,
          onChanged: widget.onTextChanged,
        );
      },
      optionsViewBuilder: (context, onSelectedCb, optionsList) {
        final list = optionsList.toList();
        if (list.isEmpty && widget.onAddNew == null) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.card,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SizedBox(
                width: 320,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  children: [
                    if (widget.onAddNew != null)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.add, size: 18, color: AppColors.primary),
                        title: Text(widget.addNewLabel,
                            style: const TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.w600)),
                        onTap: widget.onAddNew,
                      ),
                    for (final option in list)
                      ListTile(
                        dense: true,
                        title: Text(widget.displayStringForOption(option)),
                        onTap: () => onSelectedCb(option),
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
