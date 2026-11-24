import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The web app has no ripples: a press just tints the surface, so the paper
/// stays flat.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.pressedColor = Palette.lineSoft,
    this.radius = 0,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color pressedColor;
  final double radius;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (!widget.enabled || !mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? widget.onTap : null,
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _pressed && active ? widget.pressedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: widget.child,
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  const PillButton({
    required this.label,
    this.onPressed,
    this.primary = false,
    this.icon,
    this.height = 44,
    this.fontSize = 16,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Widget? icon;
  final double height;
  final double fontSize;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Pressable(
        onTap: onPressed,
        radius: Frame.pillRadius,
        pressedColor: primary ? Palette.ink2 : Palette.lineSoft,
        child: Container(
          height: height,
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: Space.x5),
          decoration: BoxDecoration(
            color: primary ? Palette.ink : Palette.card,
            border: Border.all(
              color: Palette.ink,
              width: primary ? 0 : Frame.border,
            ),
            borderRadius: BorderRadius.circular(Frame.pillRadius),
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: Space.x1 * 2),
              ],
              Text(
                label,
                style: AppType.sans(
                  fontSize,
                  weight: 600,
                  height: 1,
                  color: primary ? Palette.card : Palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onPressed,
    this.active = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return PillButton(
      label: label,
      onPressed: onPressed,
      primary: active,
      height: 42,
      fontSize: 14,
    );
  }
}
