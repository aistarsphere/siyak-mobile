import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/siyag_theme.dart';

/// `whileTap={{ scale: 0.97 }}` press feedback from the reference (motion/react).
class SiyagTap extends StatefulWidget {
  const SiyagTap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<SiyagTap> createState() => _SiyagTapState();
}

class _SiyagTapState extends State<SiyagTap> {
  bool _down = false;
  void _set(bool v) => _down == v ? null : setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: SM.tap,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
