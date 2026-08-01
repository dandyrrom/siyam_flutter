import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A tappable row that highlights with [AppColors.muted] while the cursor
/// is over it, tracked directly via [MouseRegion] rather than relying on
/// [InkWell.hoverColor] -- the ink hover overlay wasn't visibly rendering
/// in this app's environment even though the press/splash highlight did.
class HoverableRow extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const HoverableRow({super.key, required this.onTap, required this.child});

  @override
  State<HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<HoverableRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        color: _hovering ? AppColors.muted : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
