import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single primary call-to-action pinned to the bottom of a screen via
/// [Scaffold.bottomNavigationBar]. Letting the Scaffold manage the slot
/// (instead of a [Stack] + [Positioned] overlay with hand-picked padding)
/// keeps the gap to the system navigation bar consistent across devices:
/// [SafeArea] supplies the real inset and `minimum` only tops it up when
/// the device reports none, so the button never doubles up on padding. The
/// minimum is kept small on purpose — on devices with a real nav-bar inset,
/// that inset alone (not our own addition on top of it) is the gap.
class StickyActionButton extends StatelessWidget {
  const StickyActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final style = FilledButton.styleFrom(
      backgroundColor: AppTheme.primary,
      foregroundColor: AppTheme.primaryForeground,
      disabledBackgroundColor: scheme.surfaceContainerHighest,
      minimumSize: const Size.fromHeight(56),
      elevation: onPressed != null ? 4 : 0,
      shadowColor: AppTheme.primary.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    final labelText = Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: loading
          ? FilledButton.icon(
              style: style,
              onPressed: null,
              icon: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              label: labelText,
            )
          : icon == null
          ? FilledButton(style: style, onPressed: onPressed, child: labelText)
          : FilledButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon),
              label: labelText,
            ),
    );
  }
}
