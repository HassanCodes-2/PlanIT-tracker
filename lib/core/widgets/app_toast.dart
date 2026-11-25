import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/icons.dart';

/// A lightweight, auto-dismissing notification shown at the top of the screen.
///
/// Unlike [SnackBar], dismissal is driven by a plain [Timer], so it always
/// goes away even when system animations are disabled, and it never stacks up
/// or blocks buttons at the bottom of the screen. Tapping the toast dismisses
/// it immediately.
abstract final class AppToast {
  static OverlayEntry? _entry;
  static _ToastCardState? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    dismiss();
    final OverlayState? overlay;
    try {
      overlay = Overlay.of(context, rootOverlay: true);
    } catch (_) {
      return;
    }
    final entry = OverlayEntry(
      builder: (context) => _ToastCard(
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismissed: _clearRefs,
        onRegistered: (state) => _current = state,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }

  /// Removes the visible toast, if any. Safe to call any time.
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.beginExit();
  }

  static void _clearRefs() {
    _entry?.remove();
    _entry = null;
    _current = null;
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.onDismissed,
    required this.onRegistered,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;
  final ValueChanged<_ToastCardState> onRegistered;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    final quick = MediaQuery.disableAnimationsOf(context);
    _controller = AnimationController(
      vsync: this,
      duration: quick ? const Duration(milliseconds: 1) : const Duration(milliseconds: 220),
      reverseDuration: quick
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 180),
    );
    widget.onRegistered(this);
    _controller.forward();
  }

  void beginExit() {
    if (_exiting) return;
    _exiting = true;
    _controller.reverse().whenComplete(widget.onDismissed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.paddingOf(context);
    final background = theme.brightness == Brightness.dark
        ? const Color(0xFF2E2E36)
        : const Color(0xFF202024);
    final actionColor = AppTheme.ensureVisible(
      theme.colorScheme.secondary,
      background,
      Brightness.dark,
      ratio: 4.5,
    );

    return Positioned(
      top: padding.top + 10,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutCubic,
              )),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: background,
                  elevation: 4,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: beginExit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (widget.actionLabel != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                widget.onAction?.call();
                                beginExit();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.check,
                                      size: 13,
                                      color: actionColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.actionLabel!,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        color: actionColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}