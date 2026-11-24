import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../core/widgets/confetti.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';
import '../../domain/enums.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, required this.deedId, this.date});

  final int deedId;
  final DateTime? date;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  static const _choices = [5, 15, 25, 45];

  db.Deed? _deed;
  bool _loading = true;

  int _totalSeconds = 25 * 60;
  int _remaining = 25 * 60;
  bool _running = false;
  bool _finished = false;
  Timer? _timer;
  DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final deed = await ref.read(repositoryProvider).deedById(widget.deedId);
    if (!mounted) return;
    setState(() {
      _deed = deed;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelFocusNotification());
    super.dispose();
  }

  void _startPause() {
    HapticFeedback.selectionClick();
    if (_running) {
      _timer?.cancel();
      final ends = _endsAt;
      unawaited(ref.read(notificationServiceProvider).cancelFocusNotification());
      setState(() {
        _running = false;
        if (ends != null) {
          _remaining = ends.difference(DateTime.now()).inSeconds
              .clamp(0, _totalSeconds);
        }
      });
      return;
    }
    _endsAt = DateTime.now().add(Duration(seconds: _remaining));
    final notifications = ref.read(notificationServiceProvider);
    unawaited(
      notifications.ensurePermission().then((allowed) {
        if (allowed == false && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are off — focus alerts may not appear.',
              ),
            ),
          );
        }
      }),
    );
    final deed = _deed;
    if (deed != null && _endsAt != null) {
      unawaited(notifications.scheduleFocusNotification(_endsAt!, deed.name));
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() => _running = true);
  }

  void _tick() {
    final ends = _endsAt;
    if (ends == null) return;
    final seconds = ends.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) {
      _timer?.cancel();
      unawaited(ref.read(notificationServiceProvider).cancelFocusNotification());
      setState(() {
        _remaining = 0;
        _running = false;
        _finished = true;
      });
      _onComplete();
      return;
    }
    setState(() {
      _remaining = seconds.clamp(0, _totalSeconds);
    });
  }

  Future<void> _onComplete() async {
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    showConfetti(context);
    final deed = _deed;
    if (deed == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Session complete!'),
        content: Text('Great focus. Mark "${deed.name}" as done?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(repositoryProvider)
                  .setLog(deed.id, dateOnly(widget.date ?? DateTime.now()),
                      LogStatus.done);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted && context.mounted) context.pop();
            },
            child: const Text('Mark done'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    final untouched = !_running && _remaining == _totalSeconds;
    if (untouched) {
      if (mounted) context.pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End session?'),
        content: const Text('Your timer will stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      unawaited(ref.read(notificationServiceProvider).cancelFocusNotification());
      context.pop();
    }
  }

  Future<void> _markDoneNow() async {
    final deed = _deed;
    if (deed == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as done?'),
        content: Text('Log "${deed.name}" as done and end this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark done'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _timer?.cancel();
    unawaited(ref.read(notificationServiceProvider).cancelFocusNotification());
    HapticFeedback.mediumImpact();
    await ref
        .read(repositoryProvider)
        .setLog(deed.id, dateOnly(widget.date ?? DateTime.now()),
                      LogStatus.done);
    if (mounted) context.pop();
  }

  void _choose(int minutes) {
    if (_running || _finished || _remaining != _totalSeconds) return;
    setState(() {
      _totalSeconds = minutes * 60;
      _remaining = _totalSeconds;
      _endsAt = null;
    });
  }

  void _addFive() {
    setState(() {
      _totalSeconds += 5 * 60;
      _remaining += 5 * 60;
      _finished = false;
      if (_running && _endsAt != null) {
        _endsAt = _endsAt!.add(const Duration(minutes: 5));
        final deed = _deed;
        if (deed != null) {
          unawaited(ref
              .read(notificationServiceProvider)
              .scheduleFocusNotification(_endsAt!, deed.name));
        }
      }
    });
  }

  void _restart() {
    setState(() {
      _remaining = _totalSeconds;
      _finished = false;
      _running = false;
      _endsAt = null;
    });
  }

  String get _timeLabel {
    final minutes = (_remaining / 60).floor();
    final seconds = _remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _statusLabel {
    if (_finished) return 'Complete!';
    if (_running) return 'Focusing…';
    if (_remaining == _totalSeconds) return 'Ready when you are';
    return 'Paused';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final deed = _deed;
    if (deed == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'This deed no longer exists.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final progress =
        _totalSeconds == 0 ? 0.0 : 1 - _remaining / _totalSeconds;
    final canPickMinutes = !_running && !_finished && _remaining == _totalSeconds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close focus session',
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmExit,
          ),
          title: const Text('Focus'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconForName(deed.icon, fallback: Icons.timer_rounded),
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      deed.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, d MMM')
                    .format(dateOnly(widget.date ?? DateTime.now())),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Semantics(
                label: 'Focus timer',
                value: '$_timeLabel remaining',
                child: ExcludeSemantics(
                child: SizedBox(
                width: 248,
                height: 248,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 248,
                      height: 248,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: progress,
                          color: theme.colorScheme.primary,
                          track:
                              theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _timeLabel,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 56,
                              height: 1.05,
                              fontFamily: context.appStyle.isDigital
                                  ? 'RobotoMono'
                                  : null,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),
              ),
              const SizedBox(height: 24),
              if (canPickMinutes)
                Wrap(
                  spacing: 8,
                  children: _choices
                      .map(
                        (minutes) {
                          final selected = _totalSeconds == minutes * 60;
                          return ChoiceChip(
                            label: Text('$minutes min'),
                            selected: selected,
                            showCheckmark: false,
                            selectedColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => _choose(minutes),
                          );
                        },
                      )
                      .toList(),
                )
              else
                TextButton.icon(
                  onPressed: _finished ? null : _addFive,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add 5 minutes'),
                ),
              const SizedBox(height: AppSpacing.xxl),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _finished ? _restart : _startPause,
                      icon: Icon(
                        _finished
                            ? Icons.replay_rounded
                            : (_running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                      ),
                      label: Text(
                        _finished
                            ? 'Go again'
                            : (_running
                                ? 'Pause'
                                : (_remaining == _totalSeconds
                                    ? 'Start'
                                    : 'Resume')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: _markDoneNow,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Mark done now'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const strokeWidth = 16.0;
    final inset = strokeWidth / 2 + 2;
    final arcRect = rect.deflate(inset);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arcRect, 0, 2 * 3.141592653589793, false, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -1.5707963267948966,
        2 * 3.141592653589793 * progress.clamp(0.0, 1.0), false,
        progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}